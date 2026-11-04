import CoreLocation
import OpenDivingKit
import SwiftUI

/// The form's pin on the instance's map, placed by a tap, and nothing where there is no map. The
/// credit for the place's name, where one was looked up, sits under it either way.
struct PinMap: View {
  let style: MapStyleModel.Shown?
  let name: String
  let latitude: String
  let longitude: String
  var credit: String?
  let onPick: (String, String) -> Void

  var body: some View {
    // Nothing at all where there is nothing to show, which a form's row would otherwise draw.
    if style != nil || credit != nil {
      VStack(alignment: .leading, spacing: 4) {
        if let style {
          PinMapFrame(style: style, name: name, position: position, onPick: onPick)
        }
        if let credit {
          AttributionLine(credits: [credit])
        }
      }
    }
  }

  private var position: DeviceLocation? {
    PlaceSearch.position(latitude: latitude, longitude: longitude)
  }

  /// Six decimals: about ten centimetres, finer than a tap can aim.
  static func text(_ value: Double) -> String {
    PlaceSearch.coordinateText((value * 1_000_000).rounded() / 1_000_000)
  }
}

private struct PinMapFrame: View {
  let style: MapStyleModel.Shown
  let name: String
  let position: DeviceLocation?
  let onPick: (String, String) -> Void

  /// Here rather than in the map, which a form's list can rebuild as it scrolls.
  @State private var camera: PinCamera

  init(
    style: MapStyleModel.Shown, name: String, position: DeviceLocation?,
    onPick: @escaping (String, String) -> Void
  ) {
    self.style = style
    self.name = name
    self.position = position
    self.onPick = onPick
    _camera = State(initialValue: PinCamera(position: position))
  }

  var body: some View {
    MapLibreView(
      styleJSON: style.styleJSON, pins: pins, camera: camera.camera,
      onCameraChange: { camera.moved(to: $0) }, onTap: place
    )
    .accessibilityLabel("Map. Tap to place \(name).")
    .overlay(alignment: .bottomTrailing) {
      MapCredit(credit: style.credit)
        .padding(4)
    }
    .frame(height: 220)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .onChange(of: position) { _, position in
      camera.follow(position)
    }
  }

  private var pins: [MapPoint] {
    position.map { [MapPoint(name: name, latitude: $0.latitude, longitude: $0.longitude)] } ?? []
  }

  private func place(_ coordinate: CLLocationCoordinate2D) {
    let folded = PinCamera.folded(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let latitude = PinMap.text(folded.latitude)
    let longitude = PinMap.text(folded.longitude)
    if let returning = PlaceSearch.position(latitude: latitude, longitude: longitude) {
      camera.picked(returning)
    }
    onPick(latitude, longitude)
  }
}

#Preview {
  PinMap(style: .preview, name: "the dive site", latitude: "28.5722", longitude: "34.5372") {
    _, _ in
  }
}
