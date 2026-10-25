import Foundation
import OpenDivingKit
import SwiftUI
import Synchronization
import UIKit

/// Sessions over a directory the test chooses, so two of them — two launches, or signed in
/// and then signed out — share one phone's stores, and the transports and the path the
/// offline tests need.
enum OfflineFixtures {
  static let origin = ServerOrigin("https://stub.opendiving.invalid")!
  static let accountA = "01a0a51f-afe3-7363-a0bc-b0d634c35923"
  static let accountB = "01a0a51f-afe3-7363-a0bc-b0d634c3592b"

  static func directory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("OpenDivingOffline-\(UUID().uuidString)", isDirectory: true)
  }

  /// Signed in to ``origin`` with an access token in hand, over `directory`.
  @MainActor
  static func signedIn(
    _ directory: URL, transport: any HTTPTransport,
    connectivity: any Connectivity = AlwaysReachable()
  ) -> Session {
    Session(
      transport: transport, secrets: InMemorySecretStore([origin.description: "refresh"]),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      connectivity: connectivity, applicationSupport: directory,
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"),
      accessToken: "access")
  }

  /// Pointed at ``origin`` and signed out of it, over `directory`.
  @MainActor
  static func signedOut(_ directory: URL) -> Session {
    Session(
      transport: StubTransport(routes: [:]), secrets: InMemorySecretStore(),
      activeOrigin: InMemoryActiveOriginStore(origin), background: NoBackgroundExecution(),
      applicationSupport: directory,
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"))
  }

  static func user(_ uuid: String) -> StubTransport.Response {
    .json(
      #"{"uuid":"\#(uuid)","name":"Test Diver","username":"testdiver","#
        + #""email":"diver@example.com","portrait_sha256":null,"units":"metric"}"#)
  }

  static let emptyPage = StubTransport.Response.json(
    #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#)

  static func page(_ item: String) -> StubTransport.Response {
    .json(#"{"data":[\#(item)],"total_count":1,"has_more":false,"page":1,"items_per_page":50}"#)
  }

  static let notFound = StubTransport.Response.json(#"{"detail":"Not Found"}"#, status: 404)

  /// `GET /user` as `account` and `GET /people` empty; nil for any other route.
  static func account(_ request: URLRequest, as account: String = accountA)
    -> StubTransport.Response?
  {
    switch StubTransport.routeKey(request) {
    case "GET user": user(account)
    case "GET people": emptyPage
    default: nil
    }
  }

  static let trip =
    #"{"uuid":"01a0a57a-92c3-73d0-8f2c-e200878f9878","name":"Dahab 2026 (September)","notes":"","#
    + #""parts":[{"start_date":"2026-09-06","end_date":null,"location":null,"#
    + #""accommodation_uuid":null,"candidate_count":0}],"people":[],"dive_count":0,"#
    + #""dive_site_count":0,"species_count":0,"max_depth":null,"candidate_count":0,"#
    + #""contact_uuids":[],"user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","#
    + #""created_at":"2026-09-15T14:31:08.739630Z"}"#

  static let site =
    #"{"uuid":"01a0a521-28c5-7e34-a572-4d7324f5033b","dive_count":2,"last_dived_on":"2026-04-17","#
    + #""max_dive_depth":46.41,"species_count":0,"average_rating":null,"other_names":[],"#
    + #""external_ids":[],"depth_from":null,"depth_to":null,"water_type":null,"altitude":null,"#
    + #""entry_types":[],"name":"Tiger Reef","latitude":null,"longitude":null,"notes":"","#
    + #""location":null,"tags":[],"user_uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","#
    + #""created_at":"2026-09-15T12:53:28.901059Z"}"#

  static let start = DiveTimestamp(wireValue: "2026-10-25T09:30:00+03:00")!

  /// A window of the test host showing `view`.
  @MainActor
  static func window(_ view: some View) -> UIWindow? {
    guard
      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
    else { return nil }
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(rootView: view)
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
  }

  /// Waits up to `seconds` for `condition`.
  @MainActor
  static func eventually(_ seconds: Double = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
  }
}

/// A switch a transport's handler reads.
final class Flag: Sendable {
  private let value: Mutex<Bool>
  init(_ value: Bool) { self.value = Mutex(value) }
  var isOn: Bool { value.withLock { $0 } }
  func set(_ on: Bool) { value.withLock { $0 = on } }
}

/// A counter a transport's handler bumps.
final class Counter: Sendable {
  private let value = Mutex(0)
  /// The count before this call.
  func next() -> Int {
    value.withLock { count in
      defer { count += 1 }
      return count
    }
  }
}

/// The connectivity seam over a path the test drives: each moment it is told goes to every
/// subscriber.
nonisolated final class FakePath: Connectivity {
  private let subscribers = Mutex<[UUID: AsyncStream<ConnectivityMoment>.Continuation]>([:])

  var isRouteAvailable: Bool { true }

  var routeAppearances: Int { 0 }

  var subscriberCount: Int { subscribers.withLock { $0.count } }

  func moments() -> AsyncStream<ConnectivityMoment> {
    let (stream, continuation) = AsyncStream.makeStream(of: ConnectivityMoment.self)
    let id = UUID()
    subscribers.withLock { $0[id] = continuation }
    continuation.onTermination = { [weak self] _ in
      _ = self?.subscribers.withLock { $0.removeValue(forKey: id) }
    }
    return stream
  }

  func emit(_ moment: ConnectivityMoment) {
    for continuation in subscribers.withLock({ Array($0.values) }) {
      continuation.yield(moment)
    }
  }
}

/// A transport that never answers until it is released, then fails every request held and
/// every one after with no route: a phone on the boat.
nonisolated final class HeldTransport: HTTPTransport {
  private struct State {
    var released = false
    var waiting: [CheckedContinuation<Void, Never>] = []
    var routes: [String] = []
  }

  private let state = Mutex(State())

  /// Every request sent so far, by route.
  var routes: [String] { state.withLock { $0.routes } }

  func release() {
    let waiting = state.withLock { state in
      state.released = true
      defer { state.waiting = [] }
      return state.waiting
    }
    for continuation in waiting { continuation.resume() }
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    await withCheckedContinuation { continuation in
      let released = state.withLock { state in
        state.routes.append(StubTransport.routeKey(request))
        if !state.released { state.waiting.append(continuation) }
        return state.released
      }
      if released { continuation.resume() }
    }
    throw URLError(.notConnectedToInternet)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await send(request)
  }
}
