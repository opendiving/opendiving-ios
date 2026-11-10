import Foundation

/// Where the site finder's camera opens: the places it fits, or none, for the world. Each host
/// has its own rule — the sites map's and the dive form's — and the server has no part in either;
/// whatever the rule ends on, the opening is one move, made once its answer is in.
public struct SiteFinderOpening: Hashable, Sendable {
  /// A town's worth of map around a lone point.
  public static let pointZoom = 10.0
  public static let world = SiteFinderOpening(points: [])

  /// Empty for the world.
  public let points: [MapPoint]

  public init(points: [MapPoint]) {
    self.points = points
  }

  public var isWorld: Bool { points.isEmpty }

  /// The camera for a map `width` by `height` points: a lone point at ``pointZoom``, anything
  /// else fitted; the middle of what it fits, with no frame to fit it in yet.
  public func camera(width: Double, height: Double) -> MapCamera {
    guard let box = WebMercator.union(points.map(\.extent)) else { return .world }
    if points.count == 1, points[0].bounds == nil {
      return MapCamera(
        latitude: points[0].latitude, longitude: points[0].longitude, zoom: Self.pointZoom)
    }
    if width > 0, height > 0 { return MapCamera.fit(points, width: width, height: height) }
    return MapCamera(
      latitude: WebMercator.latitude(
        y: (WebMercator.y(latitude: box.south) + WebMercator.y(latitude: box.north)) / 2),
      longitude: WebMercator.wrap(longitude: (box.west + box.east) / 2), zoom: MapCamera.minZoom)
  }

  /// A place: its footprint where it has one.
  static func place(_ location: LocationRead?) -> SiteFinderOpening? {
    guard let location, let latitude = location.latitude, let longitude = location.longitude
    else { return nil }
    var bounds: LatLonBounds?
    if let south = location.bboxSouth, let north = location.bboxNorth,
      let west = location.bboxWest, let east = location.bboxEast
    {
      bounds = LatLonBounds(south: south, north: north, west: west, east: east)
    }
    return SiteFinderOpening(points: [
      MapPoint(name: location.name, latitude: latitude, longitude: longitude, bounds: bounds)
    ])
  }

  static func point(_ position: DeviceLocation, name: String = "") -> SiteFinderOpening {
    SiteFinderOpening(points: [
      MapPoint(name: name, latitude: position.latitude, longitude: position.longitude)
    ])
  }

  // MARK: - The sites map

  /// The sites map's rule: the phone's location where the diver allowed it; else the place of
  /// the first trip part whose dates hold `today`, in the trip list's order; else the last
  /// dive's — its entry fix, else its first site's pin; else the world.
  public static func sitesMap(
    location: DeviceLocation?, trips: [TripRead], dives: [DiveListItem], today: CalendarDate
  ) -> SiteFinderOpening {
    if let location { return point(location) }
    for trip in trips {
      for part in trip.parts where holds(today, start: part.startDate, end: part.endDate) {
        if let place = place(part.location) { return place }
      }
    }
    if let last = dives.first {
      if let latitude = last.entryLatitude, let longitude = last.entryLongitude {
        return point(DeviceLocation(latitude: latitude, longitude: longitude))
      }
      if let site = last.diveSites.first, let latitude = site.latitude,
        let longitude = site.longitude
      {
        return point(DeviceLocation(latitude: latitude, longitude: longitude), name: site.name)
      }
    }
    return .world
  }

  // MARK: - The dive form

  /// What the dive form's rule reads, which the form holds.
  public struct DiveFormFacts: Hashable, Sendable {
    /// The pins of the sites on the dive.
    public var sites: [MapPoint]
    /// The dive's entry fix, as its read carries it.
    public var fix: DeviceLocation?
    /// The parts of the dive's trip.
    public var parts: [TripLookupPart]
    /// The day the dive starts.
    public var start: CalendarDate?

    public init(
      sites: [MapPoint] = [], fix: DeviceLocation? = nil, parts: [TripLookupPart] = [],
      start: CalendarDate? = nil
    ) {
      self.sites = sites
      self.fix = fix
      self.parts = parts
      self.start = start
    }

    /// Whether the rule reaches the phone's location: neither the sites nor the fix place it.
    public var needsLocation: Bool { sites.isEmpty && fix == nil }
  }

  /// The dive form's rule: the dive's pinned sites, fitted; else the dive's fix; else the phone's
  /// location where the diver allowed it; else the place of the first part of the dive's trip
  /// whose dates hold the dive's start; else the world.
  public static func diveForm(_ facts: DiveFormFacts, location: DeviceLocation?)
    -> SiteFinderOpening
  {
    if !facts.sites.isEmpty { return SiteFinderOpening(points: facts.sites) }
    if let fix = facts.fix { return point(fix) }
    if let location { return point(location) }
    if let start = facts.start {
      for part in facts.parts where holds(start, start: part.startDate, end: part.endDate) {
        if let place = place(part.location) { return place }
      }
    }
    return .world
  }

  /// A part holds a day from its start through its end; a part with one date holds that day.
  static func holds(_ day: CalendarDate, start: CalendarDate?, end: CalendarDate?) -> Bool {
    guard let first = start ?? end, let last = end ?? start else { return false }
    return first <= day && day <= last
  }
}
