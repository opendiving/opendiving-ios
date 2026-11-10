import CoreLocation
import MapLibre
import OpenDivingKit
import SwiftUI

/// The site finder's map: every Commons record and the diver's own sites as one clustered shape
/// source, which MapLibre draws as a few circles where an annotation per site would be thousands
/// of views, each site a pin in its mark's colour. The selected site's pin stands larger over the
/// rest, which fade back. A group takes the colour of its highest mark. A cluster's tap fits its sites and a point's tap names it;
/// a long press is where a site is added.
struct SiteFinderMap: UIViewRepresentable {
  let styleJSON: String
  /// Where the map looks, at the middle of what `covered` leaves showing. A change jumps it there;
  /// every move comes back through `onCameraChange`, saying whether a gesture made it.
  let camera: MapCamera
  /// The move to `camera` glides there rather than jumping.
  var glides = false
  /// What the screen draws over the map, which a change leaves where it was.
  var covered = UIEdgeInsets.zero
  /// Nil leaves the Commons records off the map, the diver's saved ones staying.
  let commons: CommonsDiveSitePoints?
  let yours: [DiveSitePoint]
  let selected: UUID?
  let onCameraChange: (MapCamera, Bool) -> Void
  let onPoint: (UUID) -> Void
  /// A tap on the map that touched neither a site nor a group.
  var onMapTap: () -> Void = {}
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
    context.coordinator.isDark = context.environment.colorScheme == .dark
    context.coordinator.listen(on: map)
    context.coordinator.adopt(map)
    return map
  }

  func updateUIView(_ map: MLNMapView, context: Context) {
    let coordinator = context.coordinator
    coordinator.onCameraChange = onCameraChange
    coordinator.onPoint = onPoint
    coordinator.onMapTap = onMapTap
    coordinator.onLongPress = onLongPress
    if styleJSON != coordinator.styleJSON {
      coordinator.styleJSON = styleJSON
      coordinator.fonts = MapStyleFonts.textFont(in: styleJSON)
      coordinator.isDark = context.environment.colorScheme == .dark
      map.styleJSON = styleJSON
    }
    coordinator.show(Layers(commons: commons, yours: yours, selected: selected), on: map)
    coordinator.cover(map, with: covered)
    coordinator.move(map, to: camera, glides: glides)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// What the sources hold.
  struct Layers: Equatable {
    var commons: CommonsDiveSitePoints?
    var yours: [DiveSitePoint]
    var selected: UUID?

    static let empty = Layers(commons: nil, yours: [], selected: nil)
  }

  final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    var onCameraChange: ((MapCamera, Bool) -> Void)?
    var onPoint: ((UUID) -> Void)?
    var onMapTap: (() -> Void)?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var styleJSON = ""
    var fonts: [String]?
    /// The appearance the marks are drawn for, taken from SwiftUI with the style that matches it:
    /// the first style can load before the map is in a window to take traits from.
    var isDark = false

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
    /// A glide to `camera` has not landed yet.
    private var isGliding = false

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
      let sitesChanged =
        layers.commons?.version != drawn.commons?.version
        || (layers.commons == nil) != (drawn.commons == nil) || layers.yours != drawn.yours
      if sitesChanged {
        set(
          Source.sites,
          SiteFinderMapMark.marks(commons: layers.commons, yours: layers.yours).map {
            Self.feature($0.uuid, $0.latitude, $0.longitude, mark: $0.mark)
          }, style)
      }
      if sitesChanged || layers.selected != drawn.selected {
        select(
          layers.selected.flatMap {
            SiteFinderMapMark.mark(of: $0, commons: layers.commons, yours: layers.yours)
          }, in: style)
      }
      drawn = layers
    }

    /// The selected site's pin on a layer of its own, growing to its size over the others, its
    /// copy among them left out and the rest fading back; let go, it shrinks back before its copy
    /// returns. Nothing fades for a site the map has no point for.
    private func select(_ mark: SiteFinderMapMark?, in style: MLNStyle) {
      pinStep?.invalidate()
      pinStep = nil
      let opacity = NSExpression(forConstantValue: mark == nil ? 0.9 : Self.fadedOpacity)
      (style.layer(withIdentifier: Layer.points) as? MLNSymbolStyleLayer)?.iconOpacity = opacity
      (style.layer(withIdentifier: Layer.clusters) as? MLNSymbolStyleLayer)?.iconOpacity = opacity
      (style.layer(withIdentifier: Layer.counts) as? MLNSymbolStyleLayer)?.textOpacity = opacity
      guard let mark else {
        let letGo = { [weak self, weak style] in
          guard let self, let style else { return }
          set(Source.selected, [], style)
          points(in: style, leavingOut: nil)
        }
        if pinScale == 1 { letGo() } else { scalePin(to: 1, in: style, then: letGo) }
        return
      }
      set(
        Source.selected, [Self.feature(mark.uuid, mark.latitude, mark.longitude, mark: mark.mark)],
        style)
      points(in: style, leavingOut: mark.uuid)
      pinScale = 1
      scalePin(to: Self.selectedScale, in: style) {}
    }

    private func points(in style: MLNStyle, leavingOut uuid: UUID?) {
      (style.layer(withIdentifier: Layer.points) as? MLNSymbolStyleLayer)?.predicate =
        uuid.map {
          NSPredicate(format: "cluster != YES AND %K != %@", Self.uuidKey, $0.uuidString)
        } ?? NSPredicate(format: "cluster != YES")
    }

    /// The other sites fading back and in as one is selected and let go, with its pin's growth.
    private static let fade = MLNTransition(duration: pinDuration, delay: 0)

    /// How far the other sites fade back while one is selected.
    private static let fadedOpacity = 0.35
    /// The selected pin's size against the others'.
    private static let selectedScale = 1.35
    private static let pinDuration = 0.2

    /// The selected pin's size now, which a step of its animation moves on from.
    private var pinScale = 1.0
    private var pinStep: PinStep?

    /// Takes the selected pin to `scale` over ``pinDuration``, a frame at a time: its size is a
    /// layout property, which the style does not animate as it does the fade.
    private func scalePin(to scale: Double, in style: MLNStyle, then done: @escaping () -> Void) {
      let from = pinScale
      pinStep = PinStep(duration: Self.pinDuration) { [weak self, weak style] progress in
        guard let self, let style else { return }
        pinScale = from + (scale - from) * progress
        (style.layer(withIdentifier: Layer.selected) as? MLNSymbolStyleLayer)?.iconScale =
          NSExpression(forConstantValue: pinScale)
        if progress >= 1 {
          pinStep = nil
          done()
        }
      }
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
      // A glide under way goes on to the middle of what shows now, rather than stopping where
      // it had got to.
      if isGliding, let camera {
        map.contentInset = covered
        map.setCenter(
          CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
          zoomLevel: camera.zoom, animated: true)
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

    func move(_ map: MLNMapView, to camera: MapCamera, glides: Bool) {
      guard camera != self.camera else { return }
      self.camera = camera
      guard isPlaced else { return }
      let center = CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)
      // A glide reports where it lands when it lands, through the delegate.
      if glides {
        isGliding = true
        map.setCenter(center, zoomLevel: camera.zoom, animated: true)
        return
      }
      isMoving = true
      map.setCenter(center, zoomLevel: camera.zoom, animated: false)
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
      // A change of appearance loads the other style, so the marks are drawn again for it.
      install(on: style, dark: isDark)
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

    private func install(on style: MLNStyle, dark: Bool) {
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
        style.setImage(SiteMapPin.image(mark, dark: dark), forName: Self.pinName(mark))
        for (size, group) in Self.groupSizes.enumerated() {
          style.setImage(
            SiteMapPin.group(mark, radius: group.radius, dark: dark),
            forName: Self.groupName(mark, size: size))
        }
      }
      addSites(to: style, dark: dark)
      addSelected(to: style)
    }

    private func addSites(to style: MLNStyle, dark: Bool) {
      guard let source = style.source(withIdentifier: Source.sites) else { return }
      let cluster = MLNSymbolStyleLayer(identifier: Layer.clusters, source: source)
      cluster.predicate = NSPredicate(format: "cluster == YES")
      cluster.iconImageName = Self.byMark { mark in
        var stops: [Int: String] = [:]
        for (size, group) in Self.groupSizes.enumerated().dropFirst() {
          stops[group.from] = Self.groupName(mark, size: size)
        }
        return NSExpression(
          format: "mgl_step:from:stops:(point_count, %@, %@)", Self.groupName(mark, size: 0),
          stops)
      }
      cluster.iconOpacity = NSExpression(forConstantValue: 0.9)
      cluster.iconOpacityTransition = Self.fade
      cluster.iconAllowsOverlap = NSExpression(forConstantValue: true)
      cluster.iconIgnoresPlacement = NSExpression(forConstantValue: true)
      style.addLayer(cluster)
      // A style's glyphs serve its own fonts alone; without one the circles still say where.
      if let fonts {
        let count = MLNSymbolStyleLayer(identifier: Layer.counts, source: source)
        count.predicate = NSPredicate(format: "cluster == YES")
        count.text = NSExpression(format: "CAST(point_count, 'NSString')")
        count.textFontNames = NSExpression(forConstantValue: fonts)
        count.textFontSize = NSExpression(forConstantValue: 12)
        count.textColor = NSExpression(forConstantValue: UIColor.white)
        count.textOpacityTransition = Self.fade
        count.textAllowsOverlap = NSExpression(forConstantValue: true)
        count.textIgnoresPlacement = NSExpression(forConstantValue: true)
        style.addLayer(count)
      }
      let point = MLNSymbolStyleLayer(identifier: Layer.points, source: source)
      point.predicate = NSPredicate(format: "cluster != YES")
      point.iconImageName = Self.byMark { NSExpression(forConstantValue: Self.pinName($0)) }
      point.iconOpacity = NSExpression(forConstantValue: 0.9)
      point.iconOpacityTransition = Self.fade
      point.iconAnchor = NSExpression(forConstantValue: NSValue(mlnIconAnchor: .bottom))
      point.iconOffset = NSExpression(
        forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: SiteMapPin.tipOffset)))
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

    /// A group's circle by how many sites it gathers: from that count, that radius.
    private static let groupSizes: [(from: Int, radius: CGFloat)] = [
      (0, 13), (25, 17), (250, 21),
    ]

    private static func groupName(_ mark: DiveSiteMark, size: Int) -> String {
      "finder-group-\(mark.rawValue)-\(size)"
    }

    /// The selected site's pin, a size up from the others, its tip still on its point.
    private func addSelected(to style: MLNStyle) {
      guard let source = style.source(withIdentifier: Source.selected) else { return }
      let pin = MLNSymbolStyleLayer(identifier: Layer.selected, source: source)
      pin.iconImageName = Self.byMark { NSExpression(forConstantValue: Self.pinName($0)) }
      pin.iconScale = NSExpression(forConstantValue: pinScale)
      pin.iconAnchor = NSExpression(forConstantValue: NSValue(mlnIconAnchor: .bottom))
      // Scaled with the icon, so the tip stays on the point at any size.
      pin.iconOffset = NSExpression(
        forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: SiteMapPin.tipOffset)))
      pin.iconAllowsOverlap = NSExpression(forConstantValue: true)
      pin.iconIgnoresPlacement = NSExpression(forConstantValue: true)
      style.addLayer(pin)
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

    /// How far in from the edge of what shows an opened group's outermost sites land, which
    /// leaves a pin's head room over its tip.
    private static let groupPadding = 32.0

    private static let uuidKey = "uuid"
    /// A point's ``DiveSiteMark`` raw value, and on a cluster the highest of its points'.
    private static let markKey = "mark"

    // MARK: - Touches

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
      guard let map = tap.view as? MLNMapView else { return }
      let point = tap.location(in: map)
      let hits = map.visibleFeatures(
        at: point, styleLayerIdentifiers: [Layer.clusters, Layer.points, Layer.selected])
      if let cluster = hits.first(where: { $0 is MLNPointFeatureCluster })
        as? MLNPointFeatureCluster,
        let shapes = map.style?.source(withIdentifier: Source.sites) as? MLNShapeSource
      {
        let splitting = shapes.zoomLevel(forExpanding: cluster)
        let sites = shapes.leaves(of: cluster, offset: 0, limit: cluster.clusterPointCount).map {
          MapPoint(name: "", latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        let showing = map.bounds.inset(by: map.contentInset)
        guard
          let camera = MapCamera.group(
            sites, splitting: splitting >= 0 ? splitting : map.zoomLevel + 1,
            width: showing.width, height: showing.height, padding: Self.groupPadding)
        else { return }
        zoomedIntoCluster = true
        map.setCenter(
          CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
          zoomLevel: camera.zoom, animated: true)
        return
      }
      if let id = hits.lazy.compactMap({ $0.attribute(forKey: Self.uuidKey) as? String }).first,
        let uuid = UUID(uuidString: id)
      {
        onPoint?(uuid)
      } else {
        onMapTap?()
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
      isGliding = false
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

  /// One animation a frame at a time, its progress eased out from 0 to 1, until it ends or is
  /// invalidated.
  final class PinStep: NSObject {
    private let duration: CFTimeInterval
    private let step: (Double) -> Void
    private var link: CADisplayLink?
    private var start: CFTimeInterval?

    init(duration: CFTimeInterval, step: @escaping (Double) -> Void) {
      self.duration = duration
      self.step = step
      super.init()
      let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
      link.add(to: .main, forMode: .common)
      self.link = link
    }

    func invalidate() {
      link?.invalidate()
      link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
      let start = start ?? link.timestamp
      self.start = start
      let elapsed = min(1, (link.timestamp - start) / duration)
      if elapsed >= 1 { invalidate() }
      step(1 - pow(1 - elapsed, 3))
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
