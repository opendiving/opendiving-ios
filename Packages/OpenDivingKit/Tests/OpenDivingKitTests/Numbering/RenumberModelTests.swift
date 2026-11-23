import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The renumber sheet: every change shown before it is written, and only the renumber shown
/// written.
@MainActor
struct RenumberModelTests {
  private func model(
    _ transport: StubTransport, defaults: RenumberDefaults = .wholeLog
  ) -> RenumberModel {
    RenumberModel(
      session: Session.stub(transport: transport), defaults: defaults, offsetMinutes: 120,
      debounce: .zero)
  }

  private func transport(renumber: StubTransport.Response? = nil) throws -> StubTransport {
    let preview = try KitFixture.text("dives-renumber")
    let renumber = renumber ?? .json(preview.replacingOccurrences(of: "true", with: "false"))
    return StubTransport { request in
      guard request.route == "POST dives/renumber" else {
        return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
      return request.json?["dry_run"] == .bool(true) ? .json(preview) : renumber
    }
  }

  @Test func theWholeLogFromOneIsPreviewedAndListedInFull() async throws {
    let transport = try transport()
    let model = model(transport)
    #expect(model.startAtText == "1")
    #expect(model.isWorking)
    #expect(model.statusLine == "Working out what would change…")
    #expect(!model.canApply)

    await model.preview()
    #expect(!model.isWorking)
    #expect(model.statusLine == "2 of 3 dives would be renumbered.")
    #expect(model.changes.map(\.newDiveNumber) == [47, 48])
    #expect(model.canApply)
    #expect(
      transport.requests.last?.json == .object(["start_at": .number(1), "dry_run": .bool(true)]))
  }

  @Test func theFirstDayIsSentAsTheInstantItBegins() async throws {
    let transport = try transport()
    let model = model(
      transport,
      defaults: RenumberDefaults(startAt: 47, fromDate: CalendarDate(year: 2023, month: 1, day: 1)))
    await model.preview()
    let sent = try KitFixture.data("request-dives-renumber")
    #expect(transport.requests.last?.json == (try JSONValue.parse(sent)))
  }

  @Test func aPreviewForOtherFieldsIsNoPreview() async throws {
    let model = model(try transport())
    await model.preview()
    model.startAtText = "12"
    #expect(model.isWorking)
    #expect(model.changes.isEmpty)
    #expect(!model.canApply)
    #expect(await model.apply() == nil)
  }

  @Test func aStartOutOfRangeAsksForNothing() async throws {
    let transport = try transport()
    let model = model(transport)
    for text in ["", "0", "2147483648", "x"] {
      model.startAtText = text
      #expect(model.statusLine == "Enter a starting number from 1 to 2,147,483,647.")
      #expect(!model.isWorking)
      await model.preview()
    }
    #expect(transport.requests.isEmpty)
  }

  @Test func aLogAlreadyNumberedSoOrAnEmptyScopeSaysSo() async throws {
    let none = StubTransport(routes: [
      "POST dives/renumber": .json(#"{"dry_run":true,"dives_in_scope":4,"changes":[]}"#)
    ])
    let numbered = model(none)
    await numbered.preview()
    #expect(
      numbered.statusLine == "Your dives are already numbered this way — nothing would change.")
    #expect(!numbered.canApply)

    let empty = model(
      StubTransport(routes: [
        "POST dives/renumber": .json(#"{"dry_run":true,"dives_in_scope":0,"changes":[]}"#)
      ]))
    await empty.preview()
    #expect(empty.statusLine == "No dives fall in this range.")
  }

  @Test func aStartTooHighForTheLastDiveSaysTheServersSentence() async throws {
    let sentence =
      "Starting at 2147483647, the last of these 3 dives would be numbered past 2147483647."
    let model = model(
      StubTransport(routes: [
        "POST dives/renumber": .json(#"{"detail":"\#(sentence)"}"#, status: 422)
      ]))
    await model.preview()
    #expect(model.statusLine == sentence)
    #expect(!model.canApply)
  }

  @Test func anyOtherFailureIsAboutTheConnection() async throws {
    let model = model(StubTransport { _ in throw URLError(.notConnectedToInternet) })
    await model.preview()
    #expect(model.statusLine == "Couldn't load a preview. Check your connection and try again.")
  }

  @Test func renumberWritesWhatThePreviewShowed() async throws {
    let transport = try transport()
    let model = model(transport)
    await model.preview()
    #expect(await model.apply() == 2)
    #expect(transport.requests.last?.json?["dry_run"] == .bool(false))
    #expect(transport.requests.last?.json?["start_at"] == .number(1))
    #expect(model.applyError == nil)
  }

  @Test func aRefusedRenumberSaysWhy() async throws {
    let model = model(
      try transport(renumber: .json(#"{"detail":"Not now."}"#, status: 409)))
    await model.preview()
    #expect(await model.apply() == nil)
    #expect(model.applyError == "Not now.")
    #expect(model.canApply)
  }

  @Test func aRenumberRereadsEveryListOverTheAccount() async throws {
    let world = try OutboxWorld()
    let preview = try KitFixture.text("dives-renumber")
    world.server.override { request, _ in
      switch request.route {
      case "POST dives/renumber": return .json(preview)
      case "GET dives/numbering": return .json(try KitFixture.text("dives-numbering"))
      default: return nil
      }
    }
    try await world.load()
    let numbering = DiveNumberingModel(session: world.session)
    await numbering.load()
    #expect(world.server.count("GET dives/numbering") == 1)

    let model = RenumberModel(session: world.session, debounce: .zero)
    await model.preview()
    #expect(await model.apply() == 2)
    await numbering.reloading?.value
    #expect(world.server.count("GET dives/numbering") == 2)
  }
}
