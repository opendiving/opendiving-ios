import Foundation
import Observation

/// *Your connect link*: the diver's own link, which whoever opens it can connect to them by. Direct
/// calls, online only; every refusal is the API's sentence as it is.
///
/// It shows the phone's copy at once while it is read, and keeps it standing under
/// ``lastUpdated`` when the read fails. The token is a credential, so it is kept as a secret,
/// never in the cache, and goes when the session ends: a link whose token has gone is nothing
/// kept.
@MainActor
@Observable
public final class ConnectLinkModel {
  /// What the link's controls ask the diver to confirm.
  public enum LinkChange: Hashable, Sendable {
    case reset, remove
  }

  /// The diver's link, once ``isLinkRead``; nil there means there is none yet.
  public private(set) var link: ConnectLinkRead?
  /// A read of the link has landed.
  public private(set) var isLinkRead = false
  /// Why the last read of the link failed.
  public private(set) var linkLoadFailure: String?
  /// When the cache's copy of the link on screen was fetched; nil once a read has landed.
  private var linkFetchedAt: Date?
  /// The change waiting for the diver to confirm it.
  public var confirmingLink: LinkChange?
  public private(set) var isChangingLink = false
  /// Why the last create, reset or removal failed.
  public private(set) var linkFailure: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    if let stores = AccountStores.current(session),
      let entry = stores.cache.kept(.connectLink, of: KeptConnectLink?.self)
    {
      if let kept = entry.value {
        if let token = stores.store.connectLinkToken(for: stores.origin, account: stores.account) {
          link = ConnectLinkRead(token: token, createdAt: kept.createdAt)
          isLinkRead = true
          linkFetchedAt = entry.fetchedAt
        }
      } else {
        isLinkRead = true
        linkFetchedAt = entry.fetchedAt
      }
    }
  }

  /// When the phone's copy on screen was fetched, until a read lands in its place: the line
  /// saying how old it is stands while that read is on its way, and through one that fails.
  public var lastUpdated: Date? { linkFetchedAt }

  public func load() async {
    let stores = AccountStores.current(session)
    do {
      let link = try await session.routedClient().connectLink()
      linkLoadFailure = nil
      showLink(link, fetchedUnder: stores)
    } catch is CancellationError {
    } catch {
      linkLoadFailure = APIError(error).message
    }
  }

  /// Reads again each time a route appears, until the calling task is cancelled.
  public func followRoute() async {
    await session.connectivity.eachRouteAppearance { await load() }
  }

  /// The server's answer about the link, kept as its copy: the token as a secret first, so the
  /// cache never names a link whose token was not kept.
  private func showLink(_ link: ConnectLinkRead?, fetchedUnder before: AccountStores?) {
    self.link = link
    isLinkRead = true
    linkFetchedAt = nil
    guard let stores = storesForAnswer(fetchedUnder: before, session: session) else { return }
    do {
      try stores.store.setConnectLinkToken(
        link?.token, for: stores.origin, account: stores.account)
    } catch {
      stores.cache.removeKept(.connectLink)
      return
    }
    stores.cache.writeKept(link.map { KeptConnectLink(createdAt: $0.createdAt) }, .connectLink)
  }

  // MARK: - The link

  /// The address the link opens, on the server's own origin, where the web serves `/connect`.
  public var linkAddress: URL? {
    guard let link, let origin = session.state.origin else { return nil }
    return Self.address(token: link.token, on: origin)
  }

  nonisolated public static func address(token: String, on origin: ServerOrigin) -> URL {
    var components = URLComponents(url: origin.url, resolvingAgainstBaseURL: false)!
    components.path = "/connect/\(token)"
    components.query = nil
    // Built from an origin and a path, which always form a URL.
    return components.url!
  }

  /// The share sheet's title: the sentence the link's page greets a newcomer with.
  public var shareTitle: String { Self.shareTitle(name: session.user?.name) }

  nonisolated public static func shareTitle(name: String?) -> String {
    "\(name ?? "A diver") invited you to connect on OpenDiving"
  }

  /// What the pane adds about the instance: on one that admits only those invited, that the link
  /// admits a newcomer on the diver's allowance; nothing on one anyone may join, nor before the
  /// server has said which it is.
  public var instanceNote: String? { Self.instanceNote(session.server?.config) }

  nonisolated public static func instanceNote(_ config: InstanceConfigRead?) -> String? {
    guard let mode = config?.registrationMode, mode != "open" else { return nil }
    return newcomers
  }

  /// Makes the link, or resets it once the diver confirmed a reset.
  public func createLink() async {
    guard !isChangingLink else { return }
    confirmingLink = nil
    linkFailure = nil
    isChangingLink = true
    defer { isChangingLink = false }
    let stores = AccountStores.current(session)
    do {
      showLink(try await session.routedClient().createConnectLink(), fetchedUnder: stores)
    } catch {
      linkFailure = APIError(error).message
    }
  }

  /// A tap on `change`'s button. Each button's dialog is its own, and iOS never shows a dialog
  /// asked for while another is up, which would leave `change` waiting on a dialog nobody sees
  /// and its button dead. So a tap while any change waits only clears it, closing what is
  /// shown, and the next tap asks.
  public func askToConfirm(_ change: LinkChange) {
    confirmingLink = confirmingLink == nil ? change : nil
  }

  /// Carries out `change`, the one the confirmation named. It is handed in rather than read
  /// from ``confirmingLink``, which the dialog clears as it closes, before this runs.
  public func confirmLinkChange(_ change: LinkChange) async {
    switch change {
    case .reset: await createLink()
    case .remove: await removeLink()
    }
  }

  private func removeLink() async {
    guard !isChangingLink else { return }
    confirmingLink = nil
    linkFailure = nil
    isChangingLink = true
    defer { isChangingLink = false }
    let stores = AccountStores.current(session)
    do {
      try await session.routedClient().removeConnectLink()
      showLink(nil, fetchedUnder: stores)
    } catch {
      linkFailure = APIError(error).message
    }
  }

  // MARK: - What the pane says

  public static let title = "Your connect link"
  public static let showButton = "Connect link"
  public static let loading = "Loading your connect link…"
  public static let linkLoadFailed = "Couldn't load your connect link."
  public static let linkNone =
    "A link of your own lets whoever follows it add you to their people, connected to your"
    + " account. Show it as a QR code, AirDrop it, or text it to a friend."
  public static let linkCreate = "Create your connect link"
  public static let linkLive =
    "Whoever scans or follows this link can add you to their people. They see your name,"
    + " username and picture, and you see them under Added you. It keeps working until you reset"
    + " or remove it."
  nonisolated public static let newcomers =
    "Somebody without an account can create one here through it, which draws on your daily"
    + " allowance of invitations."
  public static let qrLabel = "QR code of your connect link"
  public static let resetTitle = "Reset your connect link"
  public static let resetMessage =
    "The link you have now stops working for anyone who has it, and a new link and QR code take"
    + " its place. People already connected to you stay connected."
  public static let resetButton = "Reset"
  public static let removeTitle = "Remove your connect link"
  public static let removeMessage =
    "The link stops working for anyone who has it. People already connected to you stay"
    + " connected, and you can make a new link later."
  public static let removeButton = "Remove"

  // MARK: - Somebody else's link

  /// Why the pane's scanner cannot run; the paste still can.
  public enum ScannerUnavailable: Hashable, Sendable {
    /// The phone has no camera that reads codes.
    case unsupported
    /// The camera is refused to the app, or restricted.
    case cameraRefused

    public var reason: String {
      switch self {
      case .unsupported: "This phone can't scan a code. Paste the link instead."
      case .cameraRefused:
        "OpenDiving isn't allowed to use the camera. Allow it in Settings to scan a code, or paste"
          + " the link instead."
      }
    }
  }

  public static let othersTitle = "Somebody else's link"
  public static let othersNote =
    "Scan their code or paste their link to add them to your people. Any link to a page the app"
    + " has opens here too."
  public static let scanButton = "Scan a code"
  public static let stopScanning = "Stop scanning"
  public static let scannerLabel = "Camera, reading a QR code"
}
