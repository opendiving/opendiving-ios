import Foundation

/// The picture of an account a person of the diver's is connected to, of one under *Added you*,
/// or of a connect link's owner: the route it is asked for by, and its version, which is its
/// digest.
public struct ConnectedPicture: Hashable, Sendable {
  public enum Source: Hashable, Sendable {
    /// One of the diver's people, connected to the account.
    case person(UUID)
    /// An account under *Added you*, by its public id.
    case addedYou(UUID)
    /// A connect link's owner, by the link's token.
    case connectLink(String)
  }

  public let source: Source
  public let version: String

  public init(source: Source, version: String) {
    self.source = source
    self.version = version
  }

  /// A person's, where they are connected to an account that has a picture.
  public static func of(_ person: PersonRead) -> ConnectedPicture? {
    person.avatarSha256.map { ConnectedPicture(source: .person(person.uuid), version: $0) }
  }

  /// An *Added you* row's account's, where it has one.
  public static func of(_ row: AddedYouRow) -> ConnectedPicture? {
    row.avatarSha256.map { ConnectedPicture(source: .addedYou(row.uuid), version: $0) }
  }

  /// A connect link's owner's, where they have one.
  public static func of(_ owner: ConnectLinkOwnerForYou, token: String) -> ConnectedPicture? {
    owner.avatarSha256.map { ConnectedPicture(source: .connectLink(token), version: $0) }
  }
}

/// A connected account's picture as the phone draws it: the kept bytes of the version a read
/// names, so a list shown once draws offline, and otherwise the server's, kept. Only the version
/// the latest read names is ever drawn, so once a read says the tie is gone no kept copy shows.
@MainActor
public enum ConnectedPictures {
  /// Nil when the picture is neither kept nor reachable.
  public static func picture(_ picture: ConnectedPicture, session: Session) async -> Data? {
    let stores = AccountStores.current(session)
    if let stores, let kept = stores.cache.connectedPicture(version: picture.version) {
      if stores.loaded { stores.cache.touchConnectedPicture(version: picture.version) }
      return kept
    }
    guard let client = try? session.routedClient() else { return nil }
    let bytes: FetchedBytes
    do {
      switch picture.source {
      case .person(let uuid):
        bytes = try await client.personAvatar(uuid, version: picture.version)
      case .addedYou(let uuid):
        bytes = try await client.addedYouAvatar(uuid, version: picture.version)
      case .connectLink(let token):
        bytes = try await client.connectLinkAvatar(token, version: picture.version)
      }
    } catch {
      return nil
    }
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeConnectedPicture(
      bytes.data, version: picture.version)
    return bytes.data
  }
}
