import Foundation
import OpenDivingKit
import Testing

/// A settings list a server may not have: a 404 leaves the block out, anything else says why.
@MainActor
struct OptionalListTests {
  private func list(_ harness: CredentialsHarness) -> OptionalList<[PasskeyRead]> {
    OptionalList(session: harness.session) { try await $0.passkeys() }
  }

  @Test func aReadLandsTheList() async throws {
    let harness = try await CredentialsHarness()
    let list = list(harness)
    #expect(list.value == nil && !list.isAbsent && list.failure == nil)
    await list.load()
    #expect(list.value?.count == 2)
    #expect(!list.isAbsent)
  }

  @Test func a404IsTheFeatureAbsentNotAFailure() async throws {
    let harness = try await CredentialsHarness()
    harness.server.fail("GET user/passkeys", with: .json(#"{"detail":"Not Found"}"#, status: 404))
    let list = list(harness)
    await list.load()
    #expect(list.isAbsent)
    #expect(list.value == nil)
    #expect(list.failure == nil)
  }

  @Test func anotherFailureKeepsWhatWasReadAndSaysWhy() async throws {
    let harness = try await CredentialsHarness()
    let list = list(harness)
    await list.load()
    harness.server.fail(
      "GET user/passkeys", with: .json(#"{"detail":"Something broke"}"#, status: 500))
    await list.load()
    #expect(list.value?.count == 2)
    #expect(list.failure == "Something broke")
    #expect(!list.isAbsent)

    harness.server.succeed("GET user/passkeys")
    await list.load()
    #expect(list.failure == nil)
  }

  @Test func withNoRouteNothingIsAskedAndAReadFollowsTheRoute() async throws {
    let harness = try await CredentialsHarness()
    let list = list(harness)
    harness.connectivity.isRouteAvailable = false
    await list.load()
    #expect(list.failure == APIError.noRoute.message)
    #expect(!harness.server.credentialRoutes.contains("GET user/passkeys"))

    let following = Task { await list.followRoute() }
    while !harness.connectivity.isFollowed { await Task.yield() }
    harness.connectivity.appear()
    while list.value == nil { await Task.yield() }
    following.cancel()
    await following.value
    #expect(list.failure == nil)
  }

  @Test func anUpdateChangesWhatWasReadAndNothingBefore() async throws {
    let harness = try await CredentialsHarness()
    let list = list(harness)
    list.update { _ in [] }
    #expect(list.value == nil)
    await list.load()
    list.update { Array($0.prefix(1)) }
    #expect(list.value?.map(\.name) == ["iPhone"])
  }
}
