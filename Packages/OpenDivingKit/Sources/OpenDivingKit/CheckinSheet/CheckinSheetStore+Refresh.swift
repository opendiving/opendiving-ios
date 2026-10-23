import Foundation

extension CheckinSheetStore {
  /// Reads the whole sheet from the session's server and swaps it in for the cached one,
  /// or throws and leaves the cached one whole.
  ///
  /// It starts with ``Session/loadAccount()``, which reloads the people table the instructor
  /// names come from: at a cold start that table is empty until it has loaded, and a sheet
  /// built from it then would lose every instructor. Pictures go with the stored `ETag`, and
  /// a 304 keeps the bytes already on the phone.
  @MainActor
  public func refresh(with session: Session, now: Date = Date()) async throws -> CheckinSheet {
    guard case .signedIn(let origin) = session.state else { throw APIError.signedOut }
    let client = try session.requireClient()
    try await session.loadAccount()
    // `loadAccount()` returns quietly when the session ended under it.
    guard session.state == .signedIn(origin), let user = session.user else {
      throw APIError.signedOut
    }
    let people = session.people
    let cached = load()

    let details = try await client.checkinDetails()
    let stats = try await client.diveStats()
    let lastDive = try await client.dives(page: 1, itemsPerPage: 1).data.first
    let certifications = try await APIClient.allPages { page, perPage in
      try await client.certifications(page: page, itemsPerPage: perPage)
    }

    let staging = try beginStaging()
    do {
      var portrait: CheckinSheetFile?
      if let sha = user.portraitSha256 {
        portrait = try await picture(
          name: "portrait", version: sha, cached: cached?.portrait, staging: staging
        ) { etag in
          try await client.portrait(version: sha, etag: etag)
        }
      }

      let cachedSides = Dictionary(
        (cached?.cards ?? []).flatMap { [$0.front, $0.back] }.compactMap { $0 }.map {
          ($0.version, $0)
        }
      ) { first, _ in first }
      // Cards from one course or one centre ask once.
      var courseNames: [UUID: String?] = [:]
      var contactNames: [UUID: String?] = [:]
      var cards: [CheckinSheetCard] = []
      for certification in certifications {
        var courseName: String?
        if let uuid = certification.courseUuid {
          if let known = courseNames[uuid] {
            courseName = known
          } else {
            courseName = try await Self.unlessGone { try await client.course(uuid).name }
            courseNames[uuid] = .some(courseName)
          }
        }
        var contactName: String?
        if let uuid = certification.contactUuid {
          if let known = contactNames[uuid] {
            contactName = known
          } else {
            contactName = try await Self.unlessGone { try await client.contact(uuid).name }
            contactNames[uuid] = .some(contactName)
          }
        }
        var sides: [String: CheckinSheetFile] = [:]
        for side in ["front", "back"] {
          guard let file = certification.file(side: side) else { continue }
          let version = file.uuid.uuidString.lowercased()
          sides[side] = try await picture(
            name: version, version: version, cached: cachedSides[version], staging: staging,
            contentType: file.contentType
          ) { etag in
            try await client.certificationFile(certification.uuid, side: side, etag: etag)
          }
        }
        cards.append(
          CheckinSheetCard(
            certification: certification, courseName: courseName, diveCenterName: contactName,
            instructorName: certification.instructorUuid.flatMap { people[$0]?.name },
            front: sides["front"], back: sides["back"]))
      }

      let sheet = CheckinSheet(
        name: user.name, units: user.units, details: details, totalDives: stats.totalDives,
        maxDepth: stats.maxDepth, lastDiveStart: lastDive?.startTime, portrait: portrait,
        cards: cards, updatedAt: now)
      try commit(sheet)
      return sheet
    } catch {
      discardStaging()
      throw error
    }
  }

  /// One picture into the staging folder: fetched anew, or carried over on a 304. The stored
  /// `ETag` is sent only for the same version, since a new version is a different file.
  @MainActor
  private func picture(
    name: String, version: String, cached: CheckinSheetFile?, staging: Staging,
    contentType: String? = nil,
    fetch: (_ etag: String?) async throws -> ConditionalFetch<FetchedBytes>
  ) async throws -> CheckinSheetFile {
    let reusable = cached.flatMap { $0.version == version && hasFile($0.name) ? $0 : nil }
    switch try await fetch(reusable?.etag) {
    case .notModified:
      guard let reusable else {
        throw APIError.unreadableResponse("304 for \(name) with nothing cached")
      }
      try staging.carry(name: reusable.name)
      return CheckinSheetFile(
        name: name, version: version, etag: reusable.etag, contentType: reusable.contentType)
    case .fetched(let bytes, let etag):
      try staging.write(bytes.data, name: name)
      return CheckinSheetFile(
        name: name, version: version, etag: etag, contentType: bytes.contentType ?? contentType)
    }
  }

  /// A course or a dive centre deleted since the card named it is a 404 every time, and
  /// leaves its row out as on the web rather than failing every refresh after it.
  @MainActor
  private static func unlessGone(_ lookup: () async throws -> String) async throws -> String? {
    do {
      return try await lookup()
    } catch APIError.http(let status, _) where status == 404 {
      return nil
    }
  }
}
