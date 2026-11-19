import Foundation
import Observation

/// The *Dive Computers* screen's model for the signed-in app's whole life, so a download
/// keeps going when the diver leaves the screen, and the profile's button that leads back to it.
///
/// The screen reads ``model`` and reports its appearing and disappearing. Left mid-download,
/// the model is kept and ``button`` shows until the screen is seen again — through the end of
/// the download, so its outcome is not lost. Left otherwise, the model is closed and the next
/// visit starts a fresh one, as a new screen always did. A download a connection starts while
/// the screen is not shown draws the button as it runs, its outcome the notification's.
@MainActor
@Observable
public final class DiveComputerDownloads {
  @ObservationIgnored private var current: DiveComputerModel?
  /// Counts replacements of ``current``, which is kept out of observation so that making it
  /// lazily, while a view reads it, is no change a view has to answer.
  private var generation = 0
  private var screens = 0
  /// The screen was left while a download was in flight, and has not been seen since.
  private var leftBusy = false
  @ObservationIgnored private let engine: DiveComputerEngine
  @ObservationIgnored private let zone: TimeZone

  /// A model is made over `engine` when a visit needs a fresh one, never before the screen is
  /// first shown — the device's link asks for Bluetooth. `zone` is the phone's, which a test
  /// fixes.
  public init(engine: DiveComputerEngine, zone: TimeZone = .current) {
    self.engine = engine
    self.zone = zone
  }

  /// The model the screen shows: the one in flight or whose end is unseen, else a fresh one.
  public var model: DiveComputerModel {
    _ = generation
    if let current { return current }
    let fresh = DiveComputerModel(engine: engine, zone: zone)
    current = fresh
    return fresh
  }

  /// The download the profile's button draws while the screen is not shown: the one it was left
  /// in, else a walk nobody started, while it runs.
  public var button: DiveComputerButtonContent? {
    _ = generation
    guard screens == 0 else { return nil }
    if leftBusy, let current { return DiveComputerButtonContent(current) }
    guard let walk = engine.walk, !walk.watched, walk.isBusy else { return nil }
    return DiveComputerButtonContent(walk)
  }

  /// The screen came into view, the outcome of the download it shows now seen. Returns that
  /// outcome where it came while the screen was away.
  @discardableResult
  public func screenAppeared() -> DiveComputerModel.Outcome? {
    screens += 1
    defer { leftBusy = false }
    return leftBusy ? current?.outcome : nil
  }

  public func screenDisappeared() {
    screens = max(0, screens - 1)
    guard screens == 0, let current else { return }
    if current.isBusy {
      leftBusy = true
      current.screenLeftMidDownload()
    } else {
      drop()
    }
  }

  /// The session changed: what was in flight belongs to the account before.
  public func sessionChanged() {
    drop()
  }

  private func drop() {
    current?.close()
    current = nil
    leftBusy = false
    generation += 1
  }
}
