import Foundation
import Observation

/// A species' page: the species and the diver's history with it, its photo, and the dives it
/// was seen on, a page at a time. Each shows at once from the account's copy where the phone has
/// shown it, and with no route nothing is asked for until one appears.
@MainActor
@Observable
public final class SpeciesDetailModel {
  public let page: RecordPage<SpeciesPage>
  public let dives: PagedList<DiveListItem>
  /// The photo's bytes, once read; nil with no photo and while it is neither kept nor reachable.
  public private(set) var photo: Data?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var photoVersion: String?
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
  }

  /// The species, then its dives; on a return, whatever shows only the phone's copy, again.
  public func load() async {
    appearancesAtLoad = session.connectivity.routeAppearances
    await page.load()
    guard page.phase.isLoaded else { return }
    await dives.rereadIfStale()
  }

  /// Pull-to-refresh. A species already on screen stays there when the refresh fails.
  public func refresh() async {
    await page.refresh()
    guard page.phase.isLoaded else { return }
    await dives.refresh()
  }

  /// Reads again what a route can mend, each time one appears, until the calling task is
  /// cancelled.
  public func followRoute() async {
    if session.connectivity.routeAppearances != appearancesAtLoad { await reread() }
    await session.connectivity.eachRouteAppearance { await reread() }
  }

  private func reread() async {
    await page.reread()
    guard page.phase.isLoaded else { return }
    await dives.rereadIfStale()
  }

  /// The photo of the species shown, kept bytes first; nothing when it is already drawn.
  public func loadPhoto() async {
    guard case .loaded(let shown) = page.phase else { return }
    guard let version = shown.species.photoSha256 else {
      photo = nil
      photoVersion = nil
      return
    }
    guard version != photoVersion || photo == nil else { return }
    // Another photo's bytes would sit above this one's credit.
    if version != photoVersion { photo = nil }
    let bytes = await SpeciesPhotos.photo(shown.species.uuid, version: version, session: session)
    guard let bytes else { return }
    photo = bytes
    photoVersion = version
  }
}
