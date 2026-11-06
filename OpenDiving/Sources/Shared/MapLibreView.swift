import CoreLocation
import MapLibre
import OpenDivingKit
import SwiftUI

/// A map drawn by MapLibre from a style's JSON, which has to go in as JSON: `MLNMapView` given no
/// style loads MapLibre's demo tiles, and given a URL could not send the route's bearer token. It
/// neither rotates nor tilts and carries none of MapLibre's ornaments, so what it owes in credit
/// is its host's to draw. A new style restyles the same map, and its pins stay.
struct MapLibreView: UIViewRepresentable {
  let styleJSON: String
  var pins: [MapPoint] = []
  /// Where the map looks. A change jumps it there; a gesture's move comes back through
  /// `onCameraChange`.
  let camera: MapCamera
  var isInteractive = true
  /// Told where a gesture came to rest.
  var onCameraChange: ((MapCamera) -> Void)?
  /// Told where a single tap landed; a double tap is the map's own, and zooms.
  var onTap: ((CLLocationCoordinate2D) -> Void)?
  /// Told where the pin was dragged to and let go. Without it the pin cannot be held.
  var onPinDrop: ((CLLocationCoordinate2D) -> Void)?

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
    map.isUserInteractionEnabled = isInteractive
    context.coordinator.styleJSON = styleJSON
    context.coordinator.listenForTaps(on: map)
    return map
  }

  func updateUIView(_ map: MLNMapView, context: Context) {
    let coordinator = context.coordinator
    coordinator.onCameraChange = onCameraChange
    coordinator.onTap = onTap
    coordinator.onPinDrop = onPinDrop
    if styleJSON != coordinator.styleJSON {
      coordinator.styleJSON = styleJSON
      map.styleJSON = styleJSON
    }
    coordinator.show(pins, on: map)
    coordinator.move(map, to: camera)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    var onCameraChange: ((MapCamera) -> Void)?
    var onTap: ((CLLocationCoordinate2D) -> Void)?
    var onPinDrop: ((CLLocationCoordinate2D) -> Void)?
    var styleJSON = ""

    private var pins: [MapPoint] = []
    /// The pin in hand, which a change of `pins` waits for.
    private var drag: PinDrag?
    private var pinsAwaitingDrop: [MapPoint]?
    /// The camera last asked for or last reported, which a host's `camera` differs from only
    /// when the host wants the map moved.
    private var camera: MapCamera?
    private var isMoving = false

    func listenForTaps(on map: MLNMapView) {
      let hold = UILongPressGestureRecognizer(target: self, action: #selector(held))
      hold.minimumPressDuration = 0.25
      hold.delegate = self
      map.addGestureRecognizer(hold)
      let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
      tap.require(toFail: hold)
      // The two gestures a second tap makes, which is all MapLibre's own single tap waits for.
      for gesture in map.gestureRecognizers ?? [] {
        let isDoubleTap = (gesture as? UITapGestureRecognizer)?.numberOfTapsRequired == 2
        if isDoubleTap || gesture is UILongPressGestureRecognizer {
          tap.require(toFail: gesture)
        }
      }
      map.addGestureRecognizer(tap)
    }

    func show(_ pins: [MapPoint], on map: MLNMapView) {
      guard drag == nil else {
        pinsAwaitingDrop = pins
        return
      }
      guard pins != self.pins else { return }
      self.pins = pins
      map.removeAnnotations(map.annotations ?? [])
      map.addAnnotations(
        pins.map { pin in
          let annotation = MLNPointAnnotation()
          annotation.coordinate = CLLocationCoordinate2D(
            latitude: pin.latitude, longitude: pin.longitude)
          annotation.title = pin.name
          return annotation
        })
    }

    func move(_ map: MLNMapView, to camera: MapCamera) {
      guard camera != self.camera else { return }
      self.camera = camera
      isMoving = true
      map.setCenter(
        CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
        zoomLevel: camera.zoom, animated: false)
      isMoving = false
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
      guard let map = tap.view as? MLNMapView else { return }
      onTap?(map.convert(tap.location(in: map), toCoordinateFrom: map))
    }

    /// Asked at touch-down, so only a touch on the pin can become a hold and any other waits for
    /// nothing.
    func gestureRecognizer(
      _ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
      guard onPinDrop != nil, let map = recognizer.view as? MLNMapView,
        let annotation = map.annotations?.first
      else { return false }
      return PinDrag.isOnPin(
        Self.point(map.convert(annotation.coordinate, toPointTo: map)),
        touch: Self.point(touch.location(in: map)))
    }

    func gestureRecognizer(
      _: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
      true
    }

    @objc private func held(_ hold: UILongPressGestureRecognizer) {
      guard let map = hold.view as? MLNMapView, let annotation = map.annotations?.first,
        let view = map.view(for: annotation) as? PinAnnotationView
      else { return }
      let finger = Self.point(hold.location(in: map))
      switch hold.state {
      case .began:
        let started = PinDrag(
          pin: Self.point(map.convert(annotation.coordinate, toPointTo: map)), finger: finger)
        drag = started
        // The map would otherwise pan under the finger that is moving the pin.
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIView.animate(withDuration: 0.2) { view.lift(by: started.offset) }
      case .changed:
        drag?.moved(to: finger)
        if let drag { view.lift(by: drag.offset) }
      case .ended:
        drag?.moved(to: finger)
        finishDrag(on: map, view: view, drops: true)
      default:
        finishDrag(on: map, view: view, drops: false)
      }
    }

    /// A drop leaves the pin drawn where it was let go until the host's new pins replace it.
    private func finishDrag(on map: MLNMapView, view: PinAnnotationView, drops: Bool) {
      let dropped = drops ? drag?.drop : nil
      drag = nil
      map.isScrollEnabled = true
      map.isZoomEnabled = true
      if let dropped {
        onPinDrop?(map.convert(CGPoint(x: dropped.x, y: dropped.y), toCoordinateFrom: map))
      } else {
        UIView.animate(
          withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0
        ) {
          view.settle()
        }
      }
      if let waiting = pinsAwaitingDrop {
        pinsAwaitingDrop = nil
        show(waiting, on: map)
      }
    }

    private static func point(_ point: CGPoint) -> PinDrag.Point {
      PinDrag.Point(x: point.x, y: point.y)
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated _: Bool) {
      guard !isMoving, let onCameraChange else { return }
      let reported = MapCamera(
        latitude: mapView.centerCoordinate.latitude,
        longitude: mapView.centerCoordinate.longitude, zoom: mapView.zoomLevel)
      camera = reported
      onCameraChange(reported)
    }

    func mapView(_: MLNMapView, viewFor annotation: any MLNAnnotation) -> MLNAnnotationView? {
      PinAnnotationView(annotation: annotation, reuseIdentifier: nil)
    }
  }
}

