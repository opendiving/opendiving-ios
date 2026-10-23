import Foundation
import Observation

/// One trip's page: the trip, its own dives a page at a time, and the contacts its
/// information card names — each part's accommodation and the trip's dive centres.
@MainActor
@Observable
public final class TripDetailModel {
  public let tripUUID: UUID
  public private(set) var phase: DetailPhase<TripRead> = .loading
  /// The contacts read so far, by uuid. One that failed to read is left out, and the card
  /// draws the part or the line without it.
  public private(set) var contacts: [UUID: ContactRead] = [:]
  /// The trip's own dives, newest first. Candidates — dives on no trip whose day a part
  /// covers — are not among them.
  public let dives: PagedList<DiveListItem>

  @ObservationIgnored private let session: Session

  public init(session: Session, tripUUID: UUID) {
    self.session = session
    self.tripUUID = tripUUID
    dives = PagedList(session: session, itemsPerPage: APIClient.nestedListPageSize) {
      client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage, tripUUID: tripUUID)
    }
  }

  /// The trip, then its dives and its contacts; nothing once the trip is on screen.
  public func load() async {
    if case .loaded = phase { return }
    await readTrip()
    guard case .loaded(let trip) = phase else { return }
    async let list: Void = dives.load()
    async let names: Void = readContacts(trip)
    _ = await (list, names)
  }

  /// Pull-to-refresh: the trip, its dives from the first page, and its contacts again. A
  /// trip already on screen stays there when the refresh fails.
  public func refresh() async {
    await readTrip()
    guard case .loaded(let trip) = phase else { return }
    async let list: Void = dives.refresh()
    async let names: Void = readContacts(trip)
    _ = await (list, names)
  }

  private func readTrip() async {
    let wasLoaded = phase.isLoaded
    if !wasLoaded { phase = .loading }
    do {
      let trip = try await session.requireClient().trip(tripUUID)
      phase = .loaded(trip)
    } catch {
      let next = DetailPhase<TripRead>.failure(error)
      if !wasLoaded || next == .notFound { phase = next }
    }
  }

  private func readContacts(_ trip: TripRead) async {
    guard let client = session.client else { return }
    let uuids = TripSummary.contactUUIDs(trip)
    let read = await withTaskGroup(of: ContactRead?.self) { group in
      for uuid in uuids {
        group.addTask { try? await client.contact(uuid) }
      }
      var read: [UUID: ContactRead] = [:]
      for await contact in group {
        if let contact { read[contact.uuid] = contact }
      }
      return read
    }
    // Merged, so a refresh that cannot reach one keeps the name already shown.
    contacts.merge(read) { _, new in new }
  }
}
