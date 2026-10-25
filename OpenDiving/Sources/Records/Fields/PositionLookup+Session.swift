import OpenDivingKit

extension PositionLookup {
  /// Looks the position up through the session's server.
  func lookUp(
    session: Session, latitude: String, longitude: String,
    current: () -> (latitude: String, longitude: String, location: LocationWrite?),
    apply: (LocationWrite?) -> Void
  ) async {
    await lookUp(
      latitude: latitude, longitude: longitude, location: current().location,
      reverse: { latitude, longitude in
        let client = try session.requireClient()
        return try await client.geocodeReverse(latitude: latitude, longitude: longitude)
      }, current: current, apply: apply)
  }
}