/// The shared marker on the map. Disabled, so a tap on it is a tap on the map and selects nothing.
private final class PinAnnotationView: MLNAnnotationView {
  private let marker = UIHostingController(rootView: MapMarker())

  override init(annotation: (any MLNAnnotation)?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    bounds = CGRect(x: 0, y: 0, width: MapMarker.diameter, height: MapMarker.diameter)
    isEnabled = false
    scalesWithViewingDistance = false
    isUserInteractionEnabled = false
    marker.safeAreaRegions = []
    marker.view.backgroundColor = .clear
    marker.view.frame = bounds
    addSubview(marker.view)
  }

  required init?(coder _: NSCoder) {
    nil
  }

  /// The marker in the finger's hand. Moved and not this view, whose place and transform belong
  /// to the map.
  func lift(by offset: PinDrag.Point) {
    marker.view.transform = CGAffineTransform(translationX: offset.x, y: offset.y)
      .scaledBy(x: 1.4, y: 1.4)
  }

  func settle() {
    marker.view.transform = .identity
  }
}

extension MapStyleModel.Shown {
  /// Water and nothing else, for a `#Preview`.
  static let preview = MapStyleModel.Shown(
    styleJSON: """
      {"version": 8, "sources": {}, "layers": [
        {"id": "water", "type": "background", "paint": {"background-color": "#7FB5C9"}}
      ]}
      """,
    credit: "[OpenFreeMap](https://openfreemap.org/)")
}

#Preview {
  MapLibreView(
    styleJSON: MapStyleModel.Shown.preview.styleJSON,
    pins: [MapPoint(name: "Blue Hole", latitude: 28.5722, longitude: 34.5372)],
    camera: MapCamera(latitude: 28.5722, longitude: 34.5372, zoom: MapCamera.placedZoom))
}
