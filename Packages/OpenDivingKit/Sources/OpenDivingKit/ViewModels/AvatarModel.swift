import Foundation
import Observation

/// The signed-in diver's picture: the phone's copy at once, and the version the account names
/// fetched when the phone does not hold it. The version is the picture's digest, so a copy of
/// it is never asked for again. With no picture, or before one is to hand, the view draws
/// ``initials``.
@MainActor
@Observable
public final class AvatarModel {
  /// The picture as the server sent it, a WebP.
  public private(set) var data: Data?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    data = session.user?.avatarSha256 == nil ? nil : Self.kept(session)?.data
  }

  public var initials: String? {
    session.user.flatMap { AvatarText.initials($0.name) }
  }

  /// Shows what the account names: its kept picture, a fetched one, or none. A fetch that fails,
  /// or that waits for a route, leaves the picture shown as it was.
  public func load() async {
    guard let user = session.user else { return }
    let stores = AccountStores.current(session)
    guard let version = user.avatarSha256 else {
      data = nil
      stores?.writableCache?.removeAvatar()
      return
    }
    if let kept = Self.kept(session), kept.version == version {
      data = kept.data
      return
    }
    guard let bytes = try? await session.routedClient().avatar(version: version) else { return }
    data = bytes.data
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeAvatar(
      AccountCache.Avatar(version: version, data: bytes.data))
  }

  /// Loads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  private static func kept(_ session: Session) -> AccountCache.Avatar? {
    AccountStores.current(session)?.cache.avatar
  }
}
