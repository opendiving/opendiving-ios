import Observation

/// The full-screen location picker: a pin placed by a search pick, a tap, the phone's position or
/// pasted coordinates, and the place's name, which only a search or the geocoder supplies. Nothing
/// reaches the form until ``used`` is taken.
@MainActor
@Observable
public final class LocationPickerModel {
  public private(set) var picked: PickedLocation
  /// A Commons record picked in the search, shown in place of the pin until the next placing.
  public private(set) var offered: DiveSiteLookupItem?
  public private(set) var camera: MapCamera
  public private(set) var isLocating = false
  /// The geocoder is being asked what is at the pin.
  public private(set) var isNaming = false
  public private(set) var failure: LocationFailure?
  public var query: String
  public let search: PlaceSearchModel
  /// Whether the form opened with something the diver can take off.
  public let canClear: Bool
  /// The map's size in points, which a place's footprint is fitted to.
  @ObservationIgnored public var viewport = (width: 0.0, height: 0.0)

  /// The pin moved and nothing has named where it now is.
  private var isUnnamed = false
  /// A trip part's place is a name first, so a pin nothing names cannot be used; a site keeps its
  /// position either way.
  @ObservationIgnored private let needsPlace: Bool
  @ObservationIgnored private let lookup = PositionLookup()
  @ObservationIgnored private let reverse: PositionLookup.Reverse
  @ObservationIgnored private let locator: any LocationProvider
  @ObservationIgnored private var placing = 0

  public init(
    search: PlaceSearchModel, initial: PickedLocation, needsPlace: Bool = false,
    locator: any LocationProvider, reverse: @escaping PositionLookup.Reverse
  ) {
    self.search = search
    self.needsPlace = needsPlace
    self.locator = locator
    self.reverse = reverse
    picked = initial
    let position = PlaceSearch.position(latitude: initial.latitude, longitude: initial.longitude)
    camera = PinCamera(position: position).camera
    canClear = position != nil || initial.location != nil
    // A name with no position searches for itself straight away.
    query = position == nil ? initial.location?.name ?? "" : ""
  }

  /// Over the session's client.
  public convenience init(
    session: Session, search: PlaceSearchModel, initial: PickedLocation, needsPlace: Bool = false,
    locator: any LocationProvider
  ) {
    self.init(
      search: search, initial: initial, needsPlace: needsPlace, locator: locator,
      reverse: { latitude, longitude in
        let client = try session.requireClient()
        return try await client.geocodeReverse(latitude: latitude, longitude: longitude)
      })
  }

  public var position: DeviceLocation? {
    PlaceSearch.position(latitude: picked.latitude, longitude: picked.longitude)
  }

  /// What the map marks: the offered record where it has a position, or the pin.
  public var pin: MapPoint? {
    if let offered {
      guard let latitude = offered.latitude, let longitude = offered.longitude else { return nil }
      return MapPoint(name: offered.name, latitude: latitude, longitude: longitude)
    }
    return position.map {
      MapPoint(
        name: picked.location?.name ?? "The pin", latitude: $0.latitude, longitude: $0.longitude)
    }
  }

  /// The place at the pin, while it is known.
  public var placeName: String? {
    guard !isNaming, !(needsPlace && isUnnamed) else { return nil }
    return picked.location?.name
  }

  /// The line saying why a pin cannot be used.
  public var unnamedMessage: String? {
    needsPlace && isUnnamed && !isNaming
      ? "No place name found here. Search for one instead." : nil
  }

  public var canUse: Bool {
    guard offered == nil, !isNaming else { return false }
    return needsPlace ? !isUnnamed && picked.location != nil : position != nil
  }

  /// What the form takes: a looked-up name goes where the pin is, since a trip part's place has
  /// no other position.
  public var used: PickedLocation {
    var used = picked
    used.credit = lookup.credit(latitude: picked.latitude, longitude: picked.longitude)
    if needsPlace, used.location?.latitude == nil, let position {
      used.location?.latitude = position.latitude
      used.location?.longitude = position.longitude
    }
    return used
  }

