import Foundation
import OpenDivingKit
import Testing

/// The entry units a phone keeps per account, under the account's directory.
struct EntryUnitsStoreTests {
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("EntryUnitsStoreTests-\(UUID().uuidString)", isDirectory: true)
  private let origin = ServerOrigin("https://dive.example")!
  private let account = UUID()

  private var state: ServerStateStore {
    ServerStateStore(
      root: root, secrets: InMemorySecretStore(), activeOrigin: InMemoryActiveOriginStore())
  }

  @Test func whatIsSavedLoadsBack() throws {
    let store = EntryUnitsStore(store: state, origin: origin, account: account)
    #expect(store.load() == EntryUnits())

    var units = EntryUnits()
    units.toggle(.pressure, account: .metric)
    units.toggle(.weight, account: .metric)
    try store.save(units)
    #expect(EntryUnitsStore(store: state, origin: origin, account: account).load() == units)
    #expect(EntryUnitsStore(store: state, origin: origin, account: UUID()).load() == EntryUnits())
  }

  @Test func forgettingTheServerTakesThemWithIt() throws {
    let store = EntryUnitsStore(store: state, origin: origin, account: account)
    var units = EntryUnits()
    units.toggle(.depth, account: .imperial)
    try store.save(units)
    try state.forget(origin)
    #expect(store.load() == EntryUnits())
  }

  /// A dimension or a system this build does not know is a newer build's, and the rest stands.
  @Test func aStoredValueIsReadLeniently() throws {
    let data = Data(#"{"pressure":"imperial","speed":"imperial","depth":"kelvin"}"#.utf8)
    let units = try APICoding.decoder().decode(EntryUnits.self, from: data)
    #expect(units.overrides == ["pressure": .imperial])
  }
}
