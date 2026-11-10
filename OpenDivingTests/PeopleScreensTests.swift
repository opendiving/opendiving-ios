import OpenDivingKit
import Testing

@testable import OpenDiving

/// More's *People* and *Contacts* and a person's page say what the web says, and offline, with
/// nothing kept, that they show once the server can be reached.
@MainActor
struct PeopleScreensTests {
  private let server = APIError.http(status: 500, message: "Internal Server Error")

  @Test func aListOrPageNeverShownSaysItShowsOnceTheServerCanBeReached() {
    #expect(PeopleListView.failure(.noRoute) == OfflineText.peopleNotShown)
    #expect(ContactListView.failure(.noRoute) == OfflineText.contactsNotShown)
    #expect(PersonDetailView.failure(.noRoute) == OfflineText.personNotShown)
  }

  @Test func aFailureOnlineSaysTheWebsSentence() {
    #expect(PeopleListView.failure(server) == "Failed to load people. Please try again.")
    #expect(ContactListView.failure(server) == "Failed to load contacts. Please try again.")
    #expect(PersonDetailView.failure(server) == server.message)
  }

  @Test func theHeadsAndEmptyStatesAreTheWebs() {
    #expect(PeopleListView.title == "People")
    #expect(
      PeopleListView.description
        == "Your buddies, guides, instructors and the people who came along, kept once")
    #expect(PeopleListView.listTitle == "People List")
    #expect(PeopleListView.emptyTitle == "No people yet")
    #expect(
      PeopleListView.emptyMessage
        == "Add the people you dive with once, and pick them from your dives, trips and courses.")
    #expect(PeopleListView.emptyAction == "Add your first person")
    #expect(ContactListView.title == "Contacts")
    #expect(
      ContactListView.description
        == "The dive centers, schools, shops and places you stayed, kept once")
    #expect(ContactListView.listTitle == "Contact List")
    #expect(ContactListView.emptyTitle == "No contacts yet")
    #expect(
      ContactListView.emptyMessage
        == "Add the dive centers, shops and places you stay at once, and pick them from your dives, courses and trips."
    )
    #expect(ContactListView.emptyAction == "Add your first contact")
    #expect(PersonDetailView.notFound == "Person not found.")
  }
}
