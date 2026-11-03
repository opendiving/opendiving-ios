import Foundation

/// What the Dives tab's dive-computer button draws over a download left running: a ring of its
/// progress around the icon, in a colour for how the download stands.
public struct DiveComputerButtonContent: Hashable, Sendable {
  public enum Ring: Hashable, Sendable {
    /// Connecting, or a family that reports no progress.
    case indeterminate
    /// From 0 to 1.
    case fraction(Double)
  }

  public enum State: Hashable, Sendable {
    /// Connecting or downloading: the icon's bars rise in a loop.
    case working
    /// The time-zone question waits on the diver.
    case waiting
    /// The dives are kept, or there were none to keep.
    case succeeded
    /// Stopped short, or downloaded and kept nowhere.
    case failed
  }

  public let ring: Ring
  public let state: State
  /// What VoiceOver reads after the button's name: *Downloading 1 of 4 new dives, 25 percent*.
  public let accessibilityValue: String

  public init(ring: Ring, state: State, accessibilityValue: String) {
    self.ring = ring
    self.state = state
    self.accessibilityValue = accessibilityValue
  }

  @MainActor public init(_ model: DiveComputerModel) {
    switch model.phase {
    case .idle, .scanning, .connecting:
      self.init(
        ring: .indeterminate, state: .working,
        accessibilityValue: model.waitingText ?? model.connectingText
          ?? DiveComputerText.connecting)
    case .downloading:
      if let waiting = model.waitingText {
        self.init(
          ring: model.progress.map(Ring.fraction) ?? .indeterminate, state: .working,
          accessibilityValue: waiting)
        return
      }
      let text = model.downloadingText ?? DiveComputerText.connecting
      if let progress = model.progress {
        self.init(
          ring: .fraction(progress), state: .working,
          accessibilityValue: "\(text), \(Int((progress * 100).rounded())) percent")
      } else {
        self.init(ring: .indeterminate, state: .working, accessibilityValue: text)
      }
    case .askingTimeZone:
      self.init(
        ring: .fraction(1), state: .waiting, accessibilityValue: DiveComputerText.timeZoneQuestion)
    case .finished:
      let kind = model.outcome?.kind
      let failed = kind == .failed || kind == .notKept || kind == .cancelled
      self.init(
        ring: .fraction(1), state: failed ? .failed : .succeeded,
        accessibilityValue: model.outcome?.sentence ?? "")
    }
  }
}
