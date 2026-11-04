import MapLibre
import SwiftUI

/// A map drawn by MapLibre from a style's JSON, read when the map is built: given no style,
/// `MLNMapView` loads MapLibre's demo tiles. It pans and zooms but neither rotates nor tilts, and
/// carries none of MapLibre's ornaments, so what it owes in credit is its host's to draw.
struct MapLibreView: UIViewRepresentable {
  let styleJSON: String
  /// Told where a move of the camera came to rest.
  var onCameraChange: ((_ center: CLLocationCoordinate2D, _ zoom: Double) -> Void)?

  func makeUIView(context: Context) -> MLNMapView {
    let map = MLNMapView(frame: .zero, styleJSON: styleJSON)
    map.delegate = context.coordinator
    map.isRotateEnabled = false
    map.isPitchEnabled = false
    map.compassView.compassVisibility = .hidden
    map.showsScale = false
    map.logoView.isHidden = true
    map.attributionButton.isHidden = true
    return map
  }

  func updateUIView(_: MLNMapView, context: Context) {
    context.coordinator.onCameraChange = onCameraChange
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onCameraChange: onCameraChange)
  }

  final class Coordinator: NSObject, MLNMapViewDelegate {
    var onCameraChange: ((_ center: CLLocationCoordinate2D, _ zoom: Double) -> Void)?

    init(onCameraChange: ((_ center: CLLocationCoordinate2D, _ zoom: Double) -> Void)?) {
      self.onCameraChange = onCameraChange
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated _: Bool) {
      onCameraChange?(mapView.centerCoordinate, mapView.zoomLevel)
    }
  }
}

#Preview {
  MapLibreView(
    styleJSON: """
      {"version": 8, "sources": {}, "layers": [
        {"id": "water", "type": "background", "paint": {"background-color": "#7FB5C9"}}
      ]}
      """)
}
