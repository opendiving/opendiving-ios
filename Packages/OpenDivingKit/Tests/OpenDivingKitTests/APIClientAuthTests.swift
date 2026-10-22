import Foundation
import OpenDivingKit
import Synchronization
import Testing

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

struct APIClientAuthTests {
  private static let user = try! KitFixture.text("user")

  @Test func theCookieGoesOnRefreshAndLogoutAndNowhereElse() async throws {
    let harness = ClientHarness { request in
      switch request.route {
      case "POST auth/refresh": .refreshed(access: "access-1", refresh: "refresh-1")
      case "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#)
      case "GET user": .json(Self.user)
      case "GET config": .json(try KitFixture.text("config"))
      default: .json(#"{"detail":"Not Found"}"#, status: 404)
      }
    }
    _ = try await harness.client.instance()
    _ = try await harness.client.currentUser()
    try await harness.client.signOut()

    let requests = harness.transport.requests
    #expect(
      requests.map(\.route) == [
        "GET config", "GET health", "POST auth/refresh", "GET user", "POST auth/logout",
      ])
    for request in requests {
      let wantsCookie = ["POST auth/refresh", "POST auth/logout"].contains(request.route)
      #expect((request.cookie != nil) == wantsCookie, "\(request.route)")
    }
    #expect(requests[2].cookie == "refresh_token=refresh-0")
    #expect(requests[4].cookie == "refresh_token=refresh-1")
    #expect(harness.storedRefreshToken == nil)
  }

  @Test func signingInKeepsTheRefreshTokenAndTheAccessToken() async throws {
    let harness = ClientHarness(refreshToken: nil) { request in
      switch request.route {
      case "POST auth/email/verify-code":
        .json(
          try KitFixture.text("auth-outcome-authenticated"),
          headers: ["Set-Cookie": "refresh_token=fresh; HttpOnly; Path=/; SameSite=lax"])
      default: .json(Self.user)
      }
    }
    let requestID = UUID()
    let outcome = try await harness.client.verifyEmailCode(requestID: requestID, code: "123456")
    #expect(outcome.status == "authenticated")
    #expect(harness.storedRefreshToken == "fresh")
    _ = try await harness.client.currentUser()
    #expect(harness.transport.requests.last?.bearer == "access-1")
    let body = try #require(harness.transport.requests.first?.httpBody)
    let sent = try JSONDecoder().decode([String: String].self, from: body)
    #expect(sent == ["request_id": requestID.uuidString.lowercased(), "code": "123456"])
  }

  @Test(arguments: ["auth-outcome-onboarding", "auth-outcome-deletion-pending"])
  func anOutcomeThatIsNotASignInStoresNothing(fixture: String) async throws {
    let harness = ClientHarness(refreshToken: nil) { _ in .json(try KitFixture.text(fixture)) }
    _ = try await harness.client.verifyEmailCode(requestID: UUID(), code: "123456")
    #expect(harness.storedRefreshToken == nil)
  }

  @Test func aWrongCodeIsAnAnswerNotAnExpiredSession() async throws {
    let harness = ClientHarness { _ in
      .json(#"{"detail":"This code is invalid or has expired."}"#, status: 401)
    }
    await #expect(
      throws: APIError.http(status: 401, message: "This code is invalid or has expired.")
    ) {
      try await harness.client.verifyEmailCode(requestID: UUID(), code: "000000")
    }
    #expect(harness.transport.requests.map(\.route) == ["POST auth/email/verify-code"])
    #expect(harness.storedRefreshToken == "refresh-0")
  }

  @Test func anUninvitedAddressIsTheAPIsSentence() async throws {
    let harness = ClientHarness { _ in
      .json(#"{"detail":"This address has not been invited."}"#, status: 403)
    }
    await #expect(
      throws: APIError.http(status: 403, message: "This address has not been invited.")
    ) {
      try await harness.client.verifyEmailCode(requestID: UUID(), code: "123456")
    }
  }

