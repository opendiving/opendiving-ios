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

  @Test func theDiveFormsSheetIsTitleCase() {
    #expect(SiteFinderText.diveFormTitle == "Find a Dive Site")
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
    #expect(style.source(withIdentifier: "finder-commons") is MLNShapeSource)
    #expect(style.layers.count > 1)
    #expect(
      (style.layer(withIdentifier: "finder-commons-counts") != nil) == (coordinator.fonts != nil))
    let points = CommonsDiveSitePoints(
      version: "v1", sources: [:],
      points: [
        CommonsDiveSitePoint(
          longitude: 34.5, latitude: 28.5, uuid: UUID(), name: "Canyon", source: "osm")
      ])
    coordinator.show(
      SiteFinderMap.Layers(commons: points, yours: [], selected: []), on: map)
    #expect(style.layer(withIdentifier: "finder-commons-points")?.isVisible == true)
    // *Your sites* hides the Commons layer, and the diver's stays.
    coordinator.show(
      SiteFinderMap.Layers(commons: nil, yours: [], selected: []), on: map)
    #expect(style.layer(withIdentifier: "finder-commons-points")?.isVisible == false)
    #expect(style.layer(withIdentifier: "finder-yours-points")?.isVisible == true)
  }
}
