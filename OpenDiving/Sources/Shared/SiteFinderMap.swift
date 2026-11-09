import CoreLocation
import MapLibre
import OpenDivingKit
import SwiftUI

/// The site finder's map: every Commons record and the diver's own sites as clustered shape
/// sources, which MapLibre draws as a few circles where an annotation per site would be
/// thousands of views; the list's sites ringed over them, and the touched one ringed again. A
/// cluster's tap zooms into it and a point's tap names it; a long press is where a site is added.
struct SiteFinderMap: UIViewRepresentable {
  let styleJSON: String
  /// Where the map looks, at the middle of what `covered` leaves showing. A change jumps it there;
  /// every move comes back through `onCameraChange`, saying whether a gesture made it.
  let camera: MapCamera
  /// What the screen draws over the map, which a change leaves where it was.
  var covered = UIEdgeInsets.zero
  /// Nil hides the Commons layer.
  let commons: CommonsDiveSitePoints?
  let yours: [DiveSitePoint]
  let listed: [MapPoint]
  let selected: SiteFinderPoint?
  let onCameraChange: (MapCamera, Bool) -> Void
  let onPoint: (UUID) -> Void
  var onLongPress: ((CLLocationCoordinate2D) -> Void)?

  func makeUIView(context: Context) -> MLNMapView {
    let map = MLNMapView(frame: .zero, styleJSON: styleJSON)
    map.delegate = context.coordinator
    map.isRotateEnabled = false
    map.isPitchEnabled = false
    map.compassView.compassVisibility = .hidden
    map.showsScale = false
    map.logoView.isHidden = true
    map.attributionButton.isHidden = true
    map.minimumZoomLevel = MapCamera.minZoom
    map.maximumZoomLevel = MapCamera.maxZoom
    map.automaticallyAdjustsContentInset = false
    context.coordinator.styleJSON = styleJSON
    context.coordinator.fonts = MapStyleFonts.textFont(in: styleJSON)
    context.coordinator.listen(on: map)
    context.coordinator.adopt(map)
    return map
  }

