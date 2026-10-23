import Foundation
import Observation

/// One dive site's page: the site, every dive there a page at a time, and the species seen
/// on them with their photos.
@MainActor
@Observable
public final class DiveSiteDetailModel {
  /// The *Species Seen Here* card's state.
  public enum Species: Hashable, Sendable {
    /// The site counts no species, so nothing is asked for and no card is drawn.
    case none
    case loading
    case loaded([SpeciesLifeListEntry])
    case failed
  }

  public let siteUUID: UUID
  public private(set) var phase: DetailPhase<DiveSiteRead> = .loading
  public let dives: PagedList<DiveListItem>
  public private(set) var species: Species = .none
  /// Photo bytes by species uuid, as each card asks for its own.
  public private(set) var photos: [UUID: Data] = [:]

  @ObservationIgnored private let session: Session
  /// The photo version last asked for, by species uuid.
  @ObservationIgnored private var photosAsked: [UUID: String] = [:]

  public init(session: Session, siteUUID: UUID) {
    self.session = session
    self.siteUUID = siteUUID
    dives = PagedList(session: session, itemsPerPage: APIClient.nestedListPageSize) {
      client, page, itemsPerPage in
      try await client.dives(page: page, itemsPerPage: itemsPerPage, diveSiteUUID: siteUUID)
    }
  }

  /// The site, then its dives and its species; nothing once the site is on screen.
  public func load() async {
    if phase.isLoaded { return }
    await readSite()
    guard case .loaded(let site) = phase else { return }
    async let list: Void = dives.load()
    async let seen: Void = readSpecies(site)
    _ = await (list, seen)
  }

  /// Pull-to-refresh: the site, its dives from the first page, and its species again. A
  /// site already on screen stays there when the refresh fails.
  public func refresh() async {
    await readSite()
    guard case .loaded(let site) = phase else { return }
    async let list: Void = dives.refresh()
    async let seen: Void = readSpecies(site)
    _ = await (list, seen)
  }

  /// The species' photo, once per version, when it has one. A photo that fails to arrive
  /// leaves the card's no-photo backdrop.
  public func loadPhoto(_ entry: SpeciesLifeListEntry) async {
    guard let version = entry.photoSha256, photosAsked[entry.uuid] != version,
      let client = session.client
    else { return }
    photosAsked[entry.uuid] = version
    if let bytes = try? await client.speciesPhoto(entry.uuid, version: version) {
      photos[entry.uuid] = bytes.data
    }
  }

  private func readSite() async {
    let wasLoaded = phase.isLoaded
    if !wasLoaded { phase = .loading }
    do {
      let site = try await session.requireClient().diveSite(siteUUID)
      phase = .loaded(site)
    } catch {
      let next = DetailPhase<DiveSiteRead>.failure(error)
      if !wasLoaded || next == .notFound { phase = next }
    }
  }

  /// Read whole, as the web reads it: a site's species are a list worth seeing entire.
  private func readSpecies(_ site: DiveSiteRead) async {
    guard site.speciesCount > 0, let client = session.client else {
      species = .none
      return
    }
    if case .loaded = species {} else { species = .loading }
    let siteUUID = siteUUID
    do {
      let entries = try await APIClient.allPages { page, itemsPerPage in
        try await client.speciesLifeList(
          diveSiteUUID: siteUUID, page: page, itemsPerPage: itemsPerPage)
      }
      species = .loaded(entries)
    } catch {
      if case .loaded = species { return }
      species = .failed
    }
  }
}
