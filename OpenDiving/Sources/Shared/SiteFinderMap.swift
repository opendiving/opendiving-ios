import CoreLocation
import MapLibre
import OpenDivingKit
import SwiftUI

/// The site finder's map: every Commons record and the diver's own sites as one clustered shape
/// source, which MapLibre draws as a few circles where an annotation per site would be thousands
/// of views, each site a pin in its mark's colour and the touched one ringed over them. A group
/// takes the colour of its highest mark. A cluster's tap zooms into it and a point's tap names it;
/// a long press is where a site is added.
struct SiteFinderMap: UIViewRepresentable {
  let styleJSON: String
  /// Where the map looks, at the middle of what `covered` leaves showing. A change jumps it there;
  /// every move comes back through `onCameraChange`, saying whether a gesture made it.
  let camera: MapCamera
  /// What the screen draws over the map, which a change leaves where it was.
  var covered = UIEdgeInsets.zero
  /// Nil leaves the Commons records off the map, the diver's saved ones staying.
  let commons: CommonsDiveSitePoints?
  let yours: [DiveSitePoint]
  let selected: SiteFinderPoint?
  let onCameraChange: (MapCamera, Bool) -> Void
  let onPoint: (UUID) -> Void
  var onLongPress: ((CLLocationCoordinate2D) -> Void)?

  func makeUIView(context: Context) -> MLNMapView {
    let map = LaidOutMapView(frame: .zero, styleJSON: styleJSON)
    map.onLayout = { [weak coordinator = context.coordinator, weak map] in
      guard let coordinator, let map else { return }
      coordinator.laidOut(map)
    }
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
        commons: commons, yours: yours,
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
    var selected: [MapPoint]

    static let empty = Layers(commons: nil, yours: [], selected: [])
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
    /// What covers a map too small yet to be covered, which its first layout applies.
    private var pendingCover: UIEdgeInsets?
    /// The map has had a size: before it, a move does not take and a report says the world.
    private var isPlaced = false
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
      guard let style = map.style, style.source(withIdentifier: Source.sites) != nil else {
        return
      }
      if layers.commons?.version != drawn.commons?.version
        || (layers.commons == nil) != (drawn.commons == nil) || layers.yours != drawn.yours
      {
        set(
          Source.sites,
          SiteFinderMapMark.marks(commons: layers.commons, yours: layers.yours).map {
            Self.feature($0.uuid, $0.latitude, $0.longitude, mark: $0.mark)
          }, style)
      }
      if layers.selected != drawn.selected {
        set(
          Source.selected,
          layers.selected.map { Self.feature(nil, $0.latitude, $0.longitude, mark: nil) }, style)
      }
      drawn = layers
    }