  func updateUIView(_ map: MLNMapView, context: Context) {
    let coordinator = context.coordinator
    coordinator.onCameraChange = onCameraChange
    coordinator.onPoint = onPoint
    coordinator.onLongPress = onLongPress
    if styleJSON != coordinator.styleJSON {
      coordinator.styleJSON = styleJSON
      coordinator.fonts = MapStyleFonts.textFont(in: styleJSON)
      map.styleJSON = styleJSON
    }
    coordinator.show(
      Layers(
        commons: commons, yours: yours, listed: listed,
        selected: selected.map {
          [MapPoint(name: $0.name, latitude: $0.latitude, longitude: $0.longitude)]
        } ?? []),
      on: map)
    coordinator.cover(map, with: covered)
    coordinator.move(map, to: camera)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// What the sources hold.
  struct Layers: Equatable {
    var commons: CommonsDiveSitePoints?
    var yours: [DiveSitePoint]
    var listed: [MapPoint]
    var selected: [MapPoint]

    static let empty = Layers(commons: nil, yours: [], listed: [], selected: [])
  }

  final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    var onCameraChange: ((MapCamera, Bool) -> Void)?
    var onPoint: ((UUID) -> Void)?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var styleJSON = ""
    var fonts: [String]?

    /// What the style's sources hold now; emptied when a style loads, which brings none.
    private var drawn = Layers.empty
    private var wanted = Layers.empty
    private var camera: MapCamera?
    private var isMoving = false
    /// A tapped cluster's zoom, which is the diver's move although the map is told to make it.
    private var zoomedIntoCluster = false

    func listen(on map: MLNMapView) {
      let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
      hold.minimumPressDuration = 0.5
      map.addGestureRecognizer(hold)
      let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
      tap.require(toFail: hold)
      for gesture in map.gestureRecognizers ?? [] {
        if (gesture as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
          tap.require(toFail: gesture)
        }
      }
      map.addGestureRecognizer(tap)
    }

    func show(_ layers: Layers, on map: MLNMapView) {
      wanted = layers
      guard let style = map.style, style.source(withIdentifier: Source.commons) != nil else {
        return
      }
      if layers.commons?.version != drawn.commons?.version
        || (layers.commons == nil) != (drawn.commons == nil)
      {
        if let commons = layers.commons {
          set(
            Source.commons, commons.points.map { Self.feature($0.uuid, $0.latitude, $0.longitude) },
            style)
        }
        for id in [Layer.commonsClusters, Layer.commonsCounts, Layer.commonsPoints] {
          style.layer(withIdentifier: id)?.isVisible = layers.commons != nil
        }
      }
      if layers.yours != drawn.yours {
        set(
          Source.yours, layers.yours.map { Self.feature($0.uuid, $0.latitude, $0.longitude) }, style
        )
      }
      if layers.listed != drawn.listed {
        set(
          Source.listed, layers.listed.map { Self.feature(nil, $0.latitude, $0.longitude) }, style)
      }
      if layers.selected != drawn.selected {
        set(
          Source.selected, layers.selected.map { Self.feature(nil, $0.latitude, $0.longitude) },
          style)
      }
      drawn = layers
    }

    /// The content inset is what puts the camera in the middle of what shows; changed, the map
    /// would keep its centre at the new middle, so it is handed the point already there instead.
    func cover(_ map: MLNMapView, with covered: UIEdgeInsets) {
      guard covered != map.contentInset else { return }
      let bounds = map.bounds
      let showing = bounds.inset(by: covered)
      guard !bounds.isEmpty, showing.height > 0 else {
        map.contentInset = covered
        return
      }
      let middle = map.convert(CGPoint(x: showing.midX, y: showing.midY), toCoordinateFrom: map)
      isMoving = true
      map.contentInset = covered
      map.setCenter(middle, zoomLevel: map.zoomLevel, animated: false)
      isMoving = false
      DispatchQueue.main.async { [weak self, weak map] in
        guard let self, let map else { return }
        report(map, byGesture: false)
      }
    }

    func move(_ map: MLNMapView, to camera: MapCamera) {
      guard camera != self.camera else { return }
      self.camera = camera
      isMoving = true
      map.setCenter(
        CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
        zoomLevel: camera.zoom, animated: false)
      isMoving = false
      // After the update that asked for the move: the host's state is not changed inside one.
      DispatchQueue.main.async { [weak self, weak map] in
        guard let self, let map else { return }
        report(map, byGesture: false)
      }
    }

    // MARK: - The style

    func mapView(_ map: MLNMapView, didFinishLoading style: MLNStyle) {
      drawn = .empty
      install(on: style)
      show(wanted, on: map)
    }

    /// A style given as JSON can finish loading inside the map's initializer, before there is a
    /// delegate to hear it.
    func adopt(_ map: MLNMapView) {
      guard let style = map.style, style.source(withIdentifier: Source.commons) == nil else {
        return
      }
      mapView(map, didFinishLoading: style)
    }

    private func install(on style: MLNStyle) {
      let clustered: [MLNShapeSourceOption: Any] = [
        .clustered: true, .clusterRadius: 44, .maximumZoomLevelForClustering: 12,
      ]
      for id in [Source.commons, Source.yours] {
        style.addSource(MLNShapeSource(identifier: id, features: [], options: clustered))
      }
      for id in [Source.listed, Source.selected] {
        style.addSource(MLNShapeSource(identifier: id, features: [], options: nil))
      }
      addPoints(
        source: Source.commons, clusters: Layer.commonsClusters, counts: Layer.commonsCounts,
        points: Layer.commonsPoints, color: UIColor(Color.brandTeal), to: style)
      addPoints(
        source: Source.yours, clusters: Layer.yoursClusters, counts: Layer.yoursCounts,
        points: Layer.yoursPoints, color: UIColor(Color.brandCoral), to: style)
      addRing(Layer.listed, source: Source.listed, radius: 9, width: 2, to: style)
      addRing(Layer.selected, source: Source.selected, radius: 13, width: 3, to: style)
    }

    private func addPoints(
      source id: String, clusters: String, counts: String, points: String, color: UIColor,
      to style: MLNStyle
    ) {
      guard let source = style.source(withIdentifier: id) else { return }
      let cluster = MLNCircleStyleLayer(identifier: clusters, source: source)
      cluster.predicate = NSPredicate(format: "cluster == YES")
      cluster.circleColor = NSExpression(forConstantValue: color)
      cluster.circleOpacity = NSExpression(forConstantValue: 0.85)
      cluster.circleRadius = NSExpression(
        format: "mgl_step:from:stops:(point_count, 13, %@)", [25: 17, 250: 21])
      cluster.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
      cluster.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
      style.addLayer(cluster)
      // A style's glyphs serve its own fonts alone; without one the circles still say where.
      if let fonts {
        let count = MLNSymbolStyleLayer(identifier: counts, source: source)
        count.predicate = NSPredicate(format: "cluster == YES")
        count.text = NSExpression(format: "CAST(point_count, 'NSString')")
        count.textFontNames = NSExpression(forConstantValue: fonts)
        count.textFontSize = NSExpression(forConstantValue: 12)
        count.textColor = NSExpression(forConstantValue: UIColor.white)
        count.textAllowsOverlap = NSExpression(forConstantValue: true)
        count.textIgnoresPlacement = NSExpression(forConstantValue: true)
        style.addLayer(count)
      }
      let point = MLNCircleStyleLayer(identifier: points, source: source)
      point.predicate = NSPredicate(format: "cluster != YES")
      point.circleColor = NSExpression(forConstantValue: color)
      point.circleRadius = NSExpression(forConstantValue: 6)
      point.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
      point.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
      style.addLayer(point)
    }

    private func addRing(
      _ id: String, source sourceID: String, radius: Double, width: Double, to style: MLNStyle
    ) {
      guard let source = style.source(withIdentifier: sourceID) else { return }
      let ring = MLNCircleStyleLayer(identifier: id, source: source)
      ring.circleColor = NSExpression(forConstantValue: UIColor.clear)
      ring.circleRadius = NSExpression(forConstantValue: radius)
      ring.circleStrokeColor = NSExpression(forConstantValue: UIColor.label)
      ring.circleStrokeWidth = NSExpression(forConstantValue: width)
      style.addLayer(ring)
    }

    private func set(_ id: String, _ features: [MLNPointFeature], _ style: MLNStyle) {
      (style.source(withIdentifier: id) as? MLNShapeSource)?.shape =
        MLNShapeCollectionFeature(shapes: features)
    }

    private static func feature(_ uuid: UUID?, _ latitude: Double, _ longitude: Double)
      -> MLNPointFeature
    {
      let feature = MLNPointFeature()
      feature.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      if let uuid { feature.attributes = [Self.uuidKey: uuid.uuidString] }
      return feature
    }

    private static let uuidKey = "uuid"

    // MARK: - Touches

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
      guard let map = tap.view as? MLNMapView else { return }
      let point = tap.location(in: map)
      // The diver's layer is drawn over the Commons', so it answers first.
      for (source, layers) in [
        (Source.yours, [Layer.yoursClusters, Layer.yoursPoints]),
        (Source.commons, [Layer.commonsClusters, Layer.commonsPoints]),
      ] {
        let hits = map.visibleFeatures(at: point, styleLayerIdentifiers: Set(layers))
        if let cluster = hits.first(where: { $0 is MLNPointFeatureCluster })
          as? MLNPointFeatureCluster,
          let shapes = map.style?.source(withIdentifier: source) as? MLNShapeSource
        {
          let zoom = min(shapes.zoomLevel(forExpanding: cluster), MapCamera.maxZoom)
          zoomedIntoCluster = true
          map.setCenter(cluster.coordinate, zoomLevel: max(zoom, map.zoomLevel + 1), animated: true)
          return
        }
        if let id = hits.lazy.compactMap({ $0.attribute(forKey: Self.uuidKey) as? String }).first,
          let uuid = UUID(uuidString: id)
        {
          onPoint?(uuid)
          return
        }
      }
    }

