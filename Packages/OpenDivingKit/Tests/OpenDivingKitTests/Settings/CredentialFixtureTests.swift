import Foundation
import OpenDivingKit
import Testing

/// The passkeys', the signed-in devices' and the API keys' reads round-trip their fixtures,
/// and their bodies encode to theirs exactly.
struct CredentialFixtureTests {
  private let utc = TimeZone(identifier: "UTC")!

  @Test func passkeys() throws {
    let passkeys = try KitFixture.roundTrip([PasskeyRead].self, "passkeys")
    #expect(passkeys.map(\.name) == ["iPhone", "YubiKey"])
    #expect(passkeys.map(\.backedUp) == [true, false])
    #expect(
      passkeys.map { PasskeysModel.details($0, in: utc) } == [
        "Added Oct 1, 2026 · Last used Nov 2, 2026", "Added Oct 5, 2026 · Never used",
      ])
  }

  @Test func signedInDevices() throws {
    let sessions = try KitFixture.roundTrip([UserSessionRead].self, "user-sessions")
    #expect(sessions.map(\.current) == [false, true, false])
    #expect(sessions.map(\.idleTimeout) == [.standard, .extended, .standard])
    #expect(
      sessions.map(SignedInDevicesModel.label) == ["Chrome on macOS", "iPhone", "Unknown device"])
    #expect(
      SignedInDevicesModel.details(sessions[0], in: utc)
        == "203.0.113.7 · Last used Nov 9, 2026, 22:14")
    let revoked = try KitFixture.roundTrip(SessionsRevoked.self, "sessions-revoked")
    #expect(revoked.revoked == 2)
    #expect(SignedInDevicesModel.signedOut(revoked.revoked) == "2 other devices were signed out.")
    #expect(SignedInDevicesModel.signedOut(1) == "1 other device was signed out.")
  }

  @Test func apiKeys() throws {
    let keys = try KitFixture.roundTrip([APIKeyRead].self, "api-keys")
    #expect(keys.map(\.scope) == [.read, .write, .scoped])
    #expect(
      keys.map { APIKeysModel.label($0.scope) } == [
        "Read only", "Read and write", "Custom permissions",
      ])
    #expect(keys.map(\.scopes) == [nil, nil, ["dives:read", "dives:write", "sites:read"]])
    let now = try #require(DiveTimestamp(wireValue: "2026-11-10T12:00:00Z")?.instant)
    #expect(keys.map { $0.isExpired(at: now) } == [true, false, false])
    #expect(
      keys.map { APIKeysModel.details($0, now: now, in: utc) } == [
        "Created Sep 1, 2026 · Last used Nov 8, 2026 · Expired Oct 1, 2026",
        "Created Oct 20, 2026 · Never used · No expiry",
        "Created Nov 12, 2026 · Never used · Expires Nov 12, 2027",
      ])
  }

  @Test func anAPIKeyUsedTheDayBeforeNowSaysSoInItsSentence() throws {
    let key = try KitFixture.decode([APIKeyRead].self, "api-keys")[0]
    let now = try #require(DiveTimestamp(wireValue: "2026-11-09T12:00:00Z")?.instant)
    #expect(
      APIKeysModel.details(key, now: now, in: .gmt)
        == "Created Sep 1, 2026 · Last used yesterday · Expired Oct 1, 2026")
  }

  @Test func anHourLongKeyExpiresTheDayItWasMade() throws {
    let created = try #require(DiveTimestamp(wireValue: "2026-11-25T09:00:00Z"))
    let key = APIKeyRead(
      uuid: UUID(), name: "CI run", prefix: "od_abc", scope: .scoped, scopes: ["dives:read"],
      createdAt: created, lastUsedAt: nil,
      expiresAt: DiveTimestamp(wireValue: "2026-11-25T10:00:00Z"))
    let before = try #require(DiveTimestamp(wireValue: "2026-11-25T09:30:00Z")?.instant)
    let after = try #require(DiveTimestamp(wireValue: "2026-11-25T10:00:00Z")?.instant)
    #expect(
      APIKeysModel.details(key, now: before, in: .gmt)
        == "Created today · Never used · Expires today")
    #expect(
      APIKeysModel.details(key, now: after, in: .gmt)
        == "Created today · Never used · Expired today")
  }

  @Test func permissionsGroupByContentWithTheirActionsInOrder() throws {
    let offered = try KitFixture.decode([String].self, "api-key-permissions")
    let groups = PermissionGroup.groups(offered)
    #expect(groups.count == 18)
    let dives = try #require(groups.first { $0.resource == "dives" })
    #expect(dives.label == "Dives")
    #expect(dives.permissions.map(\.scope) == ["dives:read", "dives:write", "dives:delete"])
    #expect(dives.actions == "Read, Create & edit, Delete")
    #expect(dives.spoken(dives.permissions[1]) == "Create & edit dives")
    #expect(groups.first { $0.resource == "sites" }?.label == "Dive sites")
    #expect(groups.first { $0.resource == "import" }?.actions == "Create & edit")
    let species = try #require(groups.first { $0.resource == "species" })
    #expect(species.label == "Species")
    #expect(species.actions == "Create & edit")

    let reads = PermissionGroup.reads(offered)
    #expect(reads.allSatisfy { $0.hasSuffix(":read") })
    #expect(reads.contains("dives:read") && !reads.contains("checkin:read"))

    let unknown = PermissionGroup.groups(["dive-logs:share", "dives:read"])
    #expect(unknown.map(\.label) == ["dive logs", "Dives"])
    #expect(unknown[0].actions == "share")
  }

  @Test func aCreatedKeyCarriesItsSecretAndIsNeverDescribedWithIt() throws {
    let created = try KitFixture.decode(APIKeyCreated.self, "api-key-created")
    #expect(created.secret == CredentialsServer.secret)
    #expect(created.key.name == "tide sync")
    #expect(created.key.prefix == String(created.secret.prefix(12)))
    var dumped = ""
    dump(created, to: &dumped)
    for text in [String(describing: created), String(reflecting: created), dumped] {
      #expect(!text.contains(created.secret))
      #expect(text.contains("tide sync"))
    }
  }

  @Test func theLifetimesAndTheirLabels() {
    #expect(
      APIKeyLifetime.allCases.map(\.rawValue) == ["1h", "1d", "7d", "30d", "90d", "1y", "never"])
    #expect(
      APIKeyLifetime.allCases.map(APIKeysModel.label) == [
        "1 hour", "1 day", "7 days", "30 days", "90 days", "1 year", "Never",
      ])
  }

  @Test func passkeyUpdate() throws {
    let update = try sendsItsFixture(PasskeyUpdate.self, "request-passkey-update")
    #expect(update.name == "Work laptop")
  }

  @Test func apiKeyCreate() throws {
    let create = try sendsItsFixture(APIKeyCreate.self, "request-api-key-create")
    #expect(create.lifetime == .oneHour)
    #expect(create.scope == .scoped && create.scopes == ["dives:read", "sites:read"])
    let legacy = try JSONValue.parse(
      APICoding.requestEncoder().encode(
        APIKeyCreate(name: "old", scope: .read, lifetime: .never)))
    #expect(
      legacy
        == (try JSONValue.parse(Data(#"{"name":"old","scope":"read","lifetime":"never"}"#.utf8))))
  }

  private func sendsItsFixture<Body: Codable>(_ type: Body.Type, _ name: String) throws -> Body {
    let fixture = try KitFixture.data(name)
    let body = try APICoding.decoder().decode(type, from: fixture)
    let sent = try JSONValue.parse(APICoding.requestEncoder().encode(body))
    #expect(sent == (try JSONValue.parse(fixture)), "\(name): sent \(sent)")
    return body
  }
}