  /// Opened on a position with no place, the geocoder is asked what is there.
  public func start() async {
    guard position != nil, picked.location == nil else { return }
    await place(latitude: picked.latitude, longitude: picked.longitude)
  }

  /// The map came to rest somewhere of the diver's choosing.
  public func moved(to camera: MapCamera) {
    self.camera = camera
  }

  /// Typing adds a character at a time, so only a change of several at once is a paste, as in the
  /// forms' coordinate boxes. Anything else is left to the search.
  public func queryChanged(from old: String, to new: String) async {
    guard new.count - old.count > 1 else { return }
    await placeCoordinates(in: new)
  }

  /// The keyboard's search key: coordinates typed by hand place the pin.
  public func submit() async {
    await placeCoordinates(in: query)
  }

  private func placeCoordinates(in text: String) async {
    guard let pair = PlaceSearch.coordinatePair(text),
      let position = PlaceSearch.position(latitude: pair.latitude, longitude: pair.longitude)
    else { return }
    clearSearch()
    focus(on: position)
    await place(latitude: pair.latitude, longitude: pair.longitude)
  }

  /// A tap, which the map is already looking at.
  public func tapped(latitude: Double, longitude: Double) async {
    let folded = PinCamera.folded(latitude: latitude, longitude: longitude)
    clearSearch()
    await place(
      latitude: PlaceSearch.placedText(folded.latitude),
      longitude: PlaceSearch.placedText(folded.longitude))
  }

  public func useMyLocation() async {
    isLocating = true
    failure = nil
    let here: DeviceLocation
    do {
      here = try await locator.currentLocation()
    } catch {
      isLocating = false
      failure = error
      return
    }
    isLocating = false
    clearSearch()
    focus(on: here)
    await place(
      latitude: PlaceSearch.placedText(here.latitude),
      longitude: PlaceSearch.placedText(here.longitude))
  }

  public func pick(_ pick: PlacePick) {
    clearSearch()
    failure = nil
    switch pick {
    case .geocode(let result):
      let place = PlaceSearch.location(of: result)
      offered = nil
      isNaming = false
      isUnnamed = false
      placing += 1
      picked.latitude = PlaceSearch.coordinateText(result.latitude)
      picked.longitude = PlaceSearch.coordinateText(result.longitude)
      picked.location = place
      lookup.adopt(
        latitude: picked.latitude, longitude: picked.longitude, credit: result.attribution)
      show(place)
    case .commons(let site):
      offered = site
      if let latitude = site.latitude, let longitude = site.longitude {
        focus(on: DeviceLocation(latitude: latitude, longitude: longitude))
      }
    }
  }

  /// A position that arrived without a name, and the geocoder asked what is there.
  private func place(latitude: String, longitude: String) async {
    offered = nil
    failure = nil
    picked.latitude = latitude
    picked.longitude = longitude
    isUnnamed = true
    isNaming = true
    placing += 1
    let mine = placing
    await lookup.lookUp(
      latitude: latitude, longitude: longitude, location: picked.location, reverse: reverse,
      current: { (picked.latitude, picked.longitude, picked.location) },
      apply: { location in
        picked.location = location
        isUnnamed = location == nil
      })
    if mine == placing { isNaming = false }
  }

  private func clearSearch() {
    query = ""
    search.clear()
  }

  /// A place by its footprint where it has one, since a country at a jetty's zoom is empty land.
  private func show(_ place: LocationWrite) {
    guard let point = place.mapPoint else { return }
    if point.bounds != nil, viewport.width > 0, viewport.height > 0 {
      camera = .fit([point], width: viewport.width, height: viewport.height)
    } else {
      focus(on: DeviceLocation(latitude: point.latitude, longitude: point.longitude))
    }
  }

  private func focus(on position: DeviceLocation) {
    camera = MapCamera(
      latitude: position.latitude, longitude: position.longitude,
      zoom: max(camera.zoom, MapCamera.placedZoom))
  }
}
