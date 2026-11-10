import Foundation
import OpenDivingKit
import Testing

/// *Authentication*'s API keys: made from the web's form and defaults, the secret shown once and
/// kept nowhere, revoked after a confirmation.
@MainActor
struct APIKeysModelTests {
  private let laptop = UUID(uuidString: "019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a80")!
  private let made = UUID(uuidString: "019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a82")!

  private func model(_ harness: CredentialsHarness) async -> APIKeysModel {
    let model = APIKeysModel(session: harness.session)
    await model.list.load()
    return model
  }

  @Test func theFormOpensOnTheWebsDefaults() async throws {
    let harness = try await CredentialsHarness()
    let model = APIKeysModel(session: harness.session)
    #expect(!model.canCreate)
    await model.list.load()
    model.startCreating()
    #expect(model.isCreating)
    #expect(model.name.isEmpty)
    #expect(model.scope == .read)
    #expect(model.lifetime == .oneYear)
  }

  @Test func aNameIsNeededAndBounded() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.startCreating()
    model.name = "   "
    await model.create()
    #expect(model.nameError == "Give the key a name.")
    model.name = String(repeating: "k", count: 51)
    await model.create()
    #expect(model.nameError == "At most 50 characters.")
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
  }

  @Test func aCreateSendsTheFormAndShowsTheSecretOnceOnItsRow() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.startCreating()
    model.name = " tide sync "
    model.lifetime = .thirtyDays
    await model.create()

    let sent = harness.server.requests.first { $0.route == "POST user/api-keys" }
    #expect(
      sent?.json
        == (try JSONValue.parse(Data(#"{"name":"tide sync","scope":"read","lifetime":"30d"}"#.utf8)))
    )
    #expect(!model.isCreating)
    #expect(model.name.isEmpty && model.lifetime == .oneYear)
    #expect(model.list.value?.map(\.name) == ["laptop", "backup script", "tide sync"])
    let row = try #require(model.list.value?.last)
    #expect(model.secret(for: row) == CredentialsServer.secret)
    #expect(model.list.value?.dropLast().allSatisfy { model.secret(for: $0) == nil } == true)
    // Added from the answer: the list is not read again.
    #expect(harness.server.credentialRoutes.filter { $0 == "GET user/api-keys" }.count == 1)

    model.done()
    #expect(model.secret(for: row) == nil)
    #expect(model.created == nil)
  }

  @Test func theSecretReachesNoFileAndNoKeychainItem() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.startCreating()
    model.name = "tide sync"
    await model.create()
    #expect(model.created?.secret == CredentialsServer.secret)
    // Whatever the session keeps for offline, after another read of the account.
    try await harness.session.loadAccount()

    let secret = Data(CredentialsServer.secret.utf8)
    let files = FileManager.default.enumerator(
      at: harness.directory, includingPropertiesForKeys: nil)
    var read = 0
    while let file = files?.nextObject() as? URL {
      guard let contents = try? Data(contentsOf: file) else { continue }
      read += 1
      #expect(contents.range(of: secret) == nil, "\(file.lastPathComponent) holds the secret")
    }
    #expect(read > 0)
    #expect(!harness.keychain.all.contains { $0.contains(CredentialsServer.secret) })
    #expect(!String(describing: model.created).contains(CredentialsServer.secret))
  }

  @Test func aRefusedCreateKeepsTheFormWithTheAPIsSentence() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    harness.server.fail(
      "POST user/api-keys",
      with: .json(
        #"{"detail":"You already have 10 API keys. Revoke one to create another."}"#, status: 409))
    model.startCreating()
    model.name = "tide sync"
    model.scope = .write
    await model.create()
    #expect(model.createFailure == "You already have 10 API keys. Revoke one to create another.")
    #expect(model.isCreating)
    #expect(model.name == "tide sync" && model.scope == .write)
    #expect(model.created == nil)
  }

  @Test func offlineACreateSaysThereIsNoConnectionAndSendsNothing() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    harness.connectivity.isRouteAvailable = false
    model.startCreating()
    model.name = "tide sync"
    await model.create()
    #expect(model.createFailure == APIError.noRoute.message)
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
  }

  @Test func aRevocationWaitsForItsConfirmationAndTakesTheSecretWithIt() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    await model.confirmRevoke()
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("DELETE") })

    model.startCreating()
    model.name = "tide sync"
    await model.create()
    let row = try #require(model.list.value?.last)
    model.confirmingRevoke = row
    await model.confirmRevoke()
    #expect(
      harness.server.credentialRoutes.suffix(2) == [
        "DELETE user/api-key/\(made.uuidString.lowercased())", "GET user/api-keys",
      ])
    #expect(model.created == nil)
    #expect(model.list.value?.map(\.uuid).contains(made) == false)

    let key = try #require(model.list.value?.first { $0.uuid == laptop })
    #expect(
      APIKeysModel.revokeMessage(key)
        == "\u{201C}laptop\u{201D} stops working on its very next request, and can't be brought"
        + " back - whatever uses it will need a new key.")
  }
}