  @Test func concurrentUnauthorisedRequestsShareOneRefresh() async throws {
    let harness = ClientHarness(accessToken: "stale") { request in
      switch request.route {
      case "POST auth/refresh": return .refreshed(access: "fresh", refresh: "refresh-1")
      default: return request.bearer == "fresh" ? .json(Self.user) : .unauthorized
      }
    }
    try await withThrowingTaskGroup(of: UserRead.self) { group in
      for _ in 0..<10 {
        group.addTask { try await harness.client.currentUser() }
      }
      for try await user in group {
        #expect(user.username == "testdiver")
      }
    }
    let refreshes = harness.transport.requests.filter { $0.route == "POST auth/refresh" }
    #expect(refreshes.count == 1)
    #expect(harness.storedRefreshToken == "refresh-1")
  }

  @Test func unauthorisedRefreshesOnceAndRetriesOnce() async throws {
    let harness = ClientHarness(accessToken: "stale") { request in
      switch request.route {
      case "POST auth/refresh": return .refreshed(access: "fresh", refresh: "refresh-1")
      default: return request.bearer == "fresh" ? .json(Self.user) : .unauthorized
      }
    }
    _ = try await harness.client.currentUser()
    #expect(
      harness.transport.requests.map(\.route) == ["GET user", "POST auth/refresh", "GET user"])
    #expect(harness.transport.requests.map(\.bearer) == ["stale", nil, "fresh"])
  }

  @Test func aSecondUnauthorisedEndsTheSession() async throws {
    let harness = ClientHarness(accessToken: "stale") { request in
      request.route == "POST auth/refresh"
        ? .refreshed(access: "fresh", refresh: "refresh-1") : .unauthorized
    }
    await #expect(throws: APIError.signedOut) { try await harness.client.currentUser() }
    #expect(
      harness.transport.requests.map(\.route) == ["GET user", "POST auth/refresh", "GET user"])
    #expect(harness.storedRefreshToken == nil)
    #expect(harness.sessionEnded)
  }

  @Test func aRefusedRefreshEndsTheSession() async throws {
    let harness = ClientHarness(accessToken: "stale") { _ in .unauthorized }
    await #expect(throws: APIError.signedOut) { try await harness.client.currentUser() }
    #expect(harness.transport.requests.map(\.route) == ["GET user", "POST auth/refresh"])
    #expect(harness.storedRefreshToken == nil)
    #expect(harness.sessionEnded)
  }

  @Test func aRefreshThatNeverReachedTheServerKeepsTheSession() async throws {
    let harness = ClientHarness(accessToken: "stale") { request in
      if request.route == "POST auth/refresh" { throw URLError(.networkConnectionLost) }
      return .unauthorized
    }
    do {
      _ = try await harness.client.currentUser()
      Issue.record("Expected the refresh to fail")
    } catch let APIError.unreachable(failure) {
      #expect(failure.code == URLError.Code.networkConnectionLost.rawValue)
    }
    #expect(harness.storedRefreshToken == "refresh-0")
    #expect(!harness.sessionEnded)
  }

  @Test func withNoRefreshTokenNothingIsSent() async throws {
    let harness = ClientHarness(refreshToken: nil) { _ in .json(Self.user) }
    await #expect(throws: APIError.signedOut) { try await harness.client.currentUser() }
    #expect(harness.transport.requests.isEmpty)
  }

  @Test func aLogoutRetriedAfterARefreshCarriesTheRotatedCookie() async throws {
    let harness = ClientHarness(accessToken: "aged-out") { request in
      switch request.route {
      case "POST auth/refresh":
        return .refreshed(access: "fresh", refresh: "refresh-1")
      case "POST auth/logout":
        return request.bearer == "fresh"
          ? .json(#"{"message":"Logged out successfully"}"#) : .unauthorized
      default:
        return .unauthorized
      }
    }
    try await harness.client.signOut()
    let requests = harness.transport.requests
    #expect(requests.map(\.route) == ["POST auth/logout", "POST auth/refresh", "POST auth/logout"])
    #expect(requests[0].cookie == "refresh_token=refresh-0")
    #expect(requests[2].cookie == "refresh_token=refresh-1")
    #expect(requests[2].bearer == "fresh")
    #expect(harness.storedRefreshToken == nil)
  }

  @Test func aFailedLogoutKeepsTheSession() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in
      throw URLError(.notConnectedToInternet)
    }
    await #expect(throws: APIError.self) { try await harness.client.signOut() }
    #expect(harness.storedRefreshToken == "refresh-0")
  }

  @Test func theBackgroundAssertionSpansSendToWriteOnTheRefreshAlone() async throws {
    let harness = ClientHarness(accessToken: "aged-out") { request in
      switch request.route {
      case "POST auth/refresh":
        return .refreshed(access: "fresh", refresh: "refresh-1")
      case "POST auth/logout":
        return request.bearer == "fresh"
          ? .json(#"{"message":"Logged out successfully"}"#) : .unauthorized
      default:
        return request.bearer == "fresh" ? .json(Self.user) : .unauthorized
      }
    }
    try await harness.client.refreshSession()
    _ = try await harness.client.currentUser()
    #expect(
      harness.log.all == [
        "begin", "send POST auth/refresh", "write refresh-1", "end", "send GET user",
      ])

    let logout = ClientHarness(accessToken: "aged-out") { request in
      switch request.route {
      case "POST auth/refresh": .refreshed(access: "fresh", refresh: "refresh-1")
      default:
        request.bearer == "fresh" ? .json(#"{"message":"Logged out successfully"}"#) : .unauthorized
      }
    }
    try await logout.client.signOut()
    #expect(
      logout.log.all == [
        "send POST auth/logout", "begin", "send POST auth/refresh", "write refresh-1", "end",
        "send POST auth/logout", "remove",
      ])
  }

  @Test func theUserAgentNamesTheAppAndTheModelWord() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in .json(Self.user) }
    _ = try await harness.client.currentUser()
    #expect(
      harness.transport.requests.first?.value(forHTTPHeaderField: "User-Agent")
        == "OpenDiving-iOS/1.2.3 (iOS 18.6; iPhone)")
  }

  @Test func listsAskForFiftyAndPathsUseLowercaseUUIDs() async throws {
    let harness = ClientHarness(accessToken: "live") { _ in .emptyPage }
    let trip = UUID()
    _ = try await harness.client.dives(page: 2, tripUUID: trip)
    _ = try await harness.client.diveSites(page: 1)
    let urls = harness.transport.requests.compactMap { $0.url?.absoluteString }
    #expect(
      urls == [
        "https://dive.example.org/api/v1/dives?page=2&items_per_page=50&trip_uuid="
          + trip.uuidString.lowercased(),
        "https://dive.example.org/api/v1/dive-sites?page=1&items_per_page=50&sort=last_dived_on",
      ])
  }

  @Test func aProfileIsFetchedConditionally() async throws {
    let profile = try KitFixture.text("profile")
    let harness = ClientHarness(accessToken: "live") { request in
      request.value(forHTTPHeaderField: "If-None-Match") == "\"p-r3\""
        ? StubTransport.Response(status: 304)
        : .json(profile, headers: ["ETag": "\"p-r3\""])
    }
    let dive = UUID()
    let recording = UUID()
    guard
      case .fetched(let fetched, let etag) = try await harness.client.profile(
        dive: dive, recording: recording, etag: nil)
    else {
      Issue.record("Expected a profile")
      return
    }
    #expect(etag == "\"p-r3\"")
    #expect(fetched.provenance == "file")
    let again = try await harness.client.profile(dive: dive, recording: recording, etag: etag)
    #expect(again == .notModified)
  }

  @Test func errorsCarryTheStatusAndTheDetailInEitherShape() async throws {
    let validation = try KitFixture.text("error-validation")
    let harness = ClientHarness(accessToken: "live") { request in
      request.route == "GET user"
        ? .json(validation, status: 422)
        : .json(#"{"detail":"This recording has no profile"}"#, status: 404)
    }
    await #expect(
      throws: APIError.http(status: 422, message: "Input should be greater than or equal to 0")
    ) { try await harness.client.currentUser() }
    await #expect(throws: APIError.http(status: 404, message: "This recording has no profile")) {
      try await harness.client.profile(dive: UUID(), recording: UUID(), etag: nil)
    }
  }

  @Test func allPagesFollowsHasMore() async throws {
    let pages = Mutex(0)
    let items = try await APIClient.allPages { page, perPage in
      pages.withLock { $0 += 1 }
      return PaginatedListResponse(
        data: [page], totalCount: 3, hasMore: page < 3, page: page, itemsPerPage: perPage)
    }
    #expect(items == [1, 2, 3])
    #expect(pages.withLock { $0 } == 3)
  }
}
