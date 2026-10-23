import Foundation

/// What a trip's card, its page's hero and its *Trip Information* card print, from the
/// trip as the API reads it.
public enum TripSummary {
  /// One part as the *Trip Information* card lists it.
  public struct PartRow: Hashable, Sendable {
    /// Nil for a part with no place, which is still a row: dropping it would renumber the
    /// rest.
    public var place: String?
    /// Where the diver stayed, by its contact's name.
    public var accommodation: String?
    public var dates: String?

    public init(place: String? = nil, accommodation: String? = nil, dates: String? = nil) {
      self.place = place
      self.accommodation = accommodation
      self.dates = dates
    }
  }

  /// The trip's card on the trips list: its name, its facts, and the first three figures,
  /// so a trip with species shows those over its depth.
  public static func card(_ trip: TripRead, units: UnitSystem) -> RecordCardContent {
    RecordCardContent(
      title: trip.name, facts: facts(trip), figures: Array(figures(trip, units: units).prefix(3)))
  }

  /// The trip's page's head: the card the width of the screen, every figure, and a map of
  /// the places its parts went.
  public static func hero(_ trip: TripRead, units: UnitSystem) -> HeroContent {
    HeroContent(
      title: trip.name, facts: facts(trip), figures: figures(trip, units: units),
      points: points(trip))
  }

  /// The span of the trip's dated parts, then its places, each only where there is one —
  /// never the trip's creation date in place of a span.
  public static func facts(_ trip: TripRead) -> [Fact] {
    [
      TripText.span(spans(trip.parts)),
      TripText.locationsLabel(trip.parts.map { $0.location?.name }),
    ].compactMap { $0.map { Fact(text: $0) } }
  }

  /// The dives and their sites, at zero too; the species once there are some; the deepest
  /// point where there is one, in whole units as a dive card rounds its depths.
  public static func figures(_ trip: TripRead, units: UnitSystem) -> [Figure] {
    var figures = [
      Figure(label: "Dives", value: String(trip.diveCount)),
      Figure(label: "Dive sites", value: String(trip.diveSiteCount)),
    ]
    if trip.speciesCount > 0 {
      figures.append(Figure(label: "Species seen", value: String(trip.speciesCount)))
    }
    if let maxDepth = trip.maxDepth {
      figures.append(
        Figure(label: "Max depth", value: UnitFormat.depth(maxDepth, units, decimals: 0)))
    }
    return figures
  }

  /// The parts' places that carry a position, in the diver's order.
  public static func points(_ trip: TripRead) -> [MapPoint] {
    trip.parts.compactMap { part in
      guard let location = part.location, let latitude = location.latitude,
        let longitude = location.longitude
      else { return nil }
      return MapPoint(name: location.name, latitude: latitude, longitude: longitude)
    }
  }

  /// A part's section heading among the trip's dives: its place over its dates, or its
  /// dates alone for a part with no place, as the information card lists it by them.
  public static func partHeading(_ part: TripPartRead) -> (title: String, subtitle: String?) {
    let dates = TripText.partDates(start: part.startDate, end: part.endDate)
    if let place = part.location?.name { return (place, dates) }
    return (dates ?? "No place recorded", nil)
  }

  /// Every part, in the diver's order, with its accommodation named where `contacts` holds
  /// it.
  public static func partRows(_ trip: TripRead, contacts: [UUID: ContactRead]) -> [PartRow] {
    trip.parts.map { part in
      PartRow(
        place: part.location?.name,
        accommodation: part.accommodationUuid.flatMap { contacts[$0]?.name },
        dates: TripText.partDates(start: part.startDate, end: part.endDate))
    }
  }

  /// The trip's dive centres as one line, `Big Blue, Poseidon`; nil when none of them is
  /// in `contacts`.
  public static func diveCenters(_ trip: TripRead, contacts: [UUID: ContactRead]) -> String? {
    let names = trip.contactUuids.compactMap { contacts[$0]?.name }.filter { !$0.isEmpty }
    return names.isEmpty ? nil : names.joined(separator: ", ")
  }

  /// The contacts the trip's page names: each part's accommodation, then its dive centres.
  public static func contactUUIDs(_ trip: TripRead) -> [UUID] {
    var seen = Set<UUID>()
    return (trip.parts.compactMap(\.accommodationUuid) + trip.contactUuids).filter {
      seen.insert($0).inserted
    }
  }

  /// The parts' dates in the shape ``TripText`` takes them.
  public static func spans(_ parts: [TripPartRead]) -> [(start: CalendarDate?, end: CalendarDate?)]
  {
    parts.map { (start: $0.startDate, end: $0.endDate) }
  }
}
