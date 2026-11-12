import Foundation
import Observation

/// A species' page: the species and the diver's history with it, its photo, and the dives it
/// was seen on and their sites, each a page at a time. Each shows at once from the account's copy
/// where the phone has shown it, and with no route nothing is asked for until one appears.
@MainActor
@Observable
public final class SpeciesDetailModel {
  public let page: RecordPage<SpeciesPage>
  public let dives: PagedList<DiveListItem>
  /// The diver's sites a dive of theirs saw the species at, most recently dived first.
  public let sites: PagedList<DiveSiteSearchRow>
  /// The photo's bytes, once read; nil with no photo and while it is neither kept nor reachable.
  public private(set) var photo: Data?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var photoVersion: String?
  /// The version on its way, which a second ask leaves to the first.
  @ObservationIgnored private var fetchingVersion: String?
  @ObservationIgnored private var appearancesAtLoad = 0

  public init(session: Session, speciesUUID: UUID) {
    self.session = session
    page = RecordPage(session: session, species: speciesUUID)
    dives = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .speciesDives(speciesUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.dives(.species(speciesUUID), page: page, itemsPerPage: itemsPerPage)
    }
    sites = PagedList(
      session: session, itemsPerPage: APIClient.nestedListPageSize,
      cache: .speciesDiveSites(speciesUUID), routed: true
    ) { client, page, itemsPerPage in
      try await client.searchDiveSites(
        DiveSiteSearchQuery(yours: true, species: speciesUUID), page: page,
        itemsPerPage: itemsPerPage
      ).listPage
    }
  }

  /// The species, then its dives, their sites and its photo; on a return, whatever shows only
  /// the phone's copy, again.
  public func load() async {
    appearancesAtLoad = session.connectivity.routeAppearances
    await page.load()
    await readBeside { await rereadListsIfStale() }
  }

  /// Pull-to-refresh. A species already on screen stays there when the refresh fails.
  public func refresh() async {
    await page.refresh()
    await readBeside {
      async let dives: Void = dives.refresh()
      async let sites: Void = sites.refresh()
      _ = await (dives, sites)
    }
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    if session.connectivity.routeAppearances != appearancesAtLoad { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  private func reread() async {
    await page.reread()
    await readBeside { await rereadListsIfStale() }
  }

  private func rereadListsIfStale() async {
    async let dives: Void = dives.rereadIfStale()
    async let sites: Void = sites.rereadIfStale()
    _ = await (dives, sites)
  }

  /// The lists, by `list`, and the photo, which a read that could not have it is the only
  /// chance to ask for again: its version has not changed.
  private func readBeside(_ list: () async -> Void) async {
    guard page.phase.isLoaded else { return }
    await list()
    await loadPhoto()
  }

  /// The photo of the species shown, kept bytes first; nothing when it is already drawn or on
  /// its way.
  public func loadPhoto() async {
    guard case .loaded(let shown) = page.phase else { return }
    guard let version = shown.species.photoSha256 else {
      photo = nil
      photoVersion = nil
      fetchingVersion = nil
      return
    }
    guard version != photoVersion || photo == nil, version != fetchingVersion else { return }
    // Another photo's bytes would sit above this one's credit.
    if version != photoVersion { photo = nil }
    fetchingVersion = version
    let bytes = await SpeciesPhotos.photo(shown.species.uuid, version: version, session: session)
    if fetchingVersion == version { fetchingVersion = nil }
    guard let bytes else { return }
    photo = bytes
    photoVersion = version
  }
}
