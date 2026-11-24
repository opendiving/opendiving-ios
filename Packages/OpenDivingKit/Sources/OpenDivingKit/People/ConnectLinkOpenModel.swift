import Foundation
import Observation

/// Somebody's connect link, opened signed in: whose it is, asked of the server, and what follows
/// from it — that it is no longer active, that it is the diver's own, that its owner is in their
/// people already, or else the form that adds them. A direct read, online only, read again as a
/// route appears while there was none.
@MainActor
@Observable
public final class ConnectLinkOpenModel {
  public enum Phase: Hashable, Sendable {
    case loading
    /// There is no route to the server.
    case noRoute
    case failed(String)
    /// Reset or removed, or never a link.
    case gone
    case yours(ConnectLinkOwnerForYou)
    /// The diver's person connected to the owner.
    case alreadyIn(person: UUID, owner: ConnectLinkOwnerForYou)
    /// The form that adds the owner opens.
    case connect(ConnectLinkOwnerForYou)
  }

  public let token: String
  public private(set) var phase: Phase = .loading

  @ObservationIgnored private let session: Session

  public init(session: Session, token: String) {
    self.session = session
    self.token = token
  }

  public func load() async {
    do {
      guard let owner = try await session.routedClient().connectLinkOwner(token) else {
        phase = .gone
        return
      }
      phase =
        if owner.isYours {
          .yours(owner)
        } else if let person = owner.personUuid {
          .alreadyIn(person: person, owner: owner)
        } else {
          .connect(owner)
        }
    } catch is CancellationError {
    } catch {
      let error = APIError(error)
      phase = error.isUnreachable ? .noRoute : .failed(error.message)
    }
  }

  /// Reads, then reads again each time a route appears while the last read found none, until the
  /// calling task is cancelled.
  public func show() async {
    let seen = session.connectivity.routeAppearances
    await load()
    if phase == .noRoute, session.connectivity.routeAppearances != seen { await load() }
    await session.connectivity.eachRouteAppearance {
      if phase == .noRoute { await load() }
    }
  }

  /// The form that adds the owner, for ``Phase/connect(_:)``.
  public func form(_ owner: ConnectLinkOwnerForYou) -> ConnectPersonModel {
    ConnectPersonModel(session: session, connection: .link(token: token, owner: owner))
  }

  public func picture(_ owner: ConnectLinkOwnerForYou) -> ConnectedPicture? {
    .of(owner, token: token)
  }

  // MARK: - What the screen says

  public static let title = "Connect Link"
  public static let loading = "Reading the link…"
  public static let noRoute = "The link is read once the phone can reach the server."
  public static let goneTitle = "This connect link is no longer active"
  public static let goneMessage =
    "It was reset or removed. Ask whoever gave it to you for their new one."
  public static let failedTitle = "This connect link didn't load"
  public static let yoursTitle = "This is your own connect link"
  public static let yoursMessage = "Whoever opens it can add you to their people."
  public static let openYours = "Open your connect link"

  public static func alreadyInTitle(_ owner: ConnectLinkOwnerForYou) -> String {
    "\(owner.name) is in your people"
  }

  public static func alreadyInMessage(_ owner: ConnectLinkOwnerForYou) -> String {
    "Connected to @\(owner.username)."
  }

  public static func goTo(_ owner: ConnectLinkOwnerForYou) -> String {
    "Go to \(owner.name)"
  }
}
