import Foundation
import OpenDivingKit
import Testing

/// *Invitations*: the list paged by twenty with no invitation twice, sends and revocations, and
/// the invite link read only once the list has answered and kept in no file.
@MainActor
struct InvitationsModelTests {
  private func model(_ harness: InvitationsHarness) async -> InvitationsModel {
    let model = InvitationsModel(session: harness.session)
    await model.load()
    return model
  }

  private func emails(_ model: InvitationsModel) -> [String] {
    model.list.value?.invitations.compactMap(\.email) ?? []
  }

  @Test func theListPagesByTwentyAndShowsOlderAfterWhatIsShown() async throws {
    let harness = try await InvitationsHarness(count: 45)
    let model = await model(harness)
    let first = try #require(harness.server.requests.first { $0.route == "GET user/invitations" })
    #expect(first.url?.query?.contains("items_per_page=20") == true)
    #expect(model.list.value?.invitations.count == 20)
    #expect(model.canLoadMore)

    await model.loadMore()
    await model.loadMore()
    #expect(emails(model) == (0..<45).map { "invite-\($0)@example.com" })
    #expect(!model.canLoadMore)
    await model.loadMore()
    #expect(harness.server.invitationRoutes.filter { $0 == "GET user/invitations" }.count == 3)
  }

  @Test func noInvitationAppearsTwiceAfterASendOrOneMadeElsewhere() async throws {
    let harness = try await InvitationsHarness(count: 30)
    let model = await model(harness)
    model.email = " Buddy@Example.com "
    await model.send()
    #expect(emails(model).first == "buddy@example.com")
    #expect(model.email.isEmpty)
    #expect(model.sentNote == "buddy@example.com can now create an account here.")
    // Added from the answer: the list is not read again.
    #expect(harness.server.invitationRoutes.filter { $0 == "GET user/invitations" }.count == 1)
    harness.server.invite("web@example.com")

    // Two rows have arrived above page one since it was read, so page two starts on two rows
    // already shown.
    await model.loadMore()
    let shown = emails(model)
    #expect(Set(shown).count == shown.count)
    #expect(shown.count == 31)
    #expect(shown.last == "invite-29@example.com")
    #expect(!shown.contains("web@example.com"))
  }

  @Test func aSendIsCheckedAndARefusalIsTheAPIsSentence() async throws {
    let harness = try await InvitationsHarness()
    let model = await model(harness)
    model.email = "not an address"
    await model.send()
    #expect(model.emailError == "Please enter a valid email address")
    #expect(!harness.server.invitationRoutes.contains("POST user/invitations"))

    model.email = "invite-1@example.com"
    await model.send()
    #expect(model.emailError == nil)
    #expect(model.sendFailure == "You have already invited that address.")
    #expect(model.email == "invite-1@example.com")
    #expect(model.list.value?.invitations.count == 3)
  }

  @Test func offlineASendSaysThereIsNoConnectionAndSendsNothing() async throws {
    let harness = try await InvitationsHarness()
    let model = await model(harness)
    harness.connectivity.isRouteAvailable = false
    model.email = "buddy@example.com"
    await model.send()
    #expect(model.sendFailure == APIError.noRoute.message)
    #expect(model.email == "buddy@example.com")
    #expect(!harness.server.invitationRoutes.contains("POST user/invitations"))
  }

