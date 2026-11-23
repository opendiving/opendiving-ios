import Foundation
import Observation

@testable import OpenDivingKit

/// The rows above the logbook as a view draws them: read again each time something the last
/// reading observed changes, and only then.
@MainActor
final class RowsOnScreen {
  private(set) var rows: [DownloadRow] = []
  private let engine: DiveComputerEngine

  init(_ engine: DiveComputerEngine) {
    self.engine = engine
    draw()
  }

  private func draw() {
    rows = withObservationTracking {
      engine.downloadRows(units: .metric)
    } onChange: { [weak self] in
      Task { @MainActor in self?.draw() }
    }
  }
}
