import Foundation
import Observation

/// A species photo's credit sheet: the species as the catalog has it now, and the photo that
/// credit belongs to.
@MainActor
@Observable
public final class SpeciesPhotoCreditModel {
  public let speciesUUID: UUID
  public private(set) var phase: DetailPhase<SpeciesRead> = .loading
  /// The card's photo until the species arrives, then the catalog's own where it differs: a
  /// photo re-fetched since the card was drawn would otherwise sit above another's credit.
  public private(set) var photo: Data?

  @ObservationIgnored private let session: Session
  @ObservationIgnored private var photoVersion: String?

  /// `photoVersion` and `photo` are what the card drew.
  public init(session: Session, speciesUUID: UUID, photoVersion: String?, photo: Data?) {
    self.session = session
    self.speciesUUID = speciesUUID
    self.photoVersion = photoVersion
    self.photo = photo
  }

  /// The credit, once the species has arrived; nil while it has none to give.
  public var credit: PhotoCreditContent? {
    guard case .loaded(let species) = phase else { return nil }
    return .species(species)
  }

  /// Reads the species, or retries it; nothing once it is on screen.
  public func load() async {
    if phase.isLoaded { return }
    phase = .loading
    let client: APIClient
    let species: SpeciesRead
    do {
      client = try session.requireClient()
      species = try await client.species(speciesUUID)
    } catch {
      phase = .failure(error)
      return
    }
    let stale = species.photoSha256 != photoVersion
    if stale { photo = nil }
    phase = .loaded(species)
    guard let version = species.photoSha256, stale || photo == nil else { return }
    photoVersion = version
    photo = try? await client.speciesPhoto(speciesUUID, version: version).data
  }
}
