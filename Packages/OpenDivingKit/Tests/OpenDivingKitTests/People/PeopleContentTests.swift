import Foundation
import Testing

@testable import OpenDivingKit

/// More's *People* and *Contacts* cards and a person's page say what the web's
/// `people-page-content.tsx`, `contacts-page-content.tsx` and `person-detail-page-content.tsx`
/// draw at its pin.
struct PeopleContentTests {
  private func people() throws -> [PersonRead] {
    try APICoding.decoder().decode(
      PaginatedListResponse<PersonRead>.self, from: KitFixture.data("people-page")
    ).data
  }

  private func contacts() throws -> [ContactRead] {
    try APICoding.decoder().decode(
      PaginatedListResponse<ContactRead>.self, from: KitFixture.data("contacts-page")
    ).data
  }

  @Test func aPersonsCardIsTheirNameUsernameAndDives() throws {
    let ana = try people()[0]
    #expect(
      PlainCardContent.person(ana)
        == PlainCardContent(
          title: "Ana Diaz", facts: [Fact(text: "@ana"), Fact(text: "12 dives")]))
  }

  @Test func aPersonWithNoAccountHasOnlyTheirDives() throws {
    let ben = try people()[1]
    #expect(
      PlainCardContent.person(ben)
        == PlainCardContent(title: ben.name, facts: [Fact(text: "0 dives")]))
  }

  @Test func aContactsCardIsItsRolesAndCity() throws {
    let contacts = try contacts()
    #expect(
      PlainCardContent.contact(contacts[0])
        == PlainCardContent(
          title: "Big Blue Tech",
          badges: [Badge("Dive center"), Badge("School"), Badge("Shop")],
          facts: [Fact(text: "Koh Tao")]))
    // An unknown role shows as the web falls back to it; no address, no city.
    #expect(
      PlainCardContent.contact(contacts[1])
        == PlainCardContent(
          title: "Example Liveaboards", badges: [Badge("Liveaboard operator")]))
  }

  @Test func aPersonsHeadIsTheirNameAndUsername() throws {
    let ana = try people()[0]
    #expect(
      PersonPageContent.hero(ana) == HeroContent(title: "Ana Diaz", facts: [Fact(text: "@ana")]))
    #expect(PersonPageContent.hero(try people()[1]).facts.isEmpty)
  }

  @Test func theEmailOpensMailAndThePhoneTheDialler() throws {
    let ana = try people()[0]
    #expect(PersonPageContent.email(ana)?.text == "ana@example.com")
    #expect(PersonPageContent.email(ana)?.url == URL(string: "mailto:ana@example.com"))
    #expect(PersonPageContent.phone(ana)?.text == "+1 555 0100")
    #expect(PersonPageContent.phone(ana)?.url == URL(string: "tel:+15550100"))
    let ben = try people()[1]
    #expect(PersonPageContent.email(ben) == nil)
    #expect(PersonPageContent.phone(ben) == nil)
  }

  @Test func theNotesShowWhereThereAreAny() throws {
    let dana = try APICoding.decoder().decode(PersonRead.self, from: KitFixture.data("person"))
    #expect(PersonPageContent.notes(dana) == "Teaches the cave courses.")
    #expect(PersonPageContent.notes(try people()[0]) == nil)
  }
}
