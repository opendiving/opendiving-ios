import OpenDivingKit
import SwiftUI

/// A map fitted to a record's places, with no pan or zoom of its own: refitted when its frame or
/// its places change, and the whole world with nothing placed. The credit sits in its corner.
struct PlacesMapView: View {
  let style: MapStyleModel.Shown
  let points: [MapPoint]
  /// What a screen reader calls it. On the map and not its frame, so the credit's links stay
  /// reachable.
  let label: String

  @State private var size = CGSize.zero

  var body: some View {
    MapLibreView(
      styleJSON: style.styleJSON, pins: points,
      camera: MapCamera.fit(points, width: size.width, height: size.height), isInteractive: false
    )
    .accessibilityLabel(label)
    .onGeometryChange(for: CGSize.self) {
      $0.size
    } action: {
      size = $0
    }
    .overlay(alignment: .bottomTrailing) {
      MapCredit(credit: style.credit)
        .padding(4)
    }
  }
}

#Preview {
  PlacesMapView(
    style: .preview,
    points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
    label: "Map of the site"
  )
  .frame(height: 200)
}
