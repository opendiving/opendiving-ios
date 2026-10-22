import MapKit
import OpenDivingKit
import SwiftUI

/// A map fitted to a record's places, with a dive computer's fixes drawn as rings so they
/// read as a different claim from a pinned site. No line joins them.
struct PlacesMapView: View {
  let points: [MapPoint]
  var fixes: [MapPoint] = []

  var body: some View {
    Map(initialPosition: .automatic) {
      ForEach(Array(points.enumerated()), id: \.offset) { _, point in
        Marker(point.name, systemImage: "mappin", coordinate: point.coordinate)
      }
      ForEach(Array(fixes.enumerated()), id: \.offset) { _, fix in
        Annotation(fix.name, coordinate: fix.coordinate) {
          Circle()
            .strokeBorder(Color.white, lineWidth: 2)
            .background(Circle().fill(Color.blue))
            .frame(width: 14, height: 14)
        }
      }
    }
  }
}

extension MapPoint {
  fileprivate var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

#Preview {
  PlacesMapView(
    points: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
    fixes: [MapPoint(name: "Exit", latitude: 28.5735, longitude: 34.5361)])
}
