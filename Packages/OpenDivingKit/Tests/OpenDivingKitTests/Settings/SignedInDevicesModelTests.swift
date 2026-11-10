import Foundation
import OpenDivingKit
import Testing

/// *Authentication*'s signed-in devices: this phone first and untouchable, every other signed
/// out one at a time or all at once.
@MainActor
struct SignedInDevicesModelTests {
  private let mac = UUID(uuidString: "019a2b3c-4d5e-7f60-8a1b-2c3d4e5f6a70")!
  private let phone = UUID(uuidString: "019a2b3c-4d5e-7f60-8a1b-2c3d4e5f6a71")!

  @Test func thisPhoneLeadsMarkedAndTheRestKeepTheServersOrder() async throws {
    let harness = try await CredentialsHarness()
    let model = SignedInDevicesModel(session: harness.session)
    await model.list.load()
    #expect(model.rows.count == 3)
    #expect(model.rows.first?.uuid == phone)
    #expect(
      model.rows.map(SignedInDevicesModel.label) == ["iPhone", "Chrome on macOS", "Unknown device"])
    #expect(model.rows.first?.idleTimeout == .extended)
    #expect(model.hasOthers)
  }

  @Test func thisPhoneIsNeverSignedOutFromHere() async throws {
    let harness = try await CredentialsHarness()
    let model = SignedInDevicesModel(session: harness.session)
    await model.list.load()
    model.confirmingSignOut = model.rows.first
    await model.confirmSignOut()
    #expect(!harness.server.credentialRoutes.contains { $0.hasPrefix("DELETE") })
  }

  @Test func anotherDeviceIsSignedOutAfterItsConfirmation() async throws {
    let harness = try await CredentialsHarness()
    let model = SignedInDevicesModel(session: harness.session)
    await model.list.load()
    let device = try #require(model.rows.first { $0.uuid == mac })
    #expect(
      SignedInDevicesModel.signOutMessage(device)
        == "Chrome on macOS (203.0.113.7) will have to sign in again. It loses access"
        + " immediately, on its very next request.")
    model.confirmingSignOut = device
    await model.confirmSignOut()
    #expect(
      harness.server.credentialRoutes.suffix(2) == [
        "DELETE user/session/\(mac.uuidString.lowercased())", "GET user/sessions",
      ])
    #expect(model.rows.count == 2)
    #expect(model.failure == nil)
  }

  @Test func signingTheOthersOutReportsTheServersCount() async throws {
    let harness = try await CredentialsHarness()
    let model = SignedInDevicesModel(session: harness.session)
    await model.list.load()
    model.confirmingSignOutOthers = true
    await model.confirmSignOutOthers()
    #expect(
      harness.server.credentialRoutes.suffix(2) == ["DELETE user/sessions", "GET user/sessions"])
    #expect(model.outcome == "2 other devices were signed out.")
    #expect(model.rows.map(\.uuid) == [phone])
    #expect(!model.hasOthers)
    #expect(!model.confirmingSignOutOthers)
  }

  @Test func aRefusalIsTheAPIsSentence() async throws {
    let harness = try await CredentialsHarness()
    let model = SignedInDevicesModel(session: harness.session)
    await model.list.load()
    harness.server.fail(
      "DELETE user/sessions", with: .json(#"{"detail":"Too many requests"}"#, status: 429))
    await model.confirmSignOutOthers()
    #expect(model.failure == "Too many requests")
    #expect(model.outcome == nil)
    #expect(model.rows.count == 3)
  }
}
