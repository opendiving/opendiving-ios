import Foundation
import Observation
import OpenDivingKit

/// Where a tapped download notification leads, until the screen it opened is closed.
@MainActor
@Observable
final class NoticeRoute {
  struct Opened: Identifiable, Hashable {
    let id = UUID()
    let target: DiveComputerNotice.Target
  }

  var opened: Opened?

  func open(_ target: DiveComputerNotice.Target) {
    opened = Opened(target: target)
  }
}
