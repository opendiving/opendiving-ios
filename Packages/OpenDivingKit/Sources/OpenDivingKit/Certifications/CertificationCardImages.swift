import Foundation

/// A card's stored sides as the list and a certification's page draw them: the kept bytes when
/// the phone has shown that version of the side, so a card shown once draws offline, and
/// otherwise the server's, kept under the account's cache.
///
/// A side's version is its file's uuid and `updated_at` (`certificationFileVersion`): a
/// replaced side moves its `updated_at`, and one deleted and uploaded again has a new uuid, so
/// a version names its bytes and a new one is fetched. Only the last version of a side is kept,
/// and the sides of the most recently drawn ``limit`` certifications.
@MainActor
public enum CertificationCardImages {
  public static let limit = AccountCache.detailLimit

  /// Nil when the side has neither kept bytes for this version nor a route to fetch them.
  public static func bytes(
    of certification: UUID, _ file: CertificationFileInfo, session: Session
  ) async -> Data? {
    let stores = AccountStores.current(session)
    if let stores, let kept = kept(certification, file, in: stores.cache) {
      if stores.loaded { touch(certification, in: stores.cache) }
      return kept
    }
    guard let client = try? session.routedClient(),
      let fetched = try? await client.certificationFile(certification, side: file.side, etag: nil),
      case .fetched(let bytes, _) = fetched
    else { return nil }
    if let cache = cacheForAnswer(fetchedUnder: stores, session: session) {
      keep(bytes.data, certification, file, in: cache)
    }
    return bytes.data
  }

  /// The side's bytes from the server, kept or not, for a download: never an older version.
  public static func download(
    of certification: UUID, _ file: CertificationFileInfo, session: Session
  ) async throws -> Data {
    if let stores = AccountStores.current(session),
      let kept = kept(certification, file, in: stores.cache)
    {
      return kept
    }
    let fetched = try await session.routedClient().certificationFile(
      certification, side: file.side, etag: nil)
    guard case .fetched(let bytes, _) = fetched else {
      throw APIError.http(status: 404, message: nil)
    }
    return bytes.data
  }

  static func folder(_ certification: UUID, in cache: AccountCache) -> URL {
    cache.root.appendingPathComponent("card-images", isDirectory: true)
      .appendingPathComponent(certification.uuidString.lowercased(), isDirectory: true)
  }

  /// `front-<file uuid>-<updated_at's letters and digits>`, so no version is ever a path.
  static func name(_ file: CertificationFileInfo) -> String {
    let updated = (file.updatedAt?.wireValue ?? "").filter {
      $0.isASCII && ($0.isLetter || $0.isNumber)
    }
    return
      "\(file.side == "back" ? "back" : "front")-\(file.uuid.uuidString.lowercased())-\(updated)"
  }

  static func kept(_ certification: UUID, _ file: CertificationFileInfo, in cache: AccountCache)
    -> Data?
  {
    try? Data(contentsOf: folder(certification, in: cache).appendingPathComponent(name(file)))
  }

  private static func keep(
    _ data: Data, _ certification: UUID, _ file: CertificationFileInfo, in cache: AccountCache
  ) {
    let manager = FileManager.default
    let folder = folder(certification, in: cache)
    let name = name(file)
    let side = name.prefix { $0 != "-" } + "-"
    try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
    for older in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
    where older.hasPrefix(side) && older != name {
      try? manager.removeItem(at: folder.appendingPathComponent(older))
    }
    guard (try? data.write(to: folder.appendingPathComponent(name), options: .atomic)) != nil
    else { return }
    touch(certification, in: cache)
    prune(cache)
  }

  private static func touch(_ certification: UUID, in cache: AccountCache) {
    try? FileManager.default.setAttributes(
      [.modificationDate: Date()], ofItemAtPath: folder(certification, in: cache).path)
  }

  private static func prune(_ cache: AccountCache) {
    let manager = FileManager.default
    let root = cache.root.appendingPathComponent("card-images", isDirectory: true)
    guard let names = try? manager.contentsOfDirectory(atPath: root.path), names.count > limit
    else { return }
    let dated = names.map { name in
      let url = root.appendingPathComponent(name, isDirectory: true)
      let date = (try? manager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
      return (url, date ?? .distantPast)
    }
    for (url, _) in dated.sorted(by: { $0.1 < $1.1 }).prefix(names.count - limit) {
      try? manager.removeItem(at: url)
    }
  }
}
