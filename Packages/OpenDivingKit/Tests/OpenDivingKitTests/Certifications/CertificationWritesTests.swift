import Foundation
import Testing

@testable import OpenDivingKit

/// A certification's form saving through the queue with its card images, a refused image
/// reopened, the course a pick fills from, and the card images kept once shown.
@MainActor
struct CertificationWritesTests {
  private static let certification = UUID(uuidString: "01a0b07a-206e-76bd-bc56-e9646791ba20")!

  @Test func aNewCardsImagesAreQueuedAfterItAndSentOnceItLands() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let model = RecordSheetModel(outbox: outbox, values: CertificationFormValues(name: "Rescue"))
    var edits = CertificationCardEdits()
    edits[.front] = .replace(.framed(Data("JPG".utf8), side: .front))
    edits[.back] = .replace(
      CertificationCardPick(
        data: Data("%PDF".utf8), contentType: "application/pdf", filename: "back.pdf"))
    let ref = try #require(model.save())
    #expect(edits.queue(of: ref, outbox: outbox).isEmpty)
    #expect(outbox.items.count == 3)

    world.online()
    let mark = world.server.mark
    outbox.syncNow()
    await outbox.settled()
    let created = try #require(world.server.created.first).uuidString.lowercased()
    #expect(
      world.server.writes(since: mark).map(\.route) == [
        "POST certification", "PUT certification/\(created)/file/front",
        "PUT certification/\(created)/file/back",
      ])
    #expect(outbox.items.isEmpty)
  }

  @Test func aRemovedSideIsQueuedAsItsDelete() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    var edits = CertificationCardEdits()
    edits[.back] = .remove
    #expect(edits.queue(of: .server(Self.certification), outbox: outbox).isEmpty)
    #expect(
      outbox.items.map(\.operation) == [
        .deleteCertificationFile(.server(Self.certification), .back)
      ]
    )
    await outbox.settled()
  }

  @Test func aRefusedImageReopensWithItsBytesAndGoesWhenItsSideIsDropped() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PUT certification") ? .status(415, "Not an image.") : nil
    }
    let outbox = world.outbox()
    let refused = try outbox.queueCardImage(
      Data("JPG".utf8),
      as: CertificationCardUpload(side: .back, filename: "b.jpg", contentType: "image/jpeg"),
      of: .server(Self.certification))
    await outbox.settled()

    let item = try #require(outbox.item(refused.id))
    let reopened = try #require(CertificationCardEdits.reopening(item, session: world.session))
    #expect(reopened.side == .back && reopened.failure == "Not an image.")
    #expect(reopened.pick?.data == Data("JPG".utf8) && reopened.pick?.filename == "b.jpg")
    var edits = CertificationCardEdits(reopening: reopened)
    #expect(edits[.back] == reopened.pick.map(CertificationCardEdit.replace))

    edits[.back] = nil
    world.offline()
    #expect(
      edits.queue(of: .server(Self.certification), outbox: outbox, reopened: reopened).isEmpty)
    #expect(outbox.item(refused.id) == nil)
    #expect(CertificationCardEdits.reopening(item, session: world.session)?.pick == nil)
    #expect(CertificationCardEdits(reopening: reopened.withoutBytes).isEmpty)
  }

  @Test func aRefusedImageSavedAgainReplacesItself() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.server.override { request, _ in
      request.route.hasPrefix("PUT certification") ? .status(415, "Not an image.") : nil
    }
    let outbox = world.outbox()
    let refused = try outbox.queueCardImage(
      Data("JPG".utf8),
      as: CertificationCardUpload(side: .front, filename: "f.jpg", contentType: "image/jpeg"),
      of: .server(Self.certification))
    await outbox.settled()
    let reopened = try #require(
      CertificationCardEdits.reopening(outbox.item(refused.id)!, session: world.session))
    world.offline()
    let edits = CertificationCardEdits(reopening: reopened)
    #expect(
      edits.queue(of: .server(Self.certification), outbox: outbox, reopened: reopened).isEmpty)
    #expect(outbox.item(refused.id) == nil)
    #expect(outbox.items.count == 1)
    await outbox.settled()
  }

  // MARK: - A pick's course

  @Test func aPickFillsFromThePickersRowAndAsksTheServerNothing() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let mark = world.server.mark
    let kim = RecordRef.server(UUID())
    let shop = RecordRef.server(UUID())
    let ref = RecordRef.server(UUID())
    let row = CourseLookupItem(
      ref: ref, name: "Rescue", contact: shop,
      people: [
        PersonReference(person: RecordRef.server(UUID()), role: "student"),
        PersonReference(person: kim, role: "instructor"),
      ])
    let fill = CertificationCourseFill.picked(ref, outbox: world.outbox(), rows: [row])
    #expect(fill == CertificationCourseFill(row))
    #expect(fill?.contact == shop && fill?.instructor == kim)
    #expect(fill?.agency == nil && fill?.instructorNumber == nil)
    #expect(
      world.server.count("GET course/\(ref.serverUUID!.uuidString.lowercased())", since: mark) == 0)
    #expect(
      CertificationCourseFill.picked(.server(UUID()), outbox: world.outbox(), rows: [row]) == nil)
  }

  @Test func aCourseMadeOnThePhoneFillsFromTheBodyItWaitsWith() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let kim = RecordRef.server(UUID())
    let made = try outbox.queue(
      .createCourse(
        CourseCreate(
          name: "Cave 1", agency: "gue", instructorNumber: "G-7",
          people: [PersonReference(person: kim, role: "instructor")])))
    let fill = CertificationCourseFill.picked(
      try #require(made.creates), outbox: outbox, rows: [])
    #expect(fill?.name == "Cave 1" && fill?.agency == "gue")
    #expect(fill?.instructor == kim && fill?.instructorNumber == "G-7")
    await outbox.settled()
  }

  // MARK: - Kept card images

  @Test func aSideShownOnceDrawsOfflineAndANewVersionIsFetched() async throws {
    let world = try OutboxWorld()
    try await world.load()
    let file = try #require(
      try KitFixture.decode(CertificationRead.self, "certification-front-only").file(side: "front"))
    world.server.override { request, _ in
      request.route.hasSuffix("/file/front")
        ? StubTransport.Response(headers: ["Content-Type": "image/webp"], body: Data("WEBP".utf8))
        : nil
    }
    let first = await CertificationCardImages.bytes(
      of: Self.certification, file, session: world.session)
    #expect(first == Data("WEBP".utf8))

    world.server.override { _, _ in throw URLError(.notConnectedToInternet) }
    let kept = await CertificationCardImages.bytes(
      of: Self.certification, file, session: world.session)
    #expect(kept == Data("WEBP".utf8))

    let replaced = try APICoding.decoder().decode(
      CertificationFileInfo.self,
      from: Data(
        #"{"uuid":"\#(file.uuid.uuidString.lowercased())","side":"front","#
          .appending(
            #""content_type":"image/webp","byte_size":4,"original_filename":"f.webp","#
              + #""updated_at":"2026-10-01T10:00:00Z"}"#
          ).utf8))
    let none = await CertificationCardImages.bytes(
      of: Self.certification, replaced, session: world.session)
    #expect(none == nil)
  }

  @Test func aCardsImagesGoWithItAndASideItNoLongerNamesGoes() throws {
    let world = try OutboxWorld()
    let cache = world.cacheA
    let certification = try KitFixture.decode(CertificationRead.self, "certification-front-only")
    let file = try #require(certification.file(side: "front"))
    cache.writeCardImage(Data("WEBP".utf8), certification.uuid, file)
    #expect(cache.cardImage(certification.uuid, file) == Data("WEBP".utf8))

    cache.writeRecord(certification, .certification, fetchedAt: Date())
    #expect(cache.cardImage(certification.uuid, file) != nil)
    cache.removeRecord(.certification, certification.uuid)
    #expect(cache.cardImage(certification.uuid, file) == nil)

    cache.writeCardImage(Data("WEBP".utf8), certification.uuid, file)
    let json = try String(decoding: KitFixture.data("certification-front-only"), as: UTF8.self)
    let sideRemoved = try APICoding.decoder().decode(
      CertificationRead.self,
      from: Data(
        json.replacingOccurrences(
          of: #"\[\s*\{[^\]]*\]"#, with: "[]", options: .regularExpression
        ).utf8))
    #expect(sideRemoved.files.isEmpty)
    cache.writePages(
      AccountCache.Pages(items: [sideRemoved], hasMore: false, nextPage: 2), key: "certifications")
    #expect(cache.cardImage(certification.uuid, file) == nil)
  }

  @Test func aRefusedImageWhoseBytesAreGoneReopensOnTheStoredSideAndGoesWithTheSave() async throws {
    let world = try OutboxWorld()
    try await world.load()
    world.offline()
    let outbox = world.outbox()
    let image = try outbox.queueCardImage(
      Data("JPG".utf8),
      as: CertificationCardUpload(side: .front, filename: "f.jpg", contentType: "image/jpeg"),
      of: .server(Self.certification))
    try FileManager.default.removeItem(at: world.storesA.cardFile(for: image.id))
    world.online()
    outbox.syncNow()
    await outbox.settled()

    let failed = try #require(outbox.item(image.id))
    let reopened = try #require(CertificationCardEdits.reopening(failed, session: world.session))
    #expect(reopened.pick == nil && reopened.failure == OutboxText.cardImageMissing)
    let edits = CertificationCardEdits(reopening: reopened)
    #expect(edits.isEmpty)
    #expect(
      edits.queue(of: .server(Self.certification), outbox: outbox, reopened: reopened).isEmpty)
    #expect(outbox.item(image.id) == nil)
  }
}

extension CertificationCardEdits.CardReopening {
  fileprivate var withoutBytes: Self {
    Self(item: item, side: side, pick: nil, failure: failure)
  }
}
