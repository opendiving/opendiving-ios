import Foundation
import OpenDivingKit
import Testing

/// *Your connect link*: read as the pane opens on every instance, made, reset and removed once
/// confirmed, kept for the next visit with its token as a secret alone, and what a build before
/// it kept of the invite link gone.
@MainActor
struct ConnectLinkModelTests {
  private func model(_ harness: ConnectLinkHarness) async -> ConnectLinkModel {
    let model = ConnectLinkModel(session: harness.session)
    await model.load()
    return model
  }

  @Test func theLinkRoundTripsItsFixture() throws {
    let link = try KitFixture.roundTrip(ConnectLinkRead.self, "connect-link")
    #expect(link.token == "9f86d081884c7d659a2feaa0c55ad015")
  }

  @Test func theAddressIsConnectOnTheServersOrigin() throws {
    let token = "9f86d081884c7d659a2feaa0c55ad015"
    #expect(
      ConnectLinkModel.address(token: token, on: ServerOrigin("https://opendiving.app")!)
        .absoluteString == "https://opendiving.app/connect/9f86d081884c7d659a2feaa0c55ad015")
    #expect(
      ConnectLinkModel.address(token: token, on: ServerOrigin("http://192.168.1.20:3000/dives")!)
        .absoluteString == "http://192.168.1.20:3000/connect/9f86d081884c7d659a2feaa0c55ad015")
  }

  @Test func theShareTitleIsTheSentenceTheLinksPageGreetsANewcomerWith() {
    #expect(
      ConnectLinkModel.shareTitle(name: "Test Diver")
        == "Test Diver invited you to connect on OpenDiving")
    #expect(
      ConnectLinkModel.shareTitle(name: nil) == "A diver invited you to connect on OpenDiving")
  }

  @Test func onlyAnInviteOnlyInstanceSaysANewcomerDrawsOnTheAllowance() throws {
    let invite = try KitFixture.decode(InstanceConfigRead.self, "config")
    #expect(invite.registrationMode == "invite")
    #expect(ConnectLinkModel.instanceNote(invite) == ConnectLinkModel.newcomers)
    let open = try KitFixture.decode(InstanceConfigRead.self, "config-experimental-features-all")
    #expect(open.registrationMode == "open")
    #expect(ConnectLinkModel.instanceNote(open) == nil)
    #expect(ConnectLinkModel.instanceNote(nil) == nil)
  }

  @Test func noLinkYetOffersOneAndTheAddressIsConnectOnTheServer() async throws {
    let harness = try await ConnectLinkHarness()
    let model = await model(harness)
    #expect(harness.server.linkRoutes == ["GET user/connect-link"])
    #expect(model.isLinkRead)
    #expect(model.link == nil)
    #expect(model.linkAddress == nil)

    await model.createLink()
    #expect(model.link?.token == ConnectLinkServer.token(1))
    #expect(
      model.linkAddress?.absoluteString
        == "https://dive.example.org/connect/\(ConnectLinkServer.token(1))")
    #expect(model.shareTitle == "Test Diver invited you to connect on OpenDiving")
  }

  @Test func aResetAndARemovalEachWaitForTheirConfirmation() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    let model = await model(harness)
    #expect(model.link?.token == ConnectLinkServer.token(0))

    // Dismissed without confirming.
    model.confirmingLink = .reset
    model.confirmingLink = nil
    #expect(!harness.server.linkRoutes.contains { !$0.hasPrefix("GET") })

    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingLink = .reset
    model.confirmingLink = nil
    await model.confirmLinkChange(.reset)
    #expect(model.link?.token == ConnectLinkServer.token(1))
    #expect(harness.server.token == ConnectLinkServer.token(1))

    model.confirmingLink = .remove
    model.confirmingLink = nil
    await model.confirmLinkChange(.remove)
    #expect(model.link == nil)
    #expect(model.isLinkRead)
    #expect(harness.server.token == nil)
  }

  @Test func aTapWhileAChangeWaitsClearsItAndTheNextAsks() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    let model = await model(harness)
    model.askToConfirm(.reset)
    #expect(model.confirmingLink == .reset)
    // Its dialog is up, or was asked for and never shown: the other button's tap clears it.
    model.askToConfirm(.remove)
    #expect(model.confirmingLink == nil)
    model.askToConfirm(.remove)
    #expect(model.confirmingLink == .remove)
    model.askToConfirm(.remove)
    #expect(model.confirmingLink == nil)
  }

  @Test func aRefusedLinkChangeKeepsTheLinkAndSaysWhy() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    let model = await model(harness)
    harness.connectivity.isRouteAvailable = false
    await model.confirmLinkChange(.remove)
    #expect(model.linkFailure == APIError.noRoute.message)
    #expect(model.link?.token == ConnectLinkServer.token(0))
    #expect(!harness.server.linkRoutes.contains("DELETE user/connect-link"))
  }

  @Test func aFailedReadSaysWhyAndTheNextOneShowsTheLink() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    harness.server.fail("GET user/connect-link", with: .json(#"{"detail":"Boom"}"#, status: 500))
    let model = await model(harness)
    #expect(model.linkLoadFailure == "Boom")
    #expect(!model.isLinkRead)

    harness.server.succeed("GET user/connect-link")
    await model.load()
    #expect(model.linkLoadFailure == nil)
    #expect(model.link?.token == ConnectLinkServer.token(0))
  }

  @Test func theLinkIsShownOfflineAtTheNextVisitUnderWhenItWasRead() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    let first = await model(harness)
    #expect(first.lastUpdated == nil)

    harness.connectivity.isRouteAvailable = false
    let model = ConnectLinkModel(session: harness.session)
    #expect(model.link?.token == ConnectLinkServer.token(0))
    #expect(model.isLinkRead)
    #expect(model.lastUpdated != nil)
    await model.load()
    #expect(model.link?.token == ConnectLinkServer.token(0))
    #expect(model.lastUpdated != nil)

    harness.connectivity.isRouteAvailable = true
    await model.load()
    #expect(model.lastUpdated == nil)
  }

  @Test func theTokenReachesNoFileOnlyTheKeychain() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
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
    #expect(harness.keychain.all.contains("write \(token)"))
  }

  @Test func aSignOutTakesTheTokenAndTheNextVisitKeepsNoLink() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    _ = await model(harness)
    try await harness.session.signOut()

    // The cache still names the link; only its token, gone, could show it.
    let model = ConnectLinkModel(session: harness.session)
    #expect(!model.isLinkRead)
    #expect(model.link == nil)
  }

  @Test func aRemovedLinkIsKeptAsNone() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    let first = await model(harness)
    await first.confirmLinkChange(.remove)

    harness.connectivity.isRouteAvailable = false
    let model = ConnectLinkModel(session: harness.session)
    #expect(model.isLinkRead)
    #expect(model.link == nil)
  }

  @Test func offlineTheLinkIsReadWhenARouteAppears() async throws {
    let harness = try await ConnectLinkHarness(linked: true)
    harness.connectivity.isRouteAvailable = false
    let model = await model(harness)
    #expect(model.linkLoadFailure == APIError.noRoute.message)
    #expect(!model.isLinkRead)

    let following = Task { await model.followRoute() }
    defer { following.cancel() }
    while !harness.connectivity.isFollowed { await Task.yield() }
    harness.connectivity.appear()
    for _ in 0..<200 where !model.isLinkRead { try await Task.sleep(for: .milliseconds(5)) }
    #expect(model.link?.token == ConnectLinkServer.token(0))
  }

  @Test func theInviteLinksTokenAndFilesAreGoneOnceTheAccountLoads() async throws {
    let account = try KitFixture.decode(UserRead.self, "user").uuid
    let retired =
      "\(ClientHarness.origin.description) invite-link \(account.uuidString.lowercased())"
    let harness = try await ConnectLinkHarness(secrets: [retired: "old-token"])
    #expect(try harness.secrets.secret(for: retired) == nil)

    let folder = harness.session.store.directory(for: ClientHarness.origin, account: account)
      .appendingPathComponent("Cache/settings", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for name in ["invitations.json", "invite-link.json"] {
      try Data("{}".utf8).write(to: folder.appendingPathComponent(name))
    }
    try await harness.session.loadAccount()
    for name in ["invitations.json", "invite-link.json"] {
      #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path))
    }
  }
}
