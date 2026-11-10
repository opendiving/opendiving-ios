import CoreLocation
import MapLibre
import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The site finder's screens host under the session, and its map builds its layers on a style.
@MainActor
struct SiteFinderScreensTests {
  private func host(_ view: some View, session: Session) -> UIView? {
    let host = UIHostingController(rootView: NavigationStack { view }.environment(session))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  /// A map with no size yet keeps its cover and its camera for its first layout.
  @Test func aMapWithNoSizeIsCoveredAndPlacedOnceLaidOut() {
    let map = MLNMapView(frame: .zero, styleJSON: MapStyleModel.Shown.preview.styleJSON)
    map.automaticallyAdjustsContentInset = false
    let coordinator = SiteFinderMap.Coordinator()
    coordinator.cover(map, with: UIEdgeInsets(top: 50, left: 0, bottom: 300, right: 0))
    coordinator.move(map, to: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 10), glides: false)
    #expect(map.contentInset == .zero)
    map.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
    coordinator.laidOut(map)
    #expect(map.contentInset.bottom == 300)
    #expect(abs(map.centerCoordinate.latitude - 28.5) < 1e-6)
    #expect(abs(map.centerCoordinate.longitude - 34.5) < 1e-6)
    #expect(abs(map.zoomLevel - 10) < 1e-6)
  }

  /// The panel rising leaves the map where it was, its camera now the middle of what shows.
  @Test func coveringTheMapMovesNothingOnScreen() throws {
    let map = MLNMapView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 640),
      styleJSON: MapStyleModel.Shown.preview.styleJSON)
    map.automaticallyAdjustsContentInset = false
    map.setCenter(
      CLLocationCoordinate2D(latitude: 28.5, longitude: 34.5), zoomLevel: 8, animated: false)
    let showingMiddle = CGPoint(x: 160, y: 170)
    let before = map.convert(showingMiddle, toCoordinateFrom: map)
    let coordinator = SiteFinderMap.Coordinator()
    coordinator.laidOut(map)
    coordinator.cover(map, with: UIEdgeInsets(top: 0, left: 0, bottom: 300, right: 0))
    #expect(map.contentInset.bottom == 300)
    let after = map.convert(showingMiddle, toCoordinateFrom: map)
    #expect(abs(after.latitude - before.latitude) < 1e-6)
    #expect(abs(after.longitude - before.longitude) < 1e-6)
    #expect(abs(map.centerCoordinate.latitude - before.latitude) < 1e-6)
  }

  @Test func theSheetHostsOverTheForm() {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let form = DiveFormModel(session: session, mode: .create)
    #expect(host(SiteFinderSheet(form: form, session: session), session: session) != nil)
  }

  /// A style whose labels name a font, so the clusters' counts are drawn in it.
  private static let labelledStyle = """
    {"version": 8, "glyphs": "https://glyphs.invalid/{fontstack}/{range}.pbf",
     "sources": {"s": {"type": "geojson", "data": {"type": "FeatureCollection", "features": []}}},
     "layers": [
       {"id": "water", "type": "background", "paint": {"background-color": "#7FB5C9"}},
       {"id": "label", "type": "symbol", "source": "s",
        "layout": {"text-field": "x", "text-font": ["Noto Sans Regular"]}}
     ]}
    """

  /// With a font named, the clusters' counts are drawn in it; without one, the circles alone.
  @Test(arguments: [false, true])
  func theMapAddsItsClusteredSourcesAndLayersOnceTheStyleLoads(labelled: Bool) async throws {
    let styleJSON = labelled ? Self.labelledStyle : MapStyleModel.Shown.preview.styleJSON
    let map = MLNMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 320), styleJSON: styleJSON)
    let coordinator = SiteFinderMap.Coordinator()
    coordinator.fonts = MapStyleFonts.textFont(in: styleJSON)
    map.delegate = coordinator
    coordinator.adopt(map)
    let window = UIWindow(frame: map.frame)
    window.addSubview(map)
    window.makeKeyAndVisible()
    for _ in 0..<200 where (map.style?.layers.count ?? 0) <= 1 {
      try await Task.sleep(for: .milliseconds(50))
    }
    let style = try #require(map.style)
    #expect(style.source(withIdentifier: "finder-sites") is MLNShapeSource)
    #expect(style.layers.count > 1)
    #expect((style.layer(withIdentifier: "finder-counts") != nil) == (coordinator.fonts != nil))
    for mark in DiveSiteMark.allCases {
      #expect(style.image(forName: "finder-pin-\(mark.rawValue)") != nil)
    }
    #expect(style.layer(withIdentifier: "finder-points") is MLNSymbolStyleLayer)
    #expect(style.layer(withIdentifier: "finder-clusters") is MLNSymbolStyleLayer)
    for mark in DiveSiteMark.allCases {
      for size in 0..<3 {
        #expect(style.image(forName: "finder-group-\(mark.rawValue)-\(size)") != nil)
      }
    }
  }

  /// The selected site stands on its own layer, left out of the others, which fade back until it
  /// is let go.
  @Test func aSelectedSiteIsDrawnOnItsOwnLayerOverTheFadedRest() async throws {
    let styleJSON = MapStyleModel.Shown.preview.styleJSON
    let map = MLNMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 320), styleJSON: styleJSON)
    let coordinator = SiteFinderMap.Coordinator()
    map.delegate = coordinator
    coordinator.adopt(map)
    let window = UIWindow(frame: map.frame)
    window.addSubview(map)
    window.makeKeyAndVisible()
    for _ in 0..<200 where map.style?.layer(withIdentifier: "finder-points") == nil {
      try await Task.sleep(for: .milliseconds(50))
    }
    let style = try #require(map.style)
    let uuid = UUID()
    let yours = [
      DiveSitePoint(
        longitude: 34.5, latitude: 28.5, uuid: uuid, name: "Canyon", owner: DiveSiteOwner.account)
    ]
    let points = try #require(style.layer(withIdentifier: "finder-points") as? MLNSymbolStyleLayer)
    let selected = try #require(style.source(withIdentifier: "finder-selected") as? MLNShapeSource)

    coordinator.show(.init(commons: nil, yours: yours, selected: uuid), on: map)
    #expect(style.layer(withIdentifier: "finder-selected") is MLNSymbolStyleLayer)
    #expect((selected.shape as? MLNShapeCollectionFeature)?.shapes.count == 1)
    #expect(points.predicate?.predicateFormat.contains(uuid.uuidString) == true)
    #expect(points.iconOpacity.constantValue as? Float == 0.35)

    coordinator.show(.init(commons: nil, yours: yours, selected: nil), on: map)
    #expect((selected.shape as? MLNShapeCollectionFeature)?.shapes.isEmpty == true)
    #expect(points.predicate?.predicateFormat.contains(uuid.uuidString) == false)
    #expect(points.iconOpacity.constantValue as? Float == 0.9)
  }
}
