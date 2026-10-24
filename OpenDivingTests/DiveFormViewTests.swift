import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The dive form hosted under an injected session: the sections the account shows, the
/// requests it makes online and offline, and the signed-out form in the account's units.
@MainActor
struct DiveFormViewTests {
  private static let origin = ServerOrigin("https://stub.opendiving.invalid")!
  private static let page =
    #"{"data":[],"total_count":0,"has_more":false,"page":1,"items_per_page":50}"#

  /// `GET /user` for an account in `units` hiding `hidden`.
  private static func user(units: String = "metric", hidden: [String] = []) -> String {
    let keys = hidden.map { "\"\($0)\"" }.joined(separator: ",")
    return """
      {"uuid":"01a0a51f-afe3-7363-a0bc-b0d634c35923","name":"Test Diver","username":"testdiver",
       "email":"diver@example.com","portrait_sha256":null,"units":"\(units)",
       "dive_form_hidden_fields":[\(keys)]}
      """
  }

  /// A transport answering the account and empty pages for everything else a form reads.
  private static func transport(units: String = "metric", hidden: [String] = []) -> StubTransport {
    let user = Self.user(units: units, hidden: hidden)
    let page = Self.page
    return StubTransport { request in
      switch StubTransport.routeKey(request) {
      case "GET user": .json(user)
      case "GET dives/next-number": .json(#"{"dive_number":7,"is_taken":false}"#)
      case "GET dives/recent-volumes": .json(#"{"volumes":[]}"#)
      case "GET user/species/suggest": .json(#"{"results":[],"has_more":false}"#)
      case "POST auth/logout": .json(#"{"message":"Logged out successfully"}"#)
      default: .json(page)
      }
    }
  }

  /// A window tall enough that every section of the form is laid out.
  private func host(_ view: some View, session: Session) throws -> UIWindow {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 430, height: 12_000)
    window.rootViewController = UIHostingController(
      rootView: NavigationStack { view }.environment(session))
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
  }

  /// The form's sections as the hosted list laid them out, once it has: the collection view
  /// SwiftUI's `Form` renders into, which a test can count without VoiceOver running.
  private static func renderedSections(in window: UIWindow) async -> Int? {
    func list(in view: UIView) -> UICollectionView? {
      if let list = view as? UICollectionView { return list }
      for subview in view.subviews {
        if let list = list(in: subview) { return list }
      }
      return nil
    }
    for _ in 0..<100 {
      window.layoutIfNeeded()
      if let list = list(in: window), list.numberOfSections > 1 { return list.numberOfSections }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
  }

  private static func session(_ transport: StubTransport) async throws -> Session {
    let session = Session.stub(origin: origin, transport: transport)
    try await session.loadAccount()
    return session
  }

  @Test func theSectionsAreTheOnesTheAccountShows() async throws {
    let session = try await Self.session(Self.transport())
    let model = DiveFormModel(session: session, mode: .create)
    await model.start()
    let window = try host(DiveFormScreen(model: model), session: session)
    defer { window.isHidden = true }

    #expect(
      model.sections.map(\.title)
        == [
          "Training", "Location", "People", "Dive info", "Environment", "Tanks", "Gear",
          "Marine life", "Notes",
        ])
    // The form draws one section per title, then its actions.
    #expect(await Self.renderedSections(in: window) == model.sections.count + 1)
  }

  @Test func theAccountsHiddenSectionsAreNotOnTheForm() async throws {
    let hidden = [
      "course_uuid", "sightings", "people", "bottom_temperature", "visibility", "water_type",
      "altitude", "waves", "current", "weather", "air_temperature",
    ]
    let session = try await Self.session(Self.transport(hidden: hidden))
    let model = DiveFormModel(session: session, mode: .create)
    await model.start()
    let window = try host(DiveFormScreen(model: model), session: session)
    defer { window.isHidden = true }

    #expect(model.sections.map(\.title) == ["Location", "Dive info", "Tanks", "Gear", "Notes"])
    #expect(await Self.renderedSections(in: window) == model.sections.count + 1)
  }

  @Test func onlineTheFormAsksTheServerForItsNumberAndItsPickers() async throws {
    let transport = Self.transport()
    let session = try await Self.session(transport)
    let window = try host(DiveFormView(mode: .create), session: session)
    defer { window.isHidden = true }

    #expect(await Self.waitFor("GET dives/next-number", on: transport))
    #expect(await Self.waitFor("GET people/lookup", on: transport))
    #expect(await Self.waitFor("GET dive-drafts", on: transport))
  }

  @Test func offlineTheFormAsksTheServerNothing() async throws {
    let transport = Self.transport()
    let route = NoRoute()
    let session = Session(
      transport: transport, secrets: InMemorySecretStore([Self.origin.description: "token"]),
      activeOrigin: InMemoryActiveOriginStore(Self.origin), background: NoBackgroundExecution(),
      connectivity: route,
      applicationSupport: FileManager.default.temporaryDirectory.appendingPathComponent(
        "DiveFormViewTests-\(UUID().uuidString)", isDirectory: true),
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"),
      accessToken: "token")
    try await session.loadAccount()
    let mark = transport.requests.count
    let model = DiveFormModel(session: session, mode: .create)
    await model.start()
    let window = try host(DiveFormScreen(model: model), session: session)
    defer { window.isHidden = true }
    _ = await model.searchServer(.people, matching: "Sam")
    _ = await model.searchSpecies("goby")
    await model.settled()

    #expect(transport.requests.count == mark)
  }

  @Test func signedOutTheFormIsInFeetAndMakesNoRequest() async throws {
    let transport = Self.transport(units: "imperial", hidden: ["course_uuid"])
    let session = try await Self.session(transport)
    try await session.signOut()
    let mark = transport.requests.count
    let model = DiveFormModel(session: session, mode: .create)
    await model.start()
    let window = try host(DiveFormScreen(model: model), session: session)
    defer { window.isHidden = true }

    #expect(await Self.renderedSections(in: window) == model.sections.count + 1)
    #expect(model.label(DiveFormField.maxDepth.label, .depth) == "Maximum depth (ft)")
    #expect(!model.sections.contains(.training))
    model.change { $0.submergedTime = "40" }
    model.change { $0.diveNumber = 1 }
    #expect(model.submit())
    await model.settled()
    #expect(model.outbox.queuedDiveCreates == 1)
    #expect(transport.requests.count == mark)
  }

  /// Waits up to two seconds for `transport` to have been sent `route`.
  private static func waitFor(_ route: String, on transport: StubTransport) async -> Bool {
    for _ in 0..<200 {
      if transport.requests.map(StubTransport.routeKey).contains(route) { return true }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return false
  }
}

/// A phone with no route.
private struct NoRoute: Connectivity {
  var isRouteAvailable: Bool { false }

  func moments() -> AsyncStream<ConnectivityMoment> {
    AsyncStream<ConnectivityMoment>.makeStream().stream
  }
}
