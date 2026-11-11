import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The two pictures as fields of their forms: what each edit sends, in what order beside the
/// fields, what a refusal says, and where the new picture shows afterwards.
@MainActor
struct PictureFieldTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("PictureFieldTests-\(UUID().uuidString)", isDirectory: true)
  private let today = CalendarDate(year: 2026, month: 11, day: 10)!
  private let photo = PictureSource(data: Data("the photo".utf8), width: 3024, height: 4032)
  private let square = PictureCrop(x: 0, y: 504, width: 3024, height: 3024)
  private let portraitCrop = PictureCrop(x: 0, y: 72, width: 3024, height: 3888)

  private func loaded(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) async throws -> Session {
    let session = Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity, applicationSupport: root, userAgent: ClientHarness.userAgent)
    try await session.loadAccount()
    return session
  }

  private func sent(_ server: SettingsServer, after count: Int) -> [String] {
    server.requests.dropFirst(count).map(\.route)
  }

  private func body(_ server: SettingsServer, _ route: String) -> URLRequest? {
    server.requests.last { $0.route == route }
  }

  private func json(_ text: String) throws -> JSONValue {
    try JSONValue.parse(Data(text.utf8))
  }

  private func replace(_ crop: PictureCrop) -> PictureEdit {
    .replace(photo, filename: "avatar.jpg", type: .jpeg, crop: crop)
  }

  // MARK: - Account

  @Test func thePictureGoesAfterTheFieldsAndEveryScreenReadsTheNewOne() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = AccountFormModel(session: session)
    let before = server.requests.count

    model.setName("Sam Diver")
    model.picture.set(replace(square))
    #expect(model.canSave)
    await model.save()

    #expect(
      sent(server, after: before) == ["PATCH user", "GET user", "PUT user/avatar", "GET user"])
    let upload = String(
      decoding: try #require(body(server, "PUT user/avatar")?.httpBody), as: UTF8.self)
    #expect(upload.contains(#"name="file"; filename="avatar.jpg""#))
    #expect(upload.contains("Content-Type: image/jpeg\r\n\r\nthe photo\r\n"))
    let crop = try #require(SettingsServer.formCrop(Data(upload.utf8)))
    #expect(
      try JSONValue.parse(JSONSerialization.data(withJSONObject: crop))
        == (try json(#"{"x":0,"y":504,"width":3024,"height":3024}"#)))
    #expect(session.user?.name == "Sam Diver")
    #expect(session.user?.avatarSha256 == "uploaded-avatar")
    #expect(session.user?.avatarCrop == square)
    #expect(model.picture.edit == nil)
    #expect(model.saved)
    #expect(!model.canSave)
  }

  @Test func aPictureAloneSendsNoFields() async throws {
    let server = try SettingsServer()
    let model = AccountFormModel(session: try await loaded(server))
    let before = server.requests.count

    model.picture.set(replace(square))
    await model.save()

    #expect(sent(server, after: before) == ["PUT user/avatar", "GET user"])
    #expect(model.saved)
  }

  @Test func aPictureChosenAfterASaveIsNotShownAsSaved() async throws {
    let server = try SettingsServer()
    let model = AccountFormModel(session: try await loaded(server))
    model.setName("Sam Diver")
    await model.save()
    #expect(model.saved)

    model.picture.set(replace(square))
    #expect(!model.saved)
    model.picture.pressBin()
    #expect(model.saved)
  }

  @Test func aRefusedPictureLeavesTheFieldsSavedAndSaysExactlyThat() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail(
      "PUT user/avatar",
      with: .json(
        #"{"detail":"That picture would take you past your storage limit."}"#, status: 413))
    let model = AccountFormModel(session: session)

    model.setName("Sam Diver")
    model.picture.set(replace(square))
    await model.save()

    #expect(
      model.failure
        == "Saved, but your profile picture did not. That picture would take you past your"
        + " storage limit.")
    #expect(session.user?.name == "Sam Diver")
    #expect(model.name == "Sam Diver")
    #expect(model.picture.edit == replace(square))
    #expect(!model.saved)

    // Another try sends the picture alone.
    server.succeed("PUT user/avatar")
    let before = server.requests.count
    await model.save()
    #expect(sent(server, after: before) == ["PUT user/avatar", "GET user"])
    #expect(model.failure == nil)
    #expect(model.saved)
  }

  @Test func aRefusalOfTheFieldsIsNotLeftShowingByASaveOfThePictureAlone() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    let model = AccountFormModel(session: session)
    model.setUsername("taken")
    model.picture.set(replace(square))
    await model.save()
    #expect(model.failure == "Username not available")

    model.setUsername("testdiver")
    let before = server.requests.count
    await model.save()

    #expect(sent(server, after: before) == ["PUT user/avatar", "GET user"])
    #expect(model.failure == nil)
    #expect(model.saved)
  }

  @Test func aRefusalOfTheFieldsGoesOnceAFieldItSentIsEdited() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    let model = AccountFormModel(session: session)
    model.setUsername("taken")
    await model.save()
    #expect(model.failure == "Username not available")

    // The save sent no name, and the picture is not what was refused.
    model.setName("Sam Diver")
    model.picture.set(replace(square))
    #expect(model.failure == "Username not available")

    model.setUsername("taken2")
    #expect(model.failure == nil)
  }

  @Test func aRefusalOfThePictureGoesOnceThePictureChangesAndOnlyThen() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PUT user/avatar", with: .json(#"{"detail":"Unsupported image."}"#, status: 415))
    let model = AccountFormModel(session: session)
    model.picture.set(replace(square))
    await model.save()
    let refused = "Your profile picture did not save. Unsupported image."
    #expect(model.failure == refused)

    model.setName("Sam Diver")
    model.setUsername("samdiver")
    #expect(model.failure == refused)

    // Changed and changed back is still a change.
    model.picture.pressBin()
    model.picture.set(replace(square))
    #expect(model.failure == nil)
  }

  @Test func theNextSaveSaysOnlyWhatItRefused() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PUT user/avatar", with: .json(#"{"detail":"Unsupported image."}"#, status: 415))
    let model = AccountFormModel(session: session)
    model.setName("Sam Diver")
    model.picture.set(replace(square))
    await model.save()
    #expect(model.failure != nil)

    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    model.setUsername("taken")
    await model.save()
    #expect(model.failure == "Username not available")
  }

  @Test func aRefusedPictureWithNoFieldsSaysOnlyThatItDidNotSave() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PUT user/avatar", with: .json(#"{"detail":"Unsupported image."}"#, status: 415))
    let model = AccountFormModel(session: session)

    model.picture.set(replace(square))
    await model.save()

    #expect(model.failure == "Your profile picture did not save. Unsupported image.")
  }

  @Test func refusedFieldsSendNoPicture() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PATCH user", with: .json(#"{"detail":"Username not available"}"#, status: 422))
    let model = AccountFormModel(session: session)
    let before = server.requests.count

    model.setUsername("taken")
    model.picture.set(replace(square))
    await model.save()

    #expect(sent(server, after: before) == ["PATCH user"])
    #expect(model.picture.edit == replace(square))
  }

  @Test func offlineNothingIsSentAndThePictureSaysThereIsNoConnection() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let session = try await loaded(server, connectivity: connectivity)
    connectivity.isRouteAvailable = false
    let model = AccountFormModel(session: session)
    let before = server.requests.count

    model.picture.set(replace(square))
    await model.save()

    #expect(server.requests.count == before)
    #expect(
      model.failure
        == "Your profile picture did not save. \(APIError.noRoute.message)")
  }

  @Test func aPictureTakenWhoseReadFailedShowsUntilTheAccountIsRead() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = AccountFormModel(session: session)
    server.fail("GET user", with: .json(#"{"detail":"Down"}"#, status: 500))

    model.picture.set(replace(square))
    await model.save()

    #expect(model.saved)
    #expect(model.picture.edit == nil)
    #expect(model.picture.shown == replace(square))
    #expect(!model.picture.canAdjust)
    #expect(!model.canSave)

    server.succeed("GET user")
    try await session.reloadAccount()
    #expect(model.picture.shown == nil)
    #expect(model.picture.storedSha == "uploaded-avatar")
  }

  // MARK: - Adjust, copy, remove

  @Test func adjustReCropsTheOriginalWithNoUpload() async throws {
    let server = try SettingsServer()
    server.set("avatar_original_sha256", "avatar-original")
    server.set("avatar_crop", ["x": 0, "y": 0, "width": 10, "height": 10])
    let session = try await loaded(server)
    let picture = PictureFieldModel(kind: .avatar, session: session)
    #expect(picture.canAdjust)

    guard case .success(.bytes(let data, let purpose, let initial)) = await picture.open(.adjust)
    else {
      Issue.record("no original")
      return
    }
    #expect(data == Data("avatar-original".utf8))
    #expect(purpose == .adjust)
    #expect(initial == PictureCrop(x: 0, y: 0, width: 10, height: 10))
    #expect(body(server, "GET user/avatar/original")?.url?.query == "v=avatar-original")

    let source = PictureSource(data: data, width: 4032, height: 3024)
    picture.set(
      PictureCropping(purpose: purpose, source: source, initial: initial)
        .edit(cropping: CropFrame.Area(x: 500, y: 0, width: 3024, height: 3024), kind: .avatar))
    #expect(picture.caption == "Re-cropped when you save.")
    let before = server.requests.count
    #expect(await picture.send() == nil)

    #expect(sent(server, after: before) == ["PATCH user/avatar", "GET user"])
    #expect(
      body(server, "PATCH user/avatar")?.json
        == (try json(#"{"crop":{"x":500,"y":0,"width":3024,"height":3024}}"#)))
    #expect(session.user?.avatarSha256 == "adjusted-avatar")
  }

  @Test func adjustingAPictureWithNoOriginalReCropsWhatItShowsAsAReplacement() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let picture = PictureFieldModel(kind: .avatar, session: session)

    guard case .success(.rendition(let data)) = await picture.open(.adjust) else {
      Issue.record("no rendition")
      return
    }
    #expect(data == Data(try #require(session.user?.avatarSha256).utf8))
  }

  @Test func adjustingAPendingPictureFetchesNothing() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let picture = PictureFieldModel(kind: .avatar, session: session)
    picture.set(replace(square))
    let before = server.requests.count

    guard case .success(.cropping(let cropping)) = await picture.open(.adjust) else {
      Issue.record("no cropping")
      return
    }
    #expect(cropping.purpose == .replace(filename: "avatar.jpg", type: .jpeg))
    #expect(cropping.source == photo)
    #expect(cropping.initial == square)
    #expect(server.requests.count == before)
  }

  @Test func useProfilePictureIsOfferedOnlyWhereItHasAnOriginal() async throws {
    let server = try SettingsServer()
    var session = try await loaded(server)
    #expect(!PictureFieldModel(kind: .portrait, session: session).canCopy)
    #expect(!PictureFieldModel(kind: .avatar, session: session).canCopy)

    server.set("avatar_original_sha256", "avatar-original")
    session = try await loaded(server)
    let portrait = PictureFieldModel(kind: .portrait, session: session)
    #expect(portrait.canCopy)

    guard case .success(.bytes(let data, .copy, nil)) = await portrait.open(.copy) else {
      Issue.record("no original")
      return
    }
    #expect(data == Data("avatar-original".utf8))
    portrait.set(.copy(PictureSource(data: data, width: 3024, height: 4032), crop: portraitCrop))
    #expect(portrait.caption == "Your profile picture replaces your portrait when you save.")
    let before = server.requests.count
    #expect(await portrait.send() == nil)

    #expect(sent(server, after: before) == ["POST user/portrait/from-avatar", "GET user"])
    #expect(
      body(server, "POST user/portrait/from-avatar")?.json
        == (try json(#"{"crop":{"x":0,"y":72,"width":3024,"height":3888}}"#)))
    #expect(session.user?.portraitSha256 == "copied-portrait")
  }

  @Test func removeTakesThePictureOffAndOneAlreadyGoneCountsAsRemoved() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let picture = PictureFieldModel(kind: .avatar, session: session)
    #expect(picture.bin == .remove)
    picture.pressBin()
    #expect(picture.edit == .remove)
    #expect(picture.bin == .keep)
    #expect(picture.caption == "Removed when you save.")
    #expect(!picture.canAdjust)
    #expect(picture.primaryLabel == "Upload")

    #expect(await picture.send() == nil)
    #expect(body(server, "DELETE user/avatar") != nil)
    #expect(session.user?.avatarSha256 == nil)
    #expect(picture.bin == nil)

    picture.set(.remove)
    #expect(await picture.send() == nil)
    #expect(picture.edit == nil)
  }

  @Test func theSlotSaysWhatSavingWillDo() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let picture = PictureFieldModel(kind: .avatar, session: session)
    #expect(picture.caption == PictureKind.avatar.help)
    #expect(picture.primaryLabel == "Replace")
    #expect(picture.showsStored)

    picture.set(replace(square))
    #expect(picture.caption == "Replaces your profile picture when you save.")
    #expect(picture.bin == .discard)
    #expect(picture.bin?.label(.avatar) == "Discard the new profile picture")
    picture.pressBin()
    #expect(picture.edit == nil)
    #expect(picture.showsStored)

    server.set("portrait_sha256", NSNull())
    let portrait = PictureFieldModel(kind: .portrait, session: try await loaded(server))
    #expect(portrait.primaryLabel == "Upload")
    #expect(portrait.bin == nil)
    #expect(!portrait.canAdjust)
    portrait.set(.replace(photo, filename: "portrait.jpg", type: .jpeg, crop: portraitCrop))
    #expect(portrait.caption == "Added when you save.")
  }

  // MARK: - Check-in

  @Test func thePortraitRidesAboutYouAfterItsFieldsAndReachesTheKeptSheet() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let store = CheckinSheetStore(store: session.store, origin: origin)
    let old = CheckinSheetFile(
      name: "portrait", version: "old", etag: "\"old\"", contentType: "image/webp")
    let kept = CheckinSheet(
      name: "Test Diver", units: .metric, details: try server.checkinDetails(), totalDives: 3,
      maxDepth: 30, lastDiveStart: nil, portrait: old,
      cards: [
        CheckinSheetCard(
          certification: try KitFixture.decode(CertificationRead.self, "certification-front-only"),
          courseName: nil, diveCenterName: nil, instructorName: nil,
          front: CheckinSheetFile(
            name: "side-1", version: "side-1", etag: nil, contentType: "image/jpeg"),
          back: nil)
      ],
      updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
    let staging = try store.beginStaging()
    try staging.write(Data("old portrait".utf8), name: "portrait")
    try staging.write(Data("a card".utf8), name: "side-1")
    try store.commit(kept)

    let model = CheckinDetailsModel(session: session)
    await model.load()
    model.draft.phone = "+1 555 0100"
    model.portrait.set(.replace(photo, filename: "portrait.jpg", type: .jpeg, crop: portraitCrop))
    let before = server.requests.count
    #expect(await model.save(.about, today: today))

    #expect(
      sent(server, after: before) == [
        "PATCH user/checkin-details", "PUT user/portrait", "GET user", "GET user/portrait",
      ])
    #expect(model.saved.contains(.about))
    #expect(model.failures[.about] == nil)
    let sheet = try #require(store.load())
    #expect(sheet.portrait?.version == "uploaded-portrait")
    #expect(store.data(for: try #require(sheet.portrait)) == Data("uploaded-portrait".utf8))
    #expect(sheet.details.phone == "+1 555 0100")
    #expect(sheet.updatedAt == kept.updatedAt)
    #expect(sheet.cards == kept.cards)
    #expect(store.data(for: try #require(sheet.cards.first?.front)) == Data("a card".utf8))
  }

  @Test func aRemovedPortraitLeavesTheKeptSheet() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let store = CheckinSheetStore(store: session.store, origin: origin)
    let version = try #require(session.user?.portraitSha256)
    let staging = try store.beginStaging()
    try staging.write(Data("portrait".utf8), name: "portrait")
    try store.commit(
      CheckinSheet(
        name: "Test Diver", units: .metric, details: try server.checkinDetails(), totalDives: 3,
        maxDepth: 30, lastDiveStart: nil,
        portrait: CheckinSheetFile(
          name: "portrait", version: version, etag: nil, contentType: "image/webp"),
        cards: [], updatedAt: Date(timeIntervalSince1970: 1_800_000_000)))

    let model = CheckinDetailsModel(session: session)
    await model.load()
    model.portrait.pressBin()
    #expect(await model.save(.about, today: today))

    #expect(body(server, "DELETE user/portrait") != nil)
    #expect(try #require(store.load()).portrait == nil)
    #expect(!store.hasFile("portrait"))
  }

  @Test func aRefusedPortraitLeavesTheDetailsSavedAndSaysExactlyThat() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    server.fail("PUT user/portrait", with: .json(#"{"detail":"Unsupported image."}"#, status: 415))
    let model = CheckinDetailsModel(session: session)
    await model.load()
    model.draft.phone = "+1 555 0100"
    model.portrait.set(.replace(photo, filename: "portrait.jpg", type: .jpeg, crop: portraitCrop))

    #expect(await model.save(.about, today: today))

    #expect(model.failures[.about] == "Saved, but your portrait did not. Unsupported image.")
    #expect(model.details?.phone == "+1 555 0100")
    #expect(try server.checkinDetails().phone == "+1 555 0100")
    #expect(model.portrait.edit != nil)
  }

  @Test func anotherGroupsSaveSendsNoPortrait() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let model = CheckinDetailsModel(session: session)
    await model.load()
    model.portrait.set(.replace(photo, filename: "portrait.jpg", type: .jpeg, crop: portraitCrop))
    let before = server.requests.count

    #expect(await model.save(.insurance, today: today))

    #expect(sent(server, after: before) == ["PATCH user/checkin-details"])
    #expect(model.portrait.edit != nil)
  }

  @Test func theStoredPortraitIsTheKeptSheetsWhereItHoldsThatVersion() async throws {
    let server = try SettingsServer()
    let session = try await loaded(server)
    let version = try #require(session.user?.portraitSha256)
    let store = CheckinSheetStore(store: session.store, origin: origin)
    let staging = try store.beginStaging()
    try staging.write(Data("kept portrait".utf8), name: "portrait")
    try store.commit(
      CheckinSheet(
        name: "Test Diver", units: .metric, details: try server.checkinDetails(), totalDives: 3,
        maxDepth: 30, lastDiveStart: nil,
        portrait: CheckinSheetFile(
          name: "portrait", version: version, etag: nil, contentType: "image/webp"),
        cards: [], updatedAt: Date()))
    let picture = PictureFieldModel(kind: .portrait, session: session)
    let before = server.requests.count

    await picture.loadStored()

    #expect(picture.storedData == Data("kept portrait".utf8))
    #expect(server.requests.count == before)
  }
}
