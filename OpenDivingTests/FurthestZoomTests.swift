import MapLibre
import OpenDivingKit
import Testing

@testable import OpenDiving

@MainActor
struct FurthestZoomTests {
  /// Counts the floors set on it, each of which moves a camera that sits on the floor.
  final class CountingMapView: MLNMapView {
    var floorsSet = 0
    override var minimumZoomLevel: Double {
      didSet { floorsSet += 1 }
    }
  }

  /// A 700-point map's floor is one MapLibre reads back a bit off what was set.
  @Test func aFloorReadBackOffWhatWasSetIsNotSetAgain() {
    let map = CountingMapView(frame: CGRect(x: 0, y: 0, width: 402, height: 700))
    let furthest = MapCamera.furthestZoom(height: 700)
    map.zoomOutNoFurtherThan(furthest)
    #expect(map.minimumZoomLevel != furthest)
    map.zoomOutNoFurtherThan(furthest)
    #expect(map.floorsSet == 1)
    map.zoomOutNoFurtherThan(furthest + 0.5)
    #expect(map.floorsSet == 2)
  }
}
