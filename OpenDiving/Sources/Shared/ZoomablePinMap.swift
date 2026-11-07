import OpenDivingKit
import SwiftUI

/// One pin on a map that zooms and pans and places nothing: no tap and no drop reach anything. The
/// credit sits in its corner.
struct ZoomablePinMap: View {
  let style: MapStyleModel.Shown
  let pin: MapPoint
  /// What a screen reader calls it. On the map and not its frame, so the credit's links stay
  /// reachable.
  let label: String

  var body: some View {
    MapLibreView(
      styleJSON: style.styleJSON, pins: [pin],
      camera: MapCamera(
        latitude: pin.latitude, longitude: pin.longitude, zoom: MapCamera.placedZoom)
    )
    .accessibilityLabel(label)
    .overlay(alignment: .bottomTrailing) {
      MapCredit(credit: style.credit)
        .padding(4)
    }
  }
}

#Preview {
  ZoomablePinMap(
    style: .preview, pin: MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372),
    label: "Map of the dive site"
  )
  .frame(height: 220)
}
