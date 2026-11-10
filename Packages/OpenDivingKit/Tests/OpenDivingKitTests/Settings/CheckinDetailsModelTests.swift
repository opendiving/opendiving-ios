import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// *Check-in*: what each group sends, what stops it, and the kept sheet after a save.
@MainActor
struct CheckinDetailsModelTests {
  private let origin = ClientHarness.origin
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("CheckinDetailsModelTests-\(UUID().uuidString)", isDirectory: true)
  private let today = CalendarDate(year: 2026, month: 11, day: 10)!

  private func session(
    _ server: SettingsServer, connectivity: SettingsConnectivity = SettingsConnectivity()
  ) -> Session {
    Session(
      transport: server, secrets: InMemorySecretStore([origin.description: "refresh-0"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity, applicationSupport: root, userAgent: ClientHarness.userAgent)
  }

  private func loaded(_ session: Session) async -> CheckinDetailsModel {
    let model = CheckinDetailsModel(session: session)
    await model.load()
    return model
  }

  private func writes(_ server: SettingsServer) -> [JSONValue?] {
    server.requests.filter { $0.route == "PATCH user/checkin-details" }.map(\.json)
  }

  private func json(_ text: String) throws -> JSONValue {
    try JSONValue.parse(Data(text.utf8))
  }

  @Test func nothingIsOfferedForSavingUntilTheReadHasAnswered() async throws {
    let server = try SettingsServer()
    server.fail("GET user/checkin-details", with: .json(#"{"detail":"Down"}"#, status: 500))
    let model = await loaded(session(server))

    #expect(model.details == nil)
    #expect(model.loadFailure == "Down")
    #expect(await !model.save(.about, today: today))
    #expect(writes(server).isEmpty)

    server.succeed("GET user/checkin-details")
    await model.load()
    #expect(model.details == (try server.checkinDetails()))
    #expect(model.loadFailure == nil)
    #expect(model.draft.phone == "+20 100 000 0000")
    #expect(model.draft.emergencyContacts.map(\.name) == ["Sam Example", "Alex Example"])
  }

  @Test func aboutYouSendsItsOwnKeysTrimmedWithABlankAsNull() async throws {
    let server = try SettingsServer()
    let model = await loaded(session(server))
    model.draft.email = "  shop@example.org "
    model.draft.phone = "   "

    #expect(await model.save(.about, today: today))

    #expect(
      writes(server)
        == [
          try json(#"{"email":"shop@example.org","phone":null,"date_of_birth":"1988-04-12"}"#)
        ])
    #expect(model.details?.phone == nil)
    #expect(model.draft.email == "shop@example.org")
    #expect(model.saved == [.about])
  }

  @Test func aStaleScreenCannotRevertAnotherGroup() async throws {
    let server = try SettingsServer()
    let model = await loaded(session(server))
    server.setCheckin("phone", "+1 555 0199")
    model.draft.emergencyContacts.append(.init(name: " Kim Example ", relationship: "Sister"))

    #expect(await model.save(.emergency, today: today))

    #expect(
      writes(server)
        == [
          try json(
            #"""
            {"emergency_contacts":[
              {"name":"Sam Example","phone":"+49 170 0000000","relationship":"Partner"},
              {"name":"Alex Example"},
              {"name":"Kim Example","relationship":"Sister"}]}
            """#)
        ])
    #expect(try server.checkinDetails().phone == "+1 555 0199")
    #expect(try server.checkinDetails().emergencyContacts.count == 3)
    // The group not saved keeps what the screen held, not what the save answered.
    #expect(model.draft.phone == "+20 100 000 0000")
  }

  @Test func aListEmptiedIsSentAsAnEmptyList() async throws {
    let server = try SettingsServer()
    let model = await loaded(session(server))
    model.draft.insurancePolicies.removeAll()

    #expect(await model.save(.insurance, today: today))

    #expect(writes(server) == [try json(#"{"insurance_policies":[]}"#)])
    #expect(try server.checkinDetails().insurancePolicies.isEmpty)
  }

  @Test func whatTheAPIWouldRefuseIsShownUnderItsBoxAndNothingIsSent() async throws {
    let server = try SettingsServer()
    let model = await loaded(session(server))
    model.draft.dateOfBirth = CalendarDate(year: 2026, month: 11, day: 11)
    model.draft.phone = String(repeating: "1", count: 33)
    model.draft.email = "not an address"
    let blank = CheckinDetailsDraft.Contact(name: "  ")
    model.draft.emergencyContacts.append(blank)

    #expect(await !model.save(.about, today: today))
    #expect(await !model.save(.emergency, today: today))

    #expect(writes(server).isEmpty)
    #expect(model.problems[.dateOfBirth] == "Date of birth cannot be in the future")
    #expect(model.problems[.phone] == "Phone number cannot exceed 32 characters")
    #expect(model.problems[.email] == "Please enter a valid email address")
    #expect(model.problems[.contactName(blank.id)] == "Enter who to call")

    // Fixing one group clears its own refusals and leaves the other's.
    model.draft.dateOfBirth = today
    model.draft.phone = ""
    model.draft.email = ""
    #expect(await model.save(.about, today: today))
    #expect(model.problems.keys.map(\.group) == [.emergency])
  }

  @Test func withNoRouteNothingIsSentAndTheGroupSaysSo() async throws {
    let server = try SettingsServer()
    let connectivity = SettingsConnectivity()
    let model = await loaded(session(server, connectivity: connectivity))
    connectivity.isRouteAvailable = false
    model.draft.phone = "+1 555 0100"

    #expect(await !model.save(.about, today: today))

    #expect(writes(server).isEmpty)
    #expect(model.failures[.about] == APIError.noRoute.message)
    #expect(model.draft.phone == "+1 555 0100")
  }

  @Test func aRefusalIsTheAPIsSentenceAndWhatWasTypedStays() async throws {
    let server = try SettingsServer()
    let model = await loaded(session(server))
    server.fail(
      "PATCH user/checkin-details", with: .json(#"{"detail":"Something broke"}"#, status: 500))
    model.draft.phone = "+1 555 0100"

    #expect(await !model.save(.about, today: today))

    #expect(model.failures[.about] == "Something broke")
    #expect(model.failures[.emergency] == nil)
    #expect(model.draft.phone == "+1 555 0100")
    #expect(model.details?.phone == "+20 100 000 0000")
  }

  @Test func theKeptSheetShowsTheSavedDetailsWithItsPicturesWhole() async throws {
    let server = try SettingsServer()
    let session = session(server)
    let store = CheckinSheetStore(store: session.store, origin: origin)
    let portrait = CheckinSheetFile(
      name: "portrait", version: "sha", etag: "\"1\"", contentType: "image/jpeg")
    let kept = CheckinSheet(
      name: "Test Diver", units: .metric, details: try server.checkinDetails(), totalDives: 3,
      maxDepth: 30, lastDiveStart: nil, portrait: portrait, cards: [],
      updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
    let staging = try store.beginStaging()
    try staging.write(Data("portrait-1".utf8), name: "portrait")
    try store.commit(kept)

    let model = await loaded(session)
    model.draft.insurancePolicies[0].number = "DE-1111111"
    #expect(await model.save(.insurance, today: today))

    let sheet = try #require(store.load())
    #expect(sheet.details == (try server.checkinDetails()))
    #expect(sheet.details.insurancePolicies.first?.number == "DE-1111111")
    #expect(sheet.updatedAt == kept.updatedAt)
    #expect(store.data(for: portrait) == Data("portrait-1".utf8))
  }

  @Test func withNoKeptSheetASaveKeepsNone() async throws {
    let server = try SettingsServer()
    let session = session(server)
    let model = await loaded(session)
    model.draft.phone = "+1 555 0100"

    #expect(await model.save(.about, today: today))

    #expect(CheckinSheetStore(store: session.store, origin: origin).load() == nil)
  }
}
