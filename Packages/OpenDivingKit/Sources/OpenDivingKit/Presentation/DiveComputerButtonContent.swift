import Foundation

/// What the profile's dive-computer button draws over a download the diver left running, or one a
/// connection started: a ring of its progress around the icon, in a colour for how it stands.
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
    /// A question waits on the diver: which dives to download, or the time zone.
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

  /// The screen's model, left mid-download: its walk, or the question about held dives.
  @MainActor public init(_ model: DiveComputerModel) {
    if model.phase == .askingTimeZone {
      self.init(
        ring: .fraction(1), state: .waiting, accessibilityValue: DiveComputerText.timeZoneQuestion)
    } else if let walk = model.walk {
      self.init(walk)
    } else {
      self.init(
        ring: .indeterminate, state: .working, accessibilityValue: DiveComputerText.connecting)
    }
  }

  @MainActor public init(_ walk: DiveComputerWalk) {
    switch walk.phase {
    case .connecting:
      self.init(
        ring: .indeterminate, state: .working,
        accessibilityValue: walk.waitingText ?? walk.connectingText ?? DiveComputerText.connecting)
    case .downloading:
      if let waiting = walk.waitingText {
        self.init(
          ring: walk.progress.map(Ring.fraction) ?? .indeterminate, state: .working,
          accessibilityValue: waiting)
        return
      }
      let text = walk.downloadingText
      if let progress = walk.progress {
        self.init(
          ring: .fraction(progress), state: .working,
          accessibilityValue: "\(text), \(Int((progress * 100).rounded())) percent")
      } else {
        self.init(ring: .indeterminate, state: .working, accessibilityValue: text)
      }
    case .choosingDives:
      self.init(
        ring: .fraction(1), state: .waiting, accessibilityValue: DiveComputerText.diveQuestion)
    case .askingTimeZone:
      self.init(
        ring: .fraction(1), state: .waiting, accessibilityValue: DiveComputerText.timeZoneQuestion)
    case .finished:
      let kind = walk.outcome?.kind
      let failed =
        kind == .failed || kind == .notKept || kind == .cancelled || kind == .notDownloaded
      self.init(
        ring: .fraction(1), state: failed ? .failed : .succeeded,
        accessibilityValue: walk.outcome?.sentence ?? "")
    }
  }
}
