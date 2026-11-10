import Foundation

/// A species' photo as the life list and a species' page draw it: the kept bytes when the
/// phone has them, so a list shown once draws offline, and otherwise the server's, kept.
@MainActor
public enum SpeciesPhotos {
  /// Nil when the photo is neither kept nor reachable.
  public static func photo(_ uuid: UUID, version: String, session: Session) async -> Data? {
    let stores = AccountStores.current(session)
    if let stores, let kept = stores.cache.speciesPhoto(version: version) {
      if stores.loaded { stores.cache.touchSpeciesPhoto(version: version) }
      return kept
    }
    guard let client = try? session.routedClient(),
      let bytes = try? await client.speciesPhoto(uuid, version: version)
    else { return nil }
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeSpeciesPhoto(
      bytes.data, version: version)
    return bytes.data
  }
}
