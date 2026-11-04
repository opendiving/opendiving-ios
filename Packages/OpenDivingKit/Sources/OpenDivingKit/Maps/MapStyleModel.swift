import Observation

/// A form's map: the instance's basemap style and the credit it owes, or no map at all.
///
/// A held style with a held credit shows at once, before the instance has said whether it has
/// one. A style is drawn only where it draws tiles and names their credit. One that cannot be had
/// leaves what is held, or no map, and is asked for again only when the form next appears.
@MainActor
@Observable
public final class MapStyleModel {
  public struct Shown: Hashable, Sendable {
    public let styleJSON: String
    /// A markdown link.
    public let credit: String

    public init(styleJSON: String, credit: String) {
      self.styleJSON = styleJSON
      self.credit = credit
    }
  }

  public private(set) var shown: Shown?
  /// What a form has to place a pin with, and to say so.
  public var hasMap: Bool { shown != nil }

  @ObservationIgnored private let session: Session
  /// Bumped by every ``show(_:)``, so one superseded by another while it waited lands nothing.
  @ObservationIgnored private var generation = 0

  public init(session: Session) {
    self.session = session
  }

  public func show(_ theme: MapTileTheme) async {
    generation += 1
    let current = generation
    guard let store = session.mapTileStore() else {
      shown = nil
      return
    }
    let heldStyle = await store.style(theme)
    let heldCredit = await store.credit()
    guard current == generation else { return }
    if let heldStyle, let heldCredit {
      shown = Shown(styleJSON: heldStyle, credit: heldCredit)
    }

    // No answer is no reason to take down what the phone holds.
    guard let config = await session.mapConfig() else { return }
    guard current == generation else { return }
    guard config.mapTiles == true, let named = config.mapAttribution else {
      shown = nil
      return
    }
    await store.remember(credit: named)

    let style = await store.fetchStyle(theme)
    guard current == generation, !Task.isCancelled else { return }
    shown = style.map { Shown(styleJSON: $0, credit: named) }
  }
}
