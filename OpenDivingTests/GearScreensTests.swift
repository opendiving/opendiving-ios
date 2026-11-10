import OpenDivingKit
import Testing

@testable import OpenDiving

/// More's *Gear* and a gear item's page say what the web says, and offline, with nothing kept,
/// that they show once the server can be reached.
@MainActor
struct GearScreensTests {
  private let server = APIError.http(status: 500, message: "Internal Server Error")

  @Test func aListOrPageNeverShownSaysItShowsOnceTheServerCanBeReached() {
    #expect(GearListView.gearFailure(.noRoute) == OfflineText.gearNotShown)
    #expect(GearListView.setsFailure(.noRoute) == OfflineText.gearSetsNotShown)
    #expect(GearItemDetailView.failure(.noRoute) == OfflineText.gearItemNotShown)
  }

  @Test func aFailureOnlineSaysTheWebsSentence() {
    #expect(GearListView.gearFailure(server) == "Failed to load gear. Please try again.")
    #expect(GearListView.setsFailure(server) == "Failed to load gear sets. Please try again.")
    #expect(GearItemDetailView.failure(server) == server.message)
  }

  @Test func theEmptyStatesAreTheWebs() {
    #expect(GearListView.gearEmptyTitle == "No gear yet")
    #expect(
      GearListView.gearEmptyMessage
        == "Add your first piece of kit to start tracking what you dive with!")
    #expect(GearListView.gearEmptyAction == "Add your first gear")
    #expect(GearListView.setsEmptyTitle == "No gear sets yet")
    #expect(
      GearListView.setsEmptyMessage
        == "Group the kit you use together — sidemount, tech, warm water — and load it into a dive in one click."
    )
    #expect(GearListView.setsEmptyAction == "Add your first set")
    #expect(GearItemDetailView.notFound == "Gear not found.")
  }
}
