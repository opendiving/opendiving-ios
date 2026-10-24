import Foundation
import Testing

@testable import OpenDivingKit

/// A file the build cannot read is kept, never overwritten: the edit drafts and the inbox.
@MainActor
struct KeptFileTests {
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("KeptFileTests-\(UUID().uuidString)", isDirectory: true)
  private let origin = OutboxServer.origin
  private let account = OutboxServer.accountA

  private var store: ServerStateStore {
    ServerStateStore(
      root: root, secrets: InMemorySecretStore(), activeOrigin: InMemoryActiveOriginStore(origin))
  }

  private var drafts: DraftStore<DiveDraftValues> {
    DraftStore(store: store, origin: origin, account: account)
  }

  @Test func anEditDraftSurvivesItsStoreAndFollowsAResolution() throws {
    let site = RecordRef.local(UUID())
    let dive = RecordRef.server(UUID())
    var values = DiveDraftValues()
    values.notes = "half-written"
    values.diveSites = [site]
    // The site's create is queued, so the draft keeps naming it.
    let outbox = OutboxStore(store: store, origin: origin, account: account)
    var create = OutboxItem(
      operation: .createDiveSite(DiveSiteCreate(name: "Canyon")), sequence: 1, marked: false)
    create.creates = site
    try outbox.save(create)
    try drafts.save(values, for: dive)
    #expect(drafts.load(dive)?.diveSites == [site])

    let server = UUID()
    try outbox.record(OutboxStore.Resolution(local: site.uuid, server: server, sentence: nil))
    outbox.remove(create.id)
    let reopened = DraftStore<DiveDraftValues>(store: store, origin: origin, account: account)
    #expect(reopened.load(dive)?.notes == "half-written")
    #expect(reopened.load(dive)?.diveSites == [.server(server)])
    #expect(reopened.all().count == 1)
    reopened.remove(dive)
    #expect(reopened.load(dive) == nil)
  }

  @Test func anEditDraftOfAnUnknownShapeIsKeptBesideANewOne() throws {
    let folder = store.directory(for: origin, account: account)
      .appendingPathComponent("Drafts", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let strange = folder.appendingPathComponent("strange.json")
    let bytes = Data(#"{"shape":"from a later build"}"#.utf8)
    try bytes.write(to: strange)

    try drafts.save(DiveDraftValues(), for: .server(UUID()))
    #expect(drafts.unreadable() == ["strange.json"])
    #expect(try Data(contentsOf: strange) == bytes)
    drafts.removeUnreadable("strange.json")
    #expect(drafts.unreadable().isEmpty)
  }

  @Test func anInboxRecordOfAnUnknownShapeIsWrittenBackByEverySave() throws {
    let inbox = InboxStore(store: store, origin: origin, account: account)
    try inbox.save(InboxStore.Contents(files: [InboxFile(filename: "a.fit", byteSize: 1)]))
    let file = store.directory(for: origin, account: account)
      .appendingPathComponent("Inbox/inbox.json")
    var record = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    var files = record["files"] as! [Any]
    files.append(["from": "a later build", "flag": true])
    record["files"] = files
    try JSONSerialization.data(withJSONObject: record).write(to: file)

    var contents = inbox.load()
    #expect(contents.files.map(\.filename) == ["a.fit"])
    #expect(inbox.unreadableCount == 1)
    contents.files.append(InboxFile(filename: "b.fit", byteSize: 2))
    try inbox.save(contents)
    try inbox.save(InboxStore.Contents())

    #expect(inbox.load().files.isEmpty)
    #expect(inbox.unreadableCount == 1)
    let kept = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
    let entry = (kept["files"] as! [[String: Any]]).first
    #expect(entry?["from"] as? String == "a later build")
    #expect(entry?["flag"] as? Bool == true)
  }

  @Test func anInboxThatIsNotJSONIsMovedAsideNotOverwritten() throws {
    let inbox = InboxStore(store: store, origin: origin, account: account)
    let folder = store.directory(for: origin, account: account)
      .appendingPathComponent("Inbox", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("garbled".utf8).write(to: folder.appendingPathComponent("inbox.json"))

    #expect(inbox.load().files.isEmpty)
    try inbox.save(InboxStore.Contents(files: [InboxFile(filename: "a.fit", byteSize: 1)]))
    #expect(inbox.load().files.count == 1)
    let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
    let aside = try #require(names.first { $0.hasPrefix("inbox.unreadable-") })
    #expect(try Data(contentsOf: folder.appendingPathComponent(aside)) == Data("garbled".utf8))
  }
}
