/// What the location picker hands its form: the position as the form's text, the place, and the
/// credit the place's name owes.
public struct PickedLocation: Hashable, Sendable {
  public var latitude: String
  public var longitude: String
  public var location: LocationWrite?
  public var credit: String?
  /// The position was used before the geocoder answered, so its name is still the form's to find.
  public var awaitsName = false

  public init(
    latitude: String = "", longitude: String = "", location: LocationWrite? = nil,
    credit: String? = nil
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.location = location
    self.credit = credit
  }

  /// A place alone, placed where it says it is: a trip part's, which holds no position of its own.
  public init(place: LocationWrite?) {
    self.init(
      latitude: PlaceSearch.coordinateText(place?.latitude),
      longitude: PlaceSearch.coordinateText(place?.longitude), location: place)
  }
}
