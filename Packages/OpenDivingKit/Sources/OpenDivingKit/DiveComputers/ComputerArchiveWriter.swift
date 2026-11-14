import Foundation

/// Turns a download into one DiveJSON archive on disk — `logbook.divejson` at the root and each
/// dive's original bytes under `files/`, the spec's archive convention and the api's.
///
/// A dive is named `{make-model}_{serial}_{YYYY-MM-DDThhmm}.bin` after its start, or after its
/// fingerprint's hex where nothing gave it one; the archive after the download's moment, with a
/// `.zip` suffix. Each stored original is tagged, under the api's producer key, with what
/// reads it again on the server: the reader's key, libdivecomputer's descriptor and any fallback
/// start the reader was given.
public struct ComputerArchiveWriter: Sendable {
  /// What the document's `generator` names.
  public struct Generator: Hashable, Sendable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
      self.name = name
      self.version = version
    }
  }

  /// One download, ready to write.
  public struct Download: Hashable, Sendable {
    public let identity: DiveComputerIdentity
    /// Newest first, as the computer walks them; a refused reading's bytes travel unnamed.
    public let dives: [DownloadedDive]
    /// When it was downloaded, and the phone's zone, which the names and `exported_at` use.
    public let moment: Date
    public let zone: TimeZone
    /// The zone an instant start is written in where its dive logged none: the diver's answer
    /// for this download, else the watch's.
    public let instantZone: TimeZone?

    public init(
      identity: DiveComputerIdentity, dives: [DownloadedDive], moment: Date, zone: TimeZone,
      instantZone: TimeZone?
    ) {
      self.identity = identity
      self.dives = dives
      self.moment = moment
      self.zone = zone
      self.instantZone = instantZone
    }
  }

  /// An archive written: where, what it holds, and its dives' uuids.
  public struct Written: Hashable, Sendable {
    public let url: URL
    public let summary: DownloadSummary
    public let dives: [UUID]
  }

  public let generator: Generator

  public init(generator: Generator) {
    self.generator = generator
  }

  /// Writes `download` as one archive into `directory`.
  public func write(_ download: Download, into directory: URL) throws -> Written {
    let identity = download.identity
    let slug = DiveComputerArchive.slug(vendor: identity.vendor, product: identity.product)
    let serial = DiveComputerArchive.fileSerial(identity.serial)
    var dives: [ArchiveJSON] = []
    var members: [Member] = []
    var used: Set<String> = []
    var uuids: [UUID] = []
    for downloaded in download.dives {
      let zone = downloaded.loggedZone ?? download.instantZone
      let resolved: (text: String, clock: LocalDateTime)?
      switch downloaded.reading {
      case .dive(let dive):
        resolved = try DiveComputerArchive.start(dive.start, zone: zone)
      case .refused(let start):
        resolved = start.flatMap { try? DiveComputerArchive.start($0, zone: zone) }
      }
      let stamp =
        resolved.map { DiveComputerArchive.minute($0.clock) }
        ?? Hex.lowercase(downloaded.fingerprint)
      let filename = Self.unique("\(slug)_\(serial)_\(stamp).bin", in: &used)
      let path = DiveComputerArchive.filesFolder + filename
      members.append(Member(path: path, bytes: downloaded.bytes))
      guard case .dive(let dive) = downloaded.reading, let resolved else { continue }
      let storedFile: ArchiveJSON = .object([
        "uuid": .string(
          DiveComputerArchive.fileUUID(downloaded.identity, fingerprint: downloaded.fingerprint)
            .uuidString.lowercased()),
        "original_filename": .string(filename),
        "content_type": .string("application/octet-stream"),
        "byte_size": .integer(downloaded.bytes.count),
        "sha256": .string(SHA256Digest.hex(downloaded.bytes)),
        "archive_path": .string(path),
        "extensions": .object([DiveComputerArchive.producerKey: Self.tag(dive, downloaded.identity)]
        ),
      ])
      let uuid = DiveComputerArchive.diveUUID(
        downloaded.identity, fingerprint: downloaded.fingerprint)
      uuids.append(uuid)
      dives.append(
        ComputerDiveDocument.dive(
          dive, identity: downloaded.identity, uuid: uuid, startedAt: resolved.text,
          storedFile: storedFile))
    }
    let clock = DiveComputerArchive.clock(download.moment, in: download.zone)
    let url = directory.appendingPathComponent(
      "\(slug)_\(serial)_\(DiveComputerArchive.minute(clock)).zip", isDirectory: false)
    try write(dives: dives, members: members, moment: download.moment, zone: download.zone, to: url)
    let computer = DownloadSummary.Computer(
      family: identity.family, vendor: identity.vendor, product: identity.product,
      serial: identity.serial, dives: dives.count)
    return Written(
      url: url, summary: DownloadSummary(computers: [computer], downloadedAt: download.moment),
      dives: uuids)
  }

  // MARK: - Internals

  /// What the server reads the original with: libdivecomputer's descriptor, which resolves the
  /// parser in whichever build reads it, and the fallback start the reader was given, so a dive
  /// whose bytes state no start reads to the same one there.
  private static func tag(_ dive: ComputerDive, _ identity: DiveComputerIdentity) -> ArchiveJSON {
    var tag: [String: ArchiveJSON] = [
      "parser_key": .string(DiveComputerArchive.parserKey),
      "descriptor": .object([
        "vendor": .string(identity.vendor), "product": .string(identity.product),
        "model": .integer(Int(identity.modelNumber)),
      ]),
    ]
    if let fallback = dive.fallbackStart {
      tag["fallback_start"] = .string(ComputerDive.instantText(fallback))
    }
    return .object(tag)
  }

  private struct Member {
    let path: String
    let bytes: Data
  }

  private func write(
    dives: [ArchiveJSON], members: [Member], moment: Date, zone: TimeZone, to url: URL
  ) throws {
    let document: ArchiveJSON = .object([
      "format": .string("divejson"),
      "version": .string("1.0"),
      "exported_at": .string(DiveComputerArchive.dateTime(moment, in: zone)),
      "generator": .object(["name": .string(generator.name), "version": .string(generator.version)]
      ),
      "dives": .array(dives),
    ])
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)
    do {
      var zip = try ZipWriter(creating: url, moment: moment, zone: zone)
      try zip.add(DiveComputerArchive.documentName, Data(document.text.utf8))
      for member in members { try zip.add(member.path, member.bytes) }
      try zip.finish()
    } catch {
      try? FileManager.default.removeItem(at: url)
      throw error
    }
  }

  /// `name`, or `name` with `-2`, `-3`… before its extension where `used` holds it.
  private static func unique(_ name: String, in used: inout Set<String>) -> String {
    var candidate = name
    var counter = 2
    while used.contains(candidate) {
      let dot = name.lastIndex(of: ".") ?? name.endIndex
      candidate = String(name[..<dot]) + "-\(counter)" + String(name[dot...])
      counter += 1
    }
    used.insert(candidate)
    return candidate
  }
}