    @objc private func held(_ hold: UILongPressGestureRecognizer) {
      guard hold.state == .began, let onLongPress, let map = hold.view as? MLNMapView else {
        return
      }
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      onLongPress(map.convert(hold.location(in: map), toCoordinateFrom: map))
    }

    // MARK: - Moves

    func mapView(
      _ map: MLNMapView, regionDidChangeWith reason: MLNCameraChangeReason, animated _: Bool
    ) {
      guard !isMoving else { return }
      let byFinger = !reason.subtracting([.programmatic, .transitionCancelled]).isEmpty
      report(map, byGesture: byFinger || zoomedIntoCluster)
      zoomedIntoCluster = false
    }

    private func report(_ map: MLNMapView, byGesture: Bool) {
      let reported = MapCamera(
        latitude: map.centerCoordinate.latitude, longitude: map.centerCoordinate.longitude,
        zoom: map.zoomLevel)
      camera = reported
      onCameraChange?(reported, byGesture)
    }
  }

  private enum Source {
    static let commons = "finder-commons"
    static let yours = "finder-yours"
    static let listed = "finder-listed"
    static let selected = "finder-selected"
  }

  private enum Layer {
    static let commonsClusters = "finder-commons-clusters"
    static let commonsCounts = "finder-commons-counts"
    static let commonsPoints = "finder-commons-points"
    static let yoursClusters = "finder-yours-clusters"
    static let yoursCounts = "finder-yours-counts"
    static let yoursPoints = "finder-yours-points"
    static let listed = "finder-listed"
    static let selected = "finder-selected"
  }
}

#Preview {
  SiteFinderMap(
    styleJSON: MapStyleModel.Shown.preview.styleJSON,
    camera: MapCamera(latitude: 28.5, longitude: 34.5, zoom: 8), commons: nil,
    yours: [
      DiveSitePoint(
        longitude: 34.5372, latitude: 28.5722, uuid: UUID(), name: "Blue Hole",
        owner: DiveSiteOwner.account)
    ], listed: [], selected: nil, onCameraChange: { _, _ in }, onPoint: { _ in })
}
