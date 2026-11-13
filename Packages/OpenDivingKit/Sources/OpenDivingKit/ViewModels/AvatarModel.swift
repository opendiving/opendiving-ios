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
  /// The version ``data`` holds, so a load that finds it shown reads nothing.
  public private(set) var version: String?

  public init(session: Session) {
    self.session = session
    if session.user?.avatarSha256 != nil, let kept = AccountStores.current(session)?.cache.avatar {
      data = kept.data
      version = kept.version
    }
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
      self.version = nil
      stores?.writableCache?.removeAvatar()
      return
    }
    if version == self.version { return }
    if let kept = stores?.cache.avatar, kept.version == version {
      show(kept.data, version: version)
      return
    }
    guard let bytes = try? await session.routedClient().avatar(version: version) else { return }
    show(bytes.data, version: version)
    cacheForAnswer(fetchedUnder: stores, session: session)?.writeAvatar(
      AccountCache.Avatar(version: version, data: bytes.data))
  }

  /// Loads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  private func show(_ data: Data, version: String) {
    self.data = data
    self.version = version
  }
}