  @Test func aRevocationWaitsForItsConfirmationAndReadsTheStamp() async throws {
    let harness = try await InvitationsHarness()
    let model = await model(harness)
    let row = try #require(model.list.value?.invitations.first)

    // Dismissed without confirming.
    model.confirmingRevoke = row
    model.confirmingRevoke = nil
    #expect(!harness.server.invitationRoutes.contains { $0.hasPrefix("DELETE") })

    #expect(
      InvitationsModel.revokeMessage(row)
        == "invite-0@example.com will no longer be able to create an account here. The row stays"
        + " in this list as revoked, and you can invite the address again later.")
    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingRevoke = row
    model.confirmingRevoke = nil
    await model.confirmRevoke(row)
    #expect(
      harness.server.invitationRoutes.suffix(2) == [
        "DELETE user/invitation/\(row.uuid.uuidString.lowercased())", "GET user/invitations",
      ])
    let after = try #require(model.list.value?.invitations.first)
    #expect(InvitationsModel.badge(after) == "Revoked")
    #expect(!InvitationsModel.canRevoke(after))
  }

  @Test func theSentNoteGoesWithTheNextChangeOnTheScreen() async throws {
    let harness = try await InvitationsHarness(linked: true)
    let model = await model(harness)
    func sent(_ address: String) async throws -> InvitationRead {
      model.email = address
      await model.send()
      #expect(model.sentNote == "\(address) can now create an account here.")
      return try #require(model.list.value?.invitations.first)
    }

    await model.confirmRevoke(try await sent("one@example.com"))
    #expect(model.sentNote == nil)

    _ = try await sent("two@example.com")
    await model.confirmLinkChange(.reset)
    #expect(model.sentNote == nil)

    _ = try await sent("three@example.com")
    await model.confirmLinkChange(.remove)
    #expect(model.sentNote == nil)

    _ = try await sent("four@example.com")
    await model.createLink()
    #expect(model.sentNote == nil)
  }

  @Test func anInstanceAnyoneMayJoinLeavesTheSectionOutAndNeverAsksForTheLink() async throws {
    let harness = try await InvitationsHarness()
    harness.server.fail(
      "GET user/invitations", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    let model = await model(harness)
    #expect(model.list.isAbsent)
    #expect(!model.isLinkRead)
    #expect(!harness.server.invitationRoutes.contains("GET user/invite-link"))
  }

  @Test func aListThatFailedLeavesTheLinkUnread() async throws {
    let harness = try await InvitationsHarness()
    harness.server.fail(
      "GET user/invitations", with: .json(#"{"detail":"Boom"}"#, status: 500))
    let model = await model(harness)
    #expect(model.list.failure == "Boom")
    #expect(!harness.server.invitationRoutes.contains("GET user/invite-link"))

    harness.server.succeed("GET user/invitations")
    await model.load()
    #expect(model.isLinkRead)
    #expect(model.link == nil)
  }

  @Test func noLinkYetOffersOneAndTheAddressIsJoinOnTheServer() async throws {
    let harness = try await InvitationsHarness()
    let model = await model(harness)
    #expect(model.isLinkRead)
    #expect(model.link == nil)
    #expect(model.linkAddress == nil)

    await model.createLink()
    #expect(model.link?.token == InvitationsServer.token(1))
    #expect(
      model.linkAddress?.absoluteString
        == "https://dive.example.org/join?via=\(InvitationsServer.token(1))")
    #expect(model.shareTitle == "Test Diver invited you to OpenDiving")
  }

  @Test func aResetAndARemovalEachWaitForTheirConfirmation() async throws {
    let harness = try await InvitationsHarness(linked: true)
    let model = await model(harness)
    #expect(model.link?.token == InvitationsServer.token(0))

    // Dismissed without confirming.
    model.confirmingLink = .reset
    model.confirmingLink = nil
    #expect(
      !harness.server.invitationRoutes.contains {
        $0.hasSuffix(" user/invite-link") && !$0.hasPrefix("GET")
      })

    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingLink = .reset
    model.confirmingLink = nil
    await model.confirmLinkChange(.reset)
    #expect(model.link?.token == InvitationsServer.token(1))
    #expect(harness.server.token == InvitationsServer.token(1))

    model.confirmingLink = .remove
    model.confirmingLink = nil
    await model.confirmLinkChange(.remove)
    #expect(model.link == nil)
    #expect(model.isLinkRead)
    #expect(harness.server.token == nil)
  }

  @Test func aRefusedLinkChangeKeepsTheLinkAndSaysWhy() async throws {
    let harness = try await InvitationsHarness(linked: true)
    let model = await model(harness)
    harness.connectivity.isRouteAvailable = false
    await model.confirmLinkChange(.remove)
    #expect(model.linkFailure == APIError.noRoute.message)
    #expect(model.link?.token == InvitationsServer.token(0))
    #expect(!harness.server.invitationRoutes.contains("DELETE user/invite-link"))
  }

  @Test func theTokenReachesNoFileAndNoKeychainItem() async throws {
    let harness = try await InvitationsHarness(linked: true)
    let model = await model(harness)
    await model.createLink()
    let token = try #require(model.link?.token)
    // Whatever the session keeps for offline, after another read of the account.
    try await harness.session.loadAccount()

    let secret = Data(token.utf8)
    let files = FileManager.default.enumerator(
      at: harness.directory, includingPropertiesForKeys: nil)
    var read = 0
    while let file = files?.nextObject() as? URL {
      guard let contents = try? Data(contentsOf: file) else { continue }
      read += 1
      #expect(contents.range(of: secret) == nil, "\(file.lastPathComponent) holds the token")
    }
    #expect(read > 0)
    #expect(!harness.keychain.all.contains { $0.contains(token) })
  }

  @Test func offlineTheListAndTheLinkAreReadWhenARouteAppears() async throws {
    let harness = try await InvitationsHarness(linked: true)
    harness.connectivity.isRouteAvailable = false
    let model = await model(harness)
    #expect(model.list.failure == APIError.noRoute.message)
    #expect(!model.isLinkRead)

    let following = Task { await model.followRoute() }
    defer { following.cancel() }
    while !harness.connectivity.isFollowed { await Task.yield() }
    harness.connectivity.appear()
    for _ in 0..<200 where !model.isLinkRead { try await Task.sleep(for: .milliseconds(5)) }
    #expect(model.list.value?.invitations.count == 3)
    #expect(model.link?.token == InvitationsServer.token(0))
  }
}
