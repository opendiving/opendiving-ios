import Foundation
import OpenDivingKit
import Testing

/// *Authentication*'s passkeys: listed, renamed in the row, removed after a confirmation.
@MainActor
struct PasskeysModelTests {
  private let iPhone = UUID(uuidString: "019a1f2e-3c4d-7a5b-8c6d-7e8f9a0b1c2d")!

  @Test func theBlockIsLeftOutWithNoneOrWithoutTheFeature() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    #expect(model.isShown)

    harness.server.fail("GET user/passkeys", with: .json("[]"))
    await model.list.load()
    #expect(!model.isShown)

    harness.server.fail("GET user/passkeys", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    await model.list.load()
    #expect(!model.isShown)
  }

  @Test func aRenameSendsTheTrimmedNameAndPatchesTheRow() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()

    model.rename.begin(iPhone, name: "iPhone")
    model.rename.draft = "  Work phone "
    await model.saveRename()

    #expect(
      harness.server.credentialRoutes == [
        "GET user/passkeys", "PATCH user/passkey/\(iPhone.uuidString.lowercased())",
      ])
    let sent = harness.server.requests.first { $0.route.hasPrefix("PATCH user/passkey/") }
    #expect(sent?.json == (try JSONValue.parse(Data(#"{"name":"Work phone"}"#.utf8))))
    #expect(model.list.value?.first?.name == "Work phone")
    #expect(model.rename.editing == nil)
  }

  @Test func aNameIsNeverEmptyNorLongerThanFifty() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    model.rename.begin(iPhone, name: "iPhone")
    model.rename.draft = "  "
    #expect(!model.rename.canSave)
    model.rename.draft = String(repeating: "é", count: 51)
    #expect(!model.rename.canSave)
    model.rename.draft = String(repeating: "é", count: 50)
    #expect(model.rename.canSave)
  }

  @Test func aRefusedRenameKeepsTheRowOpenWithTheAPIsSentence() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    harness.server.fail(
      "PATCH user/passkey/\(iPhone.uuidString.lowercased())",
      with: .json(#"{"detail":"Passkey not found"}"#, status: 404))
    model.rename.begin(iPhone, name: "iPhone")
    model.rename.draft = "Work phone"
    await model.saveRename()
    #expect(model.rename.failure == "Passkey not found")
    #expect(model.rename.editing == iPhone)
    #expect(model.list.value?.first?.name == "iPhone")
  }

  @Test func aRemovalWaitsForItsConfirmationAndTheListReadsAgain() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    let passkey = try #require(model.list.value?.first)

    // Dismissed without confirming.
    model.confirmingRemove = passkey
    model.confirmingRemove = nil
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("DELETE") })

    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingRemove = passkey
    #expect(PasskeysModel.removeMessage(passkey).hasPrefix("\u{201C}iPhone\u{201D} will stop"))
    model.confirmingRemove = nil
    await model.confirmRemove(passkey)
    #expect(
      harness.server.credentialRoutes.suffix(2) == [
        "DELETE user/passkey/\(iPhone.uuidString.lowercased())", "GET user/passkeys",
      ])
    #expect(model.list.value?.map(\.name) == ["YubiKey"])
    #expect(model.confirmingRemove == nil)
  }

  @Test func offlineARemovalSaysThereIsNoConnectionAndSendsNothing() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    harness.connectivity.isRouteAvailable = false
    await model.confirmRemove(try #require(model.list.value?.first))
    #expect(model.removeFailure == APIError.noRoute.message)
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("DELETE") })
    #expect(model.list.value?.count == 2)
  }

  @Test func theListIsKeptAndShownOfflineAtTheNextVisitUnderWhenItWasRead() async throws {
    let harness = try await CredentialsHarness()
    let first = PasskeysModel(session: harness.session)
    await first.list.load()
    #expect(first.list.lastUpdated == nil)
    first.rename.begin(iPhone, name: "iPhone")
    first.rename.draft = "Work phone"
    await first.saveRename()

    harness.connectivity.isRouteAvailable = false
    let model = PasskeysModel(session: harness.session)
    #expect(model.list.value?.map(\.name) == ["Work phone", "YubiKey"])
    #expect(model.list.lastUpdated == nil)
    await model.list.load()
    #expect(model.list.value?.map(\.name) == ["Work phone", "YubiKey"])
    #expect(model.list.lastUpdated != nil)
    #expect(model.isShown)

    harness.connectivity.isRouteAvailable = true
    harness.server.fail("GET user/passkeys", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    await model.list.load()
    #expect(PasskeysModel(session: harness.session).list.value == nil)
  }

  // MARK: - Adding

  @Test func withoutTheAssociationPasskeysAreAddedOnTheWeb() async throws {
    let harness = try await CredentialsHarness()
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    #expect(!model.canAdd)
    #expect(model.note == PasskeysModel.addedOnTheWeb)
    await model.add()
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("POST") })
  }

  @Test func whereThePhoneCanAddAnAccountWithNoneSeesTheBlock() async throws {
    let ceremony = FakePasskeyCeremony()
    let harness = try await CredentialsHarness(passkeyAssociation: ceremony.association())
    let model = PasskeysModel(session: harness.session)
    harness.server.fail("GET user/passkeys", with: .json("[]"))
    await model.list.load()
    #expect(model.canAdd)
    #expect(model.isShown)
    #expect(model.note == PasskeysModel.noneYet)

    // A server without passkeys still leaves the block out.
    harness.server.fail("GET user/passkeys", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    await model.list.load()
    #expect(!model.isShown)
  }

  @Test func addingNamesThePasskeyForTheDeviceAndListsIt() async throws {
    let ceremony = FakePasskeyCeremony()
    let harness = try await CredentialsHarness(passkeyAssociation: ceremony.association())
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    #expect(model.note == nil)
    await model.add()

    let request = try #require(ceremony.registrations.first)
    #expect(request.relyingParty == "localhost")
    #expect(request.name == "sam@example.com")
    #expect(request.excludedCredentials.count == 1)
    let sent = harness.server.requests.first { $0.route == "POST user/passkey/verify" }
    #expect(sent?.json?["name"] == .string("iPhone"))
    #expect(sent?.json?["credential"]?["type"] == .string("public-key"))
    #expect(model.list.value?.map(\.name) == ["iPhone", "YubiKey", "iPhone"])
    #expect(model.addFailure == nil)
    #expect(!model.isAdding)
  }

  @Test func aPhoneThatAlreadyHoldsOneIsToldSoAndNothingIsAdded() async throws {
    let ceremony = FakePasskeyCeremony()
    ceremony.registerAnswer = .matchedExcludedCredential
    let harness = try await CredentialsHarness(passkeyAssociation: ceremony.association())
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    await model.add()
    #expect(model.addFailure == "This phone already has a passkey for your account.")
    #expect(!harness.server.credentialRoutes.contains("POST user/passkey/verify"))
    #expect(model.list.value?.count == 2)
  }

  @Test func aDismissalSaysNothingAndTheSystemsRefusalTheFallback() async throws {
    let ceremony = FakePasskeyCeremony()
    let harness = try await CredentialsHarness(passkeyAssociation: ceremony.association())
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    ceremony.registerAnswer = .dismissed
    await model.add()
    #expect(model.addFailure == nil)
    ceremony.registerAnswer = .failed
    await model.add()
    #expect(model.addFailure == "Couldn't add that passkey. Please try again.")
    #expect(model.list.value?.count == 2)
  }

  @Test func theAPIsRefusalSaysItsSentence() async throws {
    let ceremony = FakePasskeyCeremony()
    let harness = try await CredentialsHarness(passkeyAssociation: ceremony.association())
    let model = PasskeysModel(session: harness.session)
    await model.list.load()
    harness.server.fail(
      "POST user/passkey/options",
      with: .json(#"{"detail":"You already have the maximum number of passkeys."}"#, status: 409))
    await model.add()
    #expect(model.addFailure == "You already have the maximum number of passkeys.")
    #expect(ceremony.registrations.isEmpty)

    harness.server.succeed("POST user/passkey/options")
    harness.server.fail(
      "POST user/passkey/verify",
      with: .json(#"{"detail":"That passkey registration expired. Try again."}"#, status: 400))
    await model.add()
    #expect(model.addFailure == "That passkey registration expired. Try again.")
  }
}
