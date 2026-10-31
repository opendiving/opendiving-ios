import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// Every signed-out screen, and Settings, rendered under an injected session the way the root
/// injects it.
@MainActor
struct SignInViewTests {
  private static let origin = ServerOrigin("https://stub.opendiving.invalid")!
  private static let requestID = "01a16586-8c04-7333-aa51-b37555e35546"

  private static func json(_ text: String, status: Int = 200) -> StubTransport.Response {
    .json(text, status: status)
  }

  private static let onboarding = json(
    #"{"status":"onboarding_required","access_token":null,"token_type":null,"#
      + #""onboarding_token":"onb","name":"Sam","restore_token":null,"purge_after":null,"#
      + #""email":"sam@example.com"}"#)

  private static let deletion = json(
    #"{"status":"deletion_pending","access_token":null,"token_type":null,"#
      + #""onboarding_token":null,"name":null,"restore_token":"rst","#
      + #""purge_after":"2026-11-21T10:00:00Z","email":"sam@example.com"}"#)

  /// A flow at the code screen, whose code redeems into `outcome`.
  private static func atTheCode(_ outcome: StubTransport.Response) async -> (Session, SignInFlow) {
    let session = Session.signedOutStub(
      origin: origin,
      transport: StubTransport(routes: [
        "POST auth/email/request": json(
          #"{"message":"Check your email for the next step.","request_id":"\#(requestID)"}"#),
        "POST auth/email/verify-code": outcome,
      ]))
    let flow = SignInFlow(session: session)
    flow.setEmail("sam@example.com")
    await flow.sendCode()
    return (session, flow)
  }

  @Test func theServerScreen() async throws {
    let session = Session.signedOutStub(origin: nil, transport: StubTransport(routes: [:]))
    #expect(
      try await Self.title(of: SignInView(), session, SignInFlow(session: session))
        == "Servers")
  }

  @Test func theEmailScreen() async throws {
    let session = Session.signedOutStub(transport: StubTransport(routes: [:]))
    #expect(
      try await Self.title(of: SignInView(), session, SignInFlow(session: session)) == "Sign in")
  }

  @Test func theCodeScreen() async throws {
    let (session, flow) = await Self.atTheCode(Self.onboarding)
    #expect(try await Self.title(of: SignInView(), session, flow) == "Check your email")
  }

  @Test func theUnfinishedAccountScreen() async throws {
    let (session, flow) = await Self.atTheCode(Self.onboarding)
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.step == .onboardingRequired(email: "sam@example.com", name: "Sam"))
    #expect(try await Self.title(of: SignInView(), session, flow) == "Sign in")
  }

  @Test func theDeletionPendingScreen() async throws {
    let (session, flow) = await Self.atTheCode(Self.deletion)
    flow.setCode("123456")
    await flow.submitCode()
    guard case .deletionPending = flow.step else {
      Issue.record("Expected deletion pending, got \(flow.step)")
      return
    }
    #expect(try await Self.title(of: SignInView(), session, flow) == "Sign in")
  }

  @Test func theUninvitedSentenceStaysOnTheCodeScreen() async throws {
    let sentence = "This email address has not been invited to this instance."
    let (session, flow) = await Self.atTheCode(
      Self.json(#"{"detail":"\#(sentence)"}"#, status: 403))
    flow.setCode("123456")
    await flow.submitCode()
    #expect(flow.codeError == sentence)
    #expect(try await Self.title(of: SignInView(), session, flow) == "Check your email")
  }

  @Test func settings() async throws {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    #expect(
      try await Self.title(of: SettingsView(), session, SignInFlow(session: session)) == "Settings")
  }

  /// Renders `view` in a window under `session` and `flow`, and reads the navigation title it
  /// settles on.
  private static func title(of view: some View, _ session: Session, _ flow: SignInFlow)
    async throws -> String?
  {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(
      rootView: view.environment(session).environment(flow)
        .environment(OutboxModel(session: session)).environment(InboxModel(session: session)))
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    for _ in 0..<50 {
      window.layoutIfNeeded()
      if let title = navigationController(in: window.rootViewController)?
        .topViewController?.navigationItem.title
      {
        return title
      }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
  }

  private static func navigationController(in controller: UIViewController?)
    -> UINavigationController?
  {
    guard let controller else { return nil }
    if let navigation = controller as? UINavigationController { return navigation }
    for child in controller.children {
      if let navigation = navigationController(in: child) { return navigation }
    }
    return nil
  }
}
