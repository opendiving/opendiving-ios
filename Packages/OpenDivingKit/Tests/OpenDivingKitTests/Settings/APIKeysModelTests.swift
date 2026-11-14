import Foundation
import OpenDivingKit
import Testing

/// *Authentication*'s API keys: made from the web's form and defaults, the secret shown once and
/// kept nowhere, revoked after a confirmation.
@MainActor
struct APIKeysModelTests {
  private let laptop = UUID(uuidString: "019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a80")!
  private let made = UUID(uuidString: "019a3c4d-5e6f-7081-9a2b-3c4d5e6f7a82")!

  /// The screen's model with its list read and its form open, as the form's own read leaves it.
  private func model(_ harness: CredentialsHarness) async -> APIKeysModel {
    let model = APIKeysModel(session: harness.session)
    await model.list.load()
    model.startCreating()
    await model.permissions.load()
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
    #expect(model.scopes == ["dives:read"])
    #expect(model.lifetime == .oneYear)
    // Nothing is sent before the server has said which permissions it offers.
    #expect(!model.canSubmit)
    model.name = "tide sync"
    await model.create()
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
    await model.permissions.load()
    #expect(model.canSubmit)
    #expect(model.grantedCount == "1 of 45 selected")
  }

  @Test func theListShowsEveryKindOfKey() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    #expect(model.list.value?.map(\.scope) == [.read, .write, .scoped])
    #expect(model.list.failure == nil)
  }

  @Test func thePresetsAndTheTogglesChangeWhatIsGranted() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.grantAll()
    #expect(model.grantedCount == "45 of 45 selected")
    model.grantReadsOnly()
    #expect(model.isGranted("gear:read") && !model.isGranted("gear:write"))
    #expect(!model.isGranted("checkin:read"))
    model.grant("checkin:read", true)
    model.grant("dives:read", false)
    #expect(model.isGranted("checkin:read") && !model.isGranted("dives:read"))
    model.cancelCreating()
    #expect(model.scopes == APIKeysModel.defaultScopes)
  }

  @Test func aKeyNeedsAPermission() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.name = "tide sync"
    model.grant("dives:read", false)
    await model.create()
    #expect(model.scopesError == "Select at least one permission.")
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
    model.grant("sites:read", true)
    #expect(model.scopesError == nil)
  }

  @Test func aServerWithoutPermissionsMakesNoKey() async throws {
    let harness = try await CredentialsHarness()
    harness.server.fail(
      "GET user/api-key-permissions", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    let model = await model(harness)
    #expect(model.permissions.isAbsent)
    #expect(!model.canSubmit)
    model.name = "tide sync"
    await model.create()
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
  }

  @Test func aNameIsNeededAndBounded() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
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
    model.name = " tide sync "
    model.lifetime = .thirtyDays
    model.grant("sites:read", true)
    await model.create()

    // In the server's order, whatever order they were picked in.
    let sent = harness.server.requests.first { $0.route == "POST user/api-keys" }
    #expect(
      sent?.json
        == (try JSONValue.parse(
          Data(
            (#"{"name":"tide sync","scope":"scoped","scopes":["dives:read","sites:read"],"#
              + #""lifetime":"30d"}"#).utf8)))
    )
    #expect(!model.isCreating)
    #expect(model.name.isEmpty && model.lifetime == .oneYear)
    #expect(model.scopes == APIKeysModel.defaultScopes)
    #expect(
      model.list.value?.map(\.name) == [
        "laptop", "backup script", "logbook assistant", "tide sync",
      ])
    #expect(model.list.value?.last?.scopes == ["dives:read", "sites:read"])
    let row = try #require(model.list.value?.last)
    #expect(model.secret(for: row) == CredentialsServer.secret)
    #expect(model.list.value?.dropLast().allSatisfy { model.secret(for: $0) == nil } == true)
    // Added from the answer: the list is not read again.
    #expect(harness.server.credentialRoutes.filter { $0 == "GET user/api-keys" }.count == 1)

    model.done()
    #expect(model.secret(for: row) == nil)
    #expect(model.created == nil)
  }

  @Test func aKeyUsedElsewhereSaysSoOnceTheAppReturnsToTheForeground() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.name = "tide sync"
    await model.create()
    let row = try #require(model.list.value?.last)
    #expect(row.lastUsedAt == nil)

    let following = Task { await model.list.followRouteAndForeground() }
    defer { following.cancel() }
    while !harness.connectivity.isFollowed { await Task.yield() }
    harness.server.use(key: made, at: "2026-11-10T13:00:00Z")
    harness.connectivity.becomeActive()
    for _ in 0..<200 where model.list.value?.last?.lastUsedAt == nil {
      try await Task.sleep(for: .milliseconds(5))
    }
    let used = try #require(model.list.value?.last)
    #expect(used.lastUsedAt != nil)
    #expect(APIKeysModel.details(used, now: model.now, in: .gmt).contains("Last used Nov 10, 2026"))
    // Read again, the row keeps its secret until the diver is done with it.
    #expect(model.secret(for: used) == CredentialsServer.secret)
  }

  @Test func theSecretReachesNoFileAndNoKeychainItem() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
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
    model.name = "tide sync"
    model.grant("dives:write", true)
    await model.create()
    #expect(model.createFailure == "You already have 10 API keys. Revoke one to create another.")
    #expect(model.isCreating)
    #expect(model.name == "tide sync" && model.isGranted("dives:write"))
    #expect(model.created == nil)
  }

  @Test func offlineACreateSaysThereIsNoConnectionAndSendsNothing() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    harness.connectivity.isRouteAvailable = false
    model.name = "tide sync"
    await model.create()
    #expect(model.createFailure == APIError.noRoute.message)
    #expect(!harness.server.credentialRoutes.contains("POST user/api-keys"))
  }

  @Test func aRevocationWaitsForItsConfirmationAndTakesTheSecretWithIt() async throws {
    let harness = try await CredentialsHarness()
    let model = await model(harness)
    model.name = "tide sync"
    await model.create()
    let row = try #require(model.list.value?.last)

    // Dismissed without confirming.
    model.confirmingRevoke = row
    model.confirmingRevoke = nil
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("DELETE") })

    // Confirmed: the dialog clears what it presents as it closes, then its button runs.
    model.confirmingRevoke = row
    model.confirmingRevoke = nil
    await model.confirmRevoke(row)
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
