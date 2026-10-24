import MapKit
import OpenDivingKit
import SwiftUI

/// The shared places map with the form's pin on it, refitted whenever the pin moves; a tap
/// places the pin there. The credit for the place's name, where one was looked up, sits under
/// it.
struct PinMap: View {
  let name: String
  let latitude: String
  let longitude: String
  var credit: String?
  let onPick: (String, String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      MapReader { proxy in
        PlacesMapView(points: points)
          .id(points)
          .onTapGesture { location in
            guard let coordinate = proxy.convert(location, from: .local) else { return }
            onPick(Self.text(coordinate.latitude), Self.text(coordinate.longitude))
          }
      }
      .frame(height: 220)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .accessibilityLabel("Map. Tap to place \(name).")
      if let credit {
        AttributionLine(credits: [credit])
      }
    }
  }

  private var points: [MapPoint] {
    guard let position = PlaceSearch.position(latitude: latitude, longitude: longitude) else {
      return []
    }
    return [MapPoint(name: name, latitude: position.latitude, longitude: position.longitude)]
  }

  /// Six decimals: about ten centimetres, finer than a tap can aim.
  static func text(_ value: Double) -> String {
    PlaceSearch.coordinateText((value * 1_000_000).rounded() / 1_000_000)
  }
}

#Preview {
  PinMap(name: "the dive site", latitude: "28.5722", longitude: "34.5372") { _, _ in }
}
