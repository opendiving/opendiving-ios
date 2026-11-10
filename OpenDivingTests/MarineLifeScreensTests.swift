import OpenDivingKit
import Testing

@testable import OpenDiving

/// More's *Marine Life*, a species' page and *Dive Sites* say what the web says, and offline,
/// with nothing kept, that they show once the server can be reached.
@MainActor
struct MarineLifeScreensTests {
  private let server = APIError.http(status: 500, message: "Internal Server Error")

  @Test func aListNeverShownSaysItShowsOnceTheServerCanBeReached() {
    #expect(MarineLifeListView.failure(.noRoute) == OfflineText.lifeListNotShown)
    #expect(YourDiveSitesView.failure(.noRoute) == OfflineText.yourDiveSitesNotShown)
    #expect(SpeciesDetailView.failure(.noRoute) == OfflineText.speciesNotShown)
  }

  @Test func aFailureOnlineSaysTheWebsSentence() {
    #expect(MarineLifeListView.failure(server) == "Failed to load your species. Please try again.")
    #expect(YourDiveSitesView.failure(server) == server.message)
  }

  @Test func theEmptyStatesAreTheWebs() {
    #expect(MarineLifeListView.emptyTitle == "No species yet")
    #expect(
      MarineLifeListView.emptyMessage == "Record what you saw on a dive and it will appear here.")
    #expect(YourDiveSitesView.empty == "You have no dive sites yet.")
    #expect(SpeciesDetailView.notFound == "Species not found.")
  }
}
