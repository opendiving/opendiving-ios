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
}
