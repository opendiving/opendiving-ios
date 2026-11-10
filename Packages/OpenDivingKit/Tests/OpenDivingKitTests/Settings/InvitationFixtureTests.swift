import Foundation
import OpenDivingKit
import Testing

/// The invitations' and the invite link's reads round-trip their fixtures, a row reads as the
/// web's card reads it, and the send's body encodes to its fixture exactly.
struct InvitationFixtureTests {
  private let utc = TimeZone(identifier: "UTC")!

  @Test func invitations() throws {
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<InvitationRead>.self, "invitations-page")
    let rows = page.data
    #expect(
      rows.map(InvitationsModel.title) == [
        "sam@example.com", "Robin Diver joined through your link", "alex@example.com",
        "kim@example.com", "Someone joined through your link",
      ])
    #expect(
      rows.map { InvitationsModel.badge($0, in: utc) } == [
        "Pending", nil, "Accepted Oct 21, 2026", "Revoked", nil,
      ])
    #expect(
      rows.map { InvitationsModel.details($0, in: utc) } == [
        "Invited Nov 8, 2026", "Nov 2, 2026", "Invited Oct 20, 2026", "Invited Oct 1, 2026",
        "Sep 12, 2026",
      ])
    #expect(rows.map(InvitationsModel.canRevoke) == [true, false, false, false, false])
  }

  @Test func inviteLink() throws {
    let link = try KitFixture.roundTrip(InviteLinkRead.self, "invite-link")
    #expect(link.token == "q7Zr2LmWexampleInviteTokenNotReal0123456")
  }

  @Test func theLinksAddressIsJoinOnTheServersOrigin() throws {
    let token = "q7Zr2LmW-example_Token"
    #expect(
      InvitationsModel.address(token: token, on: ServerOrigin("https://opendiving.app")!)
        .absoluteString == "https://opendiving.app/join?via=q7Zr2LmW-example_Token")
    #expect(
      InvitationsModel.address(token: token, on: ServerOrigin("http://192.168.1.20:3000/dives")!)
        .absoluteString == "http://192.168.1.20:3000/join?via=q7Zr2LmW-example_Token")
  }

  @Test func theShareTitleIsTheInvitationEmailsSubject() {
    #expect(
      InvitationsModel.shareTitle(name: "Test Diver") == "Test Diver invited you to OpenDiving")
    #expect(InvitationsModel.shareTitle(name: nil) == "A diver invited you to OpenDiving")
  }

  @Test func invitationCreate() throws {
    let fixture = try KitFixture.data("request-invitation-create")
    let body = try APICoding.decoder().decode(InvitationCreate.self, from: fixture)
    #expect(body.email == "buddy@example.com")
    let sent = try JSONValue.parse(APICoding.requestEncoder().encode(body))
    #expect(sent == (try JSONValue.parse(fixture)))
  }
}
