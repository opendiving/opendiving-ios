import Foundation
import OpenDivingKit
import SwiftUI
import Synchronization
import Testing
import UIKit

@testable import OpenDiving

/// A pull on More's lists and pages reads them to the end while the screen draws again under it.
@MainActor
struct PullRefreshTests {
  private typealias F = OfflineFixtures

  nonisolated private static let gearItemUUID = "01a14b2e-0c3d-7a10-9f00-3a2b3c4d5e6f"
  nonisolated private static let gearItem =
    #"{"uuid":"\#(gearItemUUID)","name":"12 L steel","brand":null,"type":"cylinder","#
    + #""notes":"","rented":false,"volume":12.0,"working_pressure":232.0,"material":"steel","#
    + #""user_uuid":"\#(F.accountA)","is_archived":false,"archived_at":null,"dive_count":0,"#
    + #""dive_time":0,"service":[],"created_at":"2026-10-24T09:00:00.000001Z"}"#

  @Test func aPullOnAListReadsItThrough() async throws {
    try await pull(GearListView())
    try await pull(MarineLifeListView())
    try await pull(CertificationListView())
    try await pull(CourseListView())
    try await pull(PeopleListView())
    try await pull(ContactListView())
    try await pull(YourDiveSitesView())
  }

  @Test func aPullOnAPageReadsItThrough() async throws {
    try await pull(GearItemDetailView(gearItemUUID: UUID(uuidString: Self.gearItemUUID)!))
  }

  /// Shows `view`, pulls it once it has settled, and expects every read the pull starts to be
  /// answered rather than cancelled.
  private func pull(_ view: some View, sourceLocation: SourceLocation = #_sourceLocation)
    async throws
  {
    let transport = AnsweringLater { request in
      if let answer = F.account(request) { return answer }
      if StubTransport.routeKey(request) == "GET gear-items/\(Self.gearItemUUID)" {
        return .json(Self.gearItem)
      }
      return F.emptyPage
    }
    let session = F.signedIn(F.directory(), transport: transport)
    try await session.loadAccount()
    let window = try #require(
      F.window(
        NavigationStack { view }
          .environment(session)
          .environment(OutboxModel(session: session))
          .environment(InboxModel(session: session))),
      sourceLocation: sourceLocation)
    defer { window.isHidden = true }

    var control: UIRefreshControl?
    #expect(
      await F.eventually {
        window.layoutIfNeeded()
        control = Self.refreshControl(in: window)
        return control != nil && transport.isIdle
      }, sourceLocation: sourceLocation)
    // Between two reads nothing is in flight for a moment.
    try await Task.sleep(for: .milliseconds(500))
    let sent = transport.answered.count
    control?.beginRefreshing()
    control?.sendActions(for: .valueChanged)

    #expect(
      await F.eventually { transport.answered.count > sent && transport.isIdle },
      sourceLocation: sourceLocation)
    try await Task.sleep(for: .milliseconds(500))
    #expect(transport.isIdle, sourceLocation: sourceLocation)
    #expect(transport.answered.dropFirst(sent).contains("GET user"), sourceLocation: sourceLocation)
    #expect(transport.cancelled.isEmpty, sourceLocation: sourceLocation)
  }

  private static func refreshControl(in view: UIView) -> UIRefreshControl? {
    if let control = (view as? UIScrollView)?.refreshControl { return control }
    return view.subviews.lazy.compactMap { refreshControl(in: $0) }.first
  }
}

/// Answers each request after a moment, so a read cut short is cut short on the wire, and keeps
/// the routes answered and cancelled.
nonisolated private final class AnsweringLater: HTTPTransport {
  private let inner: StubTransport
  private let state = Mutex((inFlight: 0, answered: [String](), cancelled: [String]()))

  init(_ handler: @escaping StubTransport.Handler) {
    inner = StubTransport(handler)
  }

  var answered: [String] { state.withLock { $0.answered } }
  var cancelled: [String] { state.withLock { $0.cancelled } }
  var isIdle: Bool { state.withLock { $0.inFlight == 0 } }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let route = StubTransport.routeKey(request)
    state.withLock { $0.inFlight += 1 }
    defer { state.withLock { $0.inFlight -= 1 } }
    do {
      try await Task.sleep(for: .milliseconds(100))
    } catch {
      state.withLock { $0.cancelled.append(route) }
      throw URLError(.cancelled)
    }
    state.withLock { $0.answered.append(route) }
    return try await inner.send(request)
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await send(request)
  }
}
