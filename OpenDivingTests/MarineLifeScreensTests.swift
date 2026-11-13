import OpenDivingKit
import Testing

@testable import OpenDiving

/// More's *Marine Life* and a species' page say what the web says, and offline,
/// with nothing kept, that they show once the server can be reached.
@MainActor
struct MarineLifeScreensTests {
  private let server = APIError.http(status: 500, message: "Internal Server Error")

  @Test func aListNeverShownSaysItShowsOnceTheServerCanBeReached() {
    #expect(MarineLifeListView.failure(.noRoute) == OfflineText.lifeListNotShown)
    #expect(SpeciesDetailView.failure(.noRoute) == OfflineText.speciesNotShown)
  }

  @Test func aFailureOnlineSaysTheWebsSentence() {
    #expect(MarineLifeListView.failure(server) == "Failed to load your species. Please try again.")
  }

  @Test func theEmptyStatesAreTheWebs() {
    #expect(MarineLifeListView.emptyTitle == "No species yet")
    #expect(
      MarineLifeListView.emptyMessage == "Record what you saw on a dive and it will appear here.")
    #expect(SpeciesDetailView.notFound == "Species not found.")
  }
}
