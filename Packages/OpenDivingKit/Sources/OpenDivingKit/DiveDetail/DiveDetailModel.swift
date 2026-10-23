import Foundation
import Observation

/// One dive's page as it loads: the dive, then what it names — its trip, its course, its
/// dive centre and the dives either side — each of which may fail without failing the page,
/// as the web hides a link it could not resolve.
@MainActor
@Observable
public final class DiveDetailModel {
  public enum Phase: Equatable, Sendable {
    case loading
    case loaded(DiveReadWithMixtures)
    case failed(APIError)
  }

  /// The dive on screen, or the one the pager is stepping to.
  public private(set) var diveUUID: UUID
  public private(set) var phase: Phase = .loading
  public private(set) var trip: TripRead?
  public private(set) var course: CourseRead?
  public private(set) var contact: ContactRead?
  public private(set) var neighbors: DiveNeighbors?
  /// A step of the pager is on its way; the dive being left stays on screen until it lands.
  public private(set) var isStepping = false

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var generation = 0

  public init(session: Session, diveUUID: UUID) {
    self.session = session
    self.diveUUID = diveUUID
  }

  /// The page's content in the account's units, once the dive has loaded.
  public var content: DiveDetailContent? {
    guard case .loaded(let dive) = phase else { return nil }
    return DiveDetailContent(
      dive: dive, trip: trip, course: course, contact: contact, people: session.people,
      units: session.units)
  }

  /// Loads the dive this model was opened on, or retries it.
  public func load() async {
    await load(diveUUID)
  }

  /// Steps to a neighbouring dive in place.
  public func show(_ uuid: UUID) async {
    guard uuid != diveUUID else { return }
    await load(uuid)
  }

  /// The species' photo, or nil when it cannot be had; the card then draws its backdrop.
  public func speciesPhoto(_ uuid: UUID, version: String) async -> Data? {
    guard let client = try? session.requireClient() else { return nil }
    return try? await client.speciesPhoto(uuid, version: version).data
  }

  private func load(_ uuid: UUID) async {
    generation += 1
    let generation = generation
    diveUUID = uuid
    neighbors = nil
    if case .loaded = phase { isStepping = true } else { phase = .loading }
    defer { if generation == self.generation { isStepping = false } }

    let client: APIClient
    let dive: DiveReadWithMixtures
    do {
      client = try session.requireClient()
      dive = try await client.dive(uuid)
    } catch {
      guard generation == self.generation else { return }
      phase = .failed(APIError(error))
      return
    }
    guard generation == self.generation else { return }
    (trip, course, contact) = (nil, nil, nil)
    phase = .loaded(dive)
    isStepping = false

    async let trip = dive.tripUuid.asyncMap { try? await client.trip($0) }
    async let course = dive.courseUuid.asyncMap { try? await client.course($0) }
    async let contact = dive.contactUuid.asyncMap { try? await client.contact($0) }
    async let neighbors = try? await client.neighbors(ofDive: uuid)
    let related = await (trip, course, contact, neighbors)
    guard generation == self.generation else { return }
    (self.trip, self.course, self.contact) = (related.0 ?? nil, related.1 ?? nil, related.2 ?? nil)
    self.neighbors = related.3
  }
}

extension Optional where Wrapped: Sendable {
  fileprivate func asyncMap<T: Sendable>(_ transform: (Wrapped) async -> T) async -> T? {
    guard let self else { return nil }
    return await transform(self)
  }
}
