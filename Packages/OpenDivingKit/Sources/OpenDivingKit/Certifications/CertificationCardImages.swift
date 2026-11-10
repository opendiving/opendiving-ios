import Foundation

/// A card's stored sides as the list and a certification's page draw them: the kept bytes when
/// the phone has shown that version of the side, so a card shown once draws offline, and
/// otherwise the server's, kept under the account's cache, which drops them with the card.
@MainActor
public enum CertificationCardImages {
  /// Nil when the side has neither kept bytes for this version nor a route to fetch them.
  public static func bytes(
    of certification: UUID, _ file: CertificationFileInfo, session: Session
  ) async -> Data? {
    let stores = AccountStores.current(session)
    if let stores, let kept = stores.cache.cardImage(certification, file) {
      if stores.loaded { stores.cache.touchCardImages(certification) }
      return kept
    }
    guard let bytes = try? await fetch(certification, file, session: session) else { return nil }
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeCardImage(
      bytes, certification, file)
    return bytes
  }

  /// The side's bytes for a download: the kept copy of this version, or the server's.
  public static func download(
    of certification: UUID, _ file: CertificationFileInfo, session: Session
  ) async throws -> Data {
    if let kept = AccountStores.current(session)?.cache.cardImage(certification, file) {
      return kept
    }
    return try await fetch(certification, file, session: session)
  }

  private static func fetch(
    _ certification: UUID, _ file: CertificationFileInfo, session: Session
  ) async throws -> Data {
    let fetched = try await session.routedClient().certificationFile(
      certification, side: file.side, etag: nil)
    // Asked with no tag, the server always sends the bytes.
    guard case .fetched(let bytes, _) = fetched else {
      throw APIError.http(status: 304, message: nil)
    }
    return bytes.data
  }
}
