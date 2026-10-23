import OpenDivingKit
import Testing

@MainActor
private final class FakeScreen: ScreenBrightness {
  var level: Double
  var writes: [Double] = []

  init(level: Double) {
    self.level = level
  }

  func currentLevel() -> Double { level }

  func setLevel(_ level: Double) {
    self.level = level
    writes.append(level)
  }
}

@MainActor
struct CardBrightnessTests {
  @Test func showingACardRaisesItAndDismissingRestoresIt() {
    let screen = FakeScreen(level: 0.3)
    let brightness = CardBrightness(screen: screen)
    brightness.cardShown()
    #expect(screen.level == 1)
    brightness.cardDismissed()
    #expect(screen.level == 0.3)
    #expect(screen.writes == [1, 0.3])
  }

  @Test func resigningActiveRestoresItAndComingBackRaisesItAgain() {
    let screen = FakeScreen(level: 0.4)
    let brightness = CardBrightness(screen: screen)
    brightness.cardShown()
    brightness.appResignedActive()
    #expect(screen.level == 0.4)
    screen.level = 0.6
    brightness.appBecameActive()
    #expect(screen.level == 1)
    brightness.cardDismissed()
    #expect(screen.level == 0.6)
  }

  @Test func withNoCardUpTheAppsComingAndGoingChangesNothing() {
    let screen = FakeScreen(level: 0.5)
    let brightness = CardBrightness(screen: screen)
    brightness.appBecameActive()
    brightness.appResignedActive()
    brightness.cardShown()
    brightness.cardDismissed()
    brightness.appBecameActive()
    brightness.cardDismissed()
    #expect(screen.writes == [1, 0.5])
  }

  @Test func restoringTwiceWritesOnce() {
    let screen = FakeScreen(level: 0.2)
    let brightness = CardBrightness(screen: screen)
    brightness.cardShown()
    brightness.appResignedActive()
    brightness.cardDismissed()
    #expect(screen.writes == [1, 0.2])
  }
}
