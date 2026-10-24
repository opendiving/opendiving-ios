import Foundation
import Observation

/// The place looked up for a position the diver placed, and the credit it owes while it still
/// names that position (`useGeocodedLocation`). An answer is dropped when a newer placing or
/// pick came first, when the position moved meanwhile, or when the diver typed over the
/// Location: none of those is the question the lookup answered.
@MainActor
@Observable
public final class PositionLookup {
  public typealias Reverse =
    @MainActor (_ latitude: Double, _ longitude: Double) async throws -> ReverseGeocode

  private var credit: String?
  private var placed: Placed?
  @ObservationIgnored private var generation = 0

  private struct Placed: Equatable {
    let latitude: String
    let longitude: String
  }

  public init() {}

  /// The credit for the place at this position, if it is still the one looked up.
  public func credit(latitude: String, longitude: String) -> String? {
    placed == Placed(latitude: latitude, longitude: longitude) ? credit : nil
  }

  /// A pick that brought its own place — a search result, a catalogue row — and so needs no
  /// lookup; any lookup still out is moot.
  public func adopt(latitude: String, longitude: String, credit: String?) {
    generation += 1
    placed = Placed(latitude: latitude, longitude: longitude)
    self.credit = credit
  }

  /// Asks what is at the position and hands `apply` what the Location becomes, unless the
  /// answer is stale or says nothing. `current` reads the form as it is when the answer
  /// arrives.
  public func lookUp(
    latitude: String, longitude: String, location: LocationWrite?, reverse: Reverse,
    current: () -> (latitude: String, longitude: String, location: LocationWrite?),
    apply: (LocationWrite?) -> Void
  ) async {
    generation += 1
    let mine = generation
    placed = nil
    credit = nil
    guard let position = PlaceSearch.position(latitude: latitude, longitude: longitude),
      let outcome = try? await reverse(position.latitude, position.longitude)
    else { return }
    let now = current()
    guard mine == generation, now.latitude == latitude, now.longitude == longitude,
      now.location?.name == location?.name,
      let adopted = PlaceSearch.adopting(outcome, current: now.location)
    else { return }
    placed = Placed(latitude: latitude, longitude: longitude)
    credit = adopted.credit
    apply(adopted.location)
  }
}
