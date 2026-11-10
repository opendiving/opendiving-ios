import Foundation

/// What a species' page shows: the catalog's record and the diver's history with it.
public struct SpeciesPage: Codable, Hashable, Sendable {
  /// The diver's dives with the species, as `GET /user/species/{uuid}` answered.
  public enum History: Codable, Hashable, Sendable {
    case seen(SpeciesLifeListEntry)
    /// A 404: no live dive of the diver's records it, so its figures are zeroes.
    case never
    /// The read failed, so the page vouches for no figure.
    case unknown
  }

  public var species: SpeciesRead
  public var history: History

  public init(species: SpeciesRead, history: History) {
    self.species = species
    self.history = history
  }

  /// Both reads at once. The page is the species', so only its read failing fails it.
  static func read(_ uuid: UUID, client: APIClient) async throws -> SpeciesPage {
    async let species = client.species(uuid)
    async let history = Self.history(uuid, client: client)
    return SpeciesPage(species: try await species, history: await history)
  }

  private static func history(_ uuid: UUID, client: APIClient) async -> History {
    do {
      return .seen(try await client.lifeListEntry(uuid))
    } catch {
      if case .http(status: 404, _) = APIError(error) { return .never }
      return .unknown
    }
  }
}
