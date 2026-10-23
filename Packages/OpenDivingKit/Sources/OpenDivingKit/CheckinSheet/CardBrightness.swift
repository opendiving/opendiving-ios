/// The screen's brightness while a card is up full-screen: at maximum for as long as the
/// card is shown and the app is active, and put back where it was when the card is dismissed
/// or the app resigns active — the brightness is the phone's, not the app's.
@MainActor
public final class CardBrightness {
  private let screen: any ScreenBrightness
  private var isShowingCard = false
  /// The level to put back; non-nil exactly while this has raised it.
  private var savedLevel: Double?

  public init(screen: any ScreenBrightness) {
    self.screen = screen
  }

  public func cardShown() {
    isShowingCard = true
    raise()
  }

  public func cardDismissed() {
    isShowingCard = false
    restore()
  }

  public func appResignedActive() {
    restore()
  }

  /// Raises it again when the app comes back with the card still up, saving whatever level
  /// the diver set while away.
  public func appBecameActive() {
    if isShowingCard { raise() }
  }

  private func raise() {
    guard savedLevel == nil else { return }
    savedLevel = screen.currentLevel()
    screen.setLevel(1)
  }

  private func restore() {
    guard let savedLevel else { return }
    screen.setLevel(savedLevel)
    self.savedLevel = nil
  }
}