    /// The content inset is what puts the camera in the middle of what shows; changed, the map
    /// would keep its centre at the new middle, so it is handed the point already there instead.
    func cover(_ map: MLNMapView, with covered: UIEdgeInsets) {
      guard covered != (pendingCover ?? map.contentInset) else { return }
      let bounds = map.bounds
      let showing = bounds.inset(by: covered)
      // An inset taller than the map leaves no middle, and the camera's move then goes astray.
      guard isPlaced, showing.height > 0 else {
        pendingCover = covered
        return
      }
      pendingCover = nil
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

    /// The first layout with a size puts the camera there; a later one applies the cover a map too
    /// small for it waited for, the camera then in the middle of what shows.
    func laidOut(_ map: MLNMapView) {
      guard !map.bounds.isEmpty else { return }
      var covered: UIEdgeInsets?
      if let pending = pendingCover, map.bounds.inset(by: pending).height > 0 {
        covered = pending
      }
      guard !isPlaced || covered != nil else { return }
      isPlaced = true
      isMoving = true
      if let covered {
        pendingCover = nil
        map.contentInset = covered
      }
      if let camera {
        map.setCenter(
          CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
          zoomLevel: camera.zoom, animated: false)
      }
      isMoving = false
      DispatchQueue.main.async { [weak self, weak map] in
        guard let self, let map else { return }
        report(map, byGesture: false)
      }
    }

    func move(_ map: MLNMapView, to camera: MapCamera) {
      guard camera != self.camera else { return }
      self.camera = camera
      guard isPlaced else { return }
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
      guard let style = map.style, style.source(withIdentifier: Source.sites) == nil else {
        return
      }
      mapView(map, didFinishLoading: style)
    }

    private func install(on style: MLNStyle) {
      let clustered: [MLNShapeSourceOption: Any] = [
        .clustered: true, .clusterRadius: 44, .maximumZoomLevelForClustering: 12,
        .clusterProperties: [
          Self.markKey: [
            NSExpression(format: "max:({$featureAccumulated, %K})", Self.markKey),
            NSExpression(forKeyPath: Self.markKey),
          ]
        ],
      ]
      style.addSource(MLNShapeSource(identifier: Source.sites, features: [], options: clustered))
      style.addSource(MLNShapeSource(identifier: Source.selected, features: [], options: nil))
      for mark in DiveSiteMark.allCases {
        style.setImage(SiteMapPin.image(mark), forName: Self.pinName(mark))
      }
      addSites(to: style)
      addRing(Layer.selected, source: Source.selected, to: style)
    }

    private func addSites(to style: MLNStyle) {
      guard let source = style.source(withIdentifier: Source.sites) else { return }
      let cluster = MLNCircleStyleLayer(identifier: Layer.clusters, source: source)
      cluster.predicate = NSPredicate(format: "cluster == YES")
      cluster.circleColor = Self.byMark { NSExpression(forConstantValue: UIColor($0.color)) }
      cluster.circleOpacity = NSExpression(forConstantValue: 0.85)
      cluster.circleRadius = NSExpression(
        format: "mgl_step:from:stops:(point_count, 13, %@)", [25: 17, 250: 21])
      cluster.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
      cluster.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
      style.addLayer(cluster)
      // A style's glyphs serve its own fonts alone; without one the circles still say where.
      if let fonts {
        let count = MLNSymbolStyleLayer(identifier: Layer.counts, source: source)
        count.predicate = NSPredicate(format: "cluster == YES")
        count.text = NSExpression(format: "CAST(point_count, 'NSString')")
        count.textFontNames = NSExpression(forConstantValue: fonts)
        count.textFontSize = NSExpression(forConstantValue: 12)
        count.textColor = NSExpression(forConstantValue: UIColor.white)
        count.textAllowsOverlap = NSExpression(forConstantValue: true)
        count.textIgnoresPlacement = NSExpression(forConstantValue: true)
        style.addLayer(count)
      }
      let point = MLNSymbolStyleLayer(identifier: Layer.points, source: source)
      point.predicate = NSPredicate(format: "cluster != YES")
      point.iconImageName = Self.byMark { NSExpression(forConstantValue: Self.pinName($0)) }
      point.iconAnchor = NSExpression(forConstantValue: NSValue(mlnIconAnchor: .bottom))
      point.iconAllowsOverlap = NSExpression(forConstantValue: true)
      point.iconIgnoresPlacement = NSExpression(forConstantValue: true)
      style.addLayer(point)
    }

    /// `value` for the mark a point carries, or the highest a cluster gathers.
    private static func byMark(_ value: (DiveSiteMark) -> NSExpression) -> NSExpression {
      var cases: [NSExpression: NSExpression] = [:]
      for mark in DiveSiteMark.allCases where mark != .private {
        cases[NSExpression(forConstantValue: mark.rawValue)] = value(mark)
      }
      return NSExpression(
        forMLNMatchingKey: NSExpression(forKeyPath: markKey), in: cases, default: value(.private))
    }

    private static func pinName(_ mark: DiveSiteMark) -> String {
      "finder-pin-\(mark.rawValue)"
    }

    /// A ring around the pin's head, which stands over the point it marks.
    private func addRing(_ id: String, source sourceID: String, to style: MLNStyle) {
      guard let source = style.source(withIdentifier: sourceID) else { return }
      let ring = MLNCircleStyleLayer(identifier: id, source: source)
      ring.circleColor = NSExpression(forConstantValue: UIColor.clear)
      ring.circleRadius = NSExpression(forConstantValue: SiteMapPin.headRadius + 4)
      ring.circleTranslation = NSExpression(
        forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: -SiteMapPin.headHeight)))
      ring.circleStrokeColor = NSExpression(forConstantValue: UIColor.label)
      ring.circleStrokeWidth = NSExpression(forConstantValue: 3)
      style.addLayer(ring)
    }

    private func set(_ id: String, _ features: [MLNPointFeature], _ style: MLNStyle) {
      (style.source(withIdentifier: id) as? MLNShapeSource)?.shape =
        MLNShapeCollectionFeature(shapes: features)
    }

    private static func feature(
      _ uuid: UUID?, _ latitude: Double, _ longitude: Double, mark: DiveSiteMark?
    ) -> MLNPointFeature {
      let feature = MLNPointFeature()
      feature.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      var attributes: [String: Any] = [:]
      if let uuid { attributes[Self.uuidKey] = uuid.uuidString }
      if let mark { attributes[Self.markKey] = mark.rawValue }
      feature.attributes = attributes
      return feature
    }

    private static let uuidKey = "uuid"
    /// A point's ``DiveSiteMark`` raw value, and on a cluster the highest of its points'.
    private static let markKey = "mark"

    // MARK: - Touches

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
      guard let map = tap.view as? MLNMapView else { return }
      let point = tap.location(in: map)
      let hits = map.visibleFeatures(
        at: point, styleLayerIdentifiers: [Layer.clusters, Layer.points])
      if let cluster = hits.first(where: { $0 is MLNPointFeatureCluster })
        as? MLNPointFeatureCluster,
        let shapes = map.style?.source(withIdentifier: Source.sites) as? MLNShapeSource
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
      guard isPlaced else { return }
      let reported = MapCamera(
        latitude: map.centerCoordinate.latitude, longitude: map.centerCoordinate.longitude,
        zoom: map.zoomLevel)
      camera = reported
      onCameraChange?(reported, byGesture)
    }
  }

  /// A map that says when it is laid out, the first time being when it has a size to cover.
  final class LaidOutMapView: MLNMapView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
      super.layoutSubviews()
      onLayout?()
    }
  }

  private enum Source {
    static let sites = "finder-sites"
    static let selected = "finder-selected"
  }

  private enum Layer {
    static let clusters = "finder-clusters"
    static let counts = "finder-counts"
    static let points = "finder-points"
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
    ], selected: nil, onCameraChange: { _, _ in }, onPoint: { _ in })
}
