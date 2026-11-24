import Foundation
import Observation

/// The one sheet that opens over whatever is in front from outside it: a tapped download
/// notification's screen, or a link's. One presenter for both, so the later arrival replaces the
/// earlier and neither is dropped.
@MainActor
@Observable
public final class ScreenPresenter {
  public enum Screen: Hashable, Sendable {
    case notice(DiveComputerNotice.Target)
    case link(AppLink.Screen)
  }

  public struct Opened: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let screen: Screen
  }

  /// The screen shown, until it is closed.
  public var opened: Opened?
  /// The simulator's `--link`, until the window takes it.
  @ObservationIgnored private var launchLink: URL?

  public init(launchLink: URL? = nil) {
    self.launchLink = launchLink
  }

  public func open(_ target: DiveComputerNotice.Target) {
    opened = Opened(screen: .notice(target))
  }

  public func open(_ screen: AppLink.Screen) {
    opened = Opened(screen: .link(screen))
  }

  /// An address handed to the app from outside: its screen opens, or the address comes back to
  /// be opened in the browser.
  public func receive(_ url: URL, state: Session.State) -> URL? {
    switch AppLinkRouter.action(for: url, from: .outside, state: state) {
    case .open(let screen):
      open(screen)
      return nil
    case .browser(let url):
      return url
    case .answer:
      // The router answers only a given link.
      return url
    }
  }

  /// The launch's link, once.
  public func takeLaunchLink() -> URL? {
    defer { launchLink = nil }
    return launchLink
  }
}
