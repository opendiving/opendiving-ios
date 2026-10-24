import Foundation

/// Where one account's ``EntryUnits`` are kept on this phone: `entry-units.json` in the
/// account's directory, so a sign-out keeps them and a forget removes them. Never sent.
public struct EntryUnitsStore: Sendable {
  let file: URL

  public init(store: ServerStateStore, origin: ServerOrigin, account: UUID) {
    file = store.directory(for: origin, account: account)
      .appendingPathComponent("entry-units.json", isDirectory: false)
  }

  /// What was stored, or no overrides when nothing readable was.
  public func load() -> EntryUnits {
    guard let data = try? Data(contentsOf: file) else { return EntryUnits() }
    return (try? APICoding.decoder().decode(EntryUnits.self, from: data)) ?? EntryUnits()
  }

  public func save(_ units: EntryUnits) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try APICoding.encoder().encode(units).write(to: file, options: .atomic)
  }
}
