import Foundation
import OpenDivingKit
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// An applied import opened from the history, and the log of any import.
@MainActor
struct ImportDetailModelTests {
  private let uuid = UUID(uuidString: "01a1b5d5-0182-786a-bc62-ed7fe7907b7d")!
  private var route: String { "import/" + uuid.uuidString.lowercased() }
  private let numbering =
    #"{"total_dives":3,"lowest":1,"highest":3,"missing_count":0,"duplicate_count":0,"out_of_date_order_count":0,"is_sequential":true}"#
  private let tangled =
    #"{"total_dives":3,"lowest":1,"highest":2,"missing_count":0,"duplicate_count":1,"out_of_date_order_count":0,"is_sequential":false}"#

  @Test func loadsTheImportAndItsNumberingSentence() async throws {
    let applied = try KitFixture.text("import-applied")
    let model = ImportDetailModel(
      session: Session.stub(
        transport: StubTransport(routes: [
          "GET \(route)": .json(applied), "GET dives/numbering": .json(numbering),
        ])),
      uuid: uuid)
    await model.load()
    guard case .loaded(let read) = model.phase else {
      Issue.record("not loaded: \(model.phase)")
      return
    }
    #expect(read.isApplied)
    #expect(model.numbering == nil)
  }

  @Test func saysWhereTheImportTangledTheNumbering() async throws {
    let pending = try JSONSerialization.jsonObject(with: KitFixture.data("import-pending"))
    var object = pending as! [String: Any]
    object["status"] = "applied"
    let body = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    let model = ImportDetailModel(
      session: Session.stub(
        transport: StubTransport(routes: [
          "GET \(route)": .json(body), "GET dives/numbering": .json(tangled),
        ])),
      uuid: uuid)
    await model.load()
    #expect(model.numbering?.hasSuffix("Renumber them on the web, from the Dives page.") == true)
  }

  @Test func anImportGoneSinceFailsWithThe404() async {
    let model = ImportDetailModel(
      session: Session.stub(
        transport: StubTransport(routes: [
          "GET \(route)": .json(#"{"detail":"Not Found"}"#, status: 404)
        ])),
      uuid: uuid)
    await model.load()
    #expect(model.phase == .failed(.http(status: 404, message: "Not Found")))
  }

  private func deleting(_ response: StubTransport.Response) -> (ImportDetailModel, EventLog) {
    let seen = EventLog()
    let key = "DELETE \(route)"
    let transport = StubTransport { request in
      guard StubTransport.routeKey(request) == key else {
        return .json(#"{"detail":"Not Found"}"#, status: 404)
      }
      seen.append(request.url!.query ?? "")
      return response
    }
    return (ImportDetailModel(session: Session.stub(transport: transport), uuid: uuid), seen)
  }

  @Test func aDeleteNamesTheStatusItMeans() async {
    let (model, seen) = deleting(.json("", status: 204))
    #expect(await model.delete())
    #expect(model.deleteError == nil)
    #expect(seen.all == ["status=applied"])
  }

  @Test func anImportAlreadyGoneIsDeleted() async {
    let (model, _) = deleting(.json(#"{"detail":"Not Found"}"#, status: 404))
    #expect(await model.delete())
  }

  @Test func aRefusedDeleteSaysWhyAndStays() async {
    let (model, _) = deleting(.json(#"{"detail":"Not now."}"#, status: 409))
    #expect(await model.delete() == false)
    #expect(model.deleteError == "Not now.")
  }

  @Test func theLogLoadsWhatTheRouteSays() async throws {
    let notes = try KitFixture.text("import-notes")
    let model = ImportLogModel(
      session: Session.stub(transport: StubTransport(routes: ["GET \(route)/notes": .json(notes)])),
      uuid: uuid, written: true)
    await model.load()
    guard case .loaded(let content) = model.phase else {
      Issue.record("not loaded: \(model.phase)")
      return
    }
    #expect(content.dives.count == 2)
  }
}
