import Foundation
import Observation

/// The signed-out screens: choosing a server, an email, the code, and what redeeming it led to.
/// The root holds one for the app's life, so that Settings can send the user back to the
/// server screen and a *Forget* can report what it did on the screen that follows it.
@MainActor
@Observable
public final class SignInFlow {
  public enum Step: Hashable, Sendable {
    case server
    case email
    case code(email: String, requestID: UUID)
    /// The account exists but sign-up was never finished, which happens on the web.
    case onboardingRequired(email: String?, name: String?)
    /// `purgeAfter` is the day the account stops being recoverable, ready to print.
    case deletionPending(email: String?, purgeAfter: String?)
  }

  /// What the server field holds when no server is active.
  public static let defaultServer = "https://opendiving.app"
  public static let codeLength = 6
  /// Seconds before *Resend* is offered again: the web's cooldown. The server's own limit is
  /// three requests per address per 15 minutes, and its 429 says so.
  public static let resendCooldown: TimeInterval = 30
  /// How long a sign-out is waited for before *Sign out* gives up and *Forget* goes on without
  /// it. A server that is gone would otherwise hold the screen through every retry of the
  /// refresh that goes in front of the logout, a minute and more.
  public static let signOutWait: Duration = .seconds(10)

  public let session: Session
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let waitLimit: Duration

  private var chosenStep = Step.email

  public private(set) var serverText: String
  public private(set) var isValidating = false
  public private(set) var serverProblem: ServerProblem?
  /// The typed origin, when the phone holds something for it that forgetting would remove —
  /// offered whether or not the server answers, since forgetting needs no server.
  public private(set) var forgettableOrigin: ServerOrigin?
  /// What the last *Forget* did, shown on the screen it lands on: the servers screen, or the
  /// signed-out screen it started from when it did not work. Settings shows its own *Forget*'s
  /// failure, through ``forget(_:)``'s answer, and dismisses this; the next sign-out, server
  /// or switch clears it.
  public private(set) var notice: String?
  /// The server a sign-out is waited for, until it answers, ``signOutWait`` runs out or the
  /// user stops waiting.
  public private(set) var signingOut: ServerOrigin?
  /// The wait in progress, numbered so that a sign-out left behind by an earlier wait — still
  /// awaiting a refresh that cancelling it does not stop — cannot end this one.
  @ObservationIgnored private var signOutWaiter:
    (number: Int, continuation: CheckedContinuation<SignOutResult, Never>)?
  @ObservationIgnored private var signOutWaits = 0

  public private(set) var email = ""
  public private(set) var isRequestingCode = false
  public private(set) var emailError: String?

  public private(set) var code = ""
  public private(set) var isVerifying = false
  public private(set) var codeError: String?
  public private(set) var isResending = false
  public private(set) var resendMessage: String?
  private var codeSentAt: Date?

  /// `signOutWait` stands in for ``signOutWait`` in a test.
  public init(
    session: Session, now: @escaping () -> Date = { Date() },
    signOutWait: Duration = SignInFlow.signOutWait
  ) {
    self.session = session
    self.now = now
    waitLimit = signOutWait
    serverText = Self.emptyServerText(session)
    refreshForgettable()
  }

  /// The screen to show. With no server active it is always the server screen.
  public var step: Step {
    session.state == .noServer ? .server : chosenStep
  }

  /// Exactly what the sign-in screen offers besides signing in: everything while a server is
  /// active — the pending screen only once an account has loaded there, since it is that
  /// account's — and nothing on the server screen with none.
  public var signedOutEntries: [SignedOutEntry] {
    guard case .signingIn(let origin) = session.state else { return [] }
    let hasAccount = session.store.lastAccount(for: origin) != nil
    return SignedOutEntry.allCases.filter { $0 != .waitingToSync || hasAccount }
  }

  /// The active server, while signing in to it.
  public var origin: ServerOrigin? { session.state.origin }

  // MARK: - The servers screen

  /// The saved servers, the active one marked, each with whether the phone is signed in there.
  public var savedServers: [SavedServer] {
    session.savedServers.map { origin in
      let status: String
      if session.isSignedIn(to: origin) {
        status = session.account(on: origin).map { "Signed in as \($0.email)" } ?? "Signed in"
      } else {
        status = "Signed out"
      }
      return SavedServer(origin: origin, isActive: origin == session.state.origin, status: status)
    }
  }

  public func setServerText(_ text: String) {
    serverText = text
    serverProblem = nil
    refreshForgettable()
  }

  /// Whether the servers screen can go back to signing in to the server already active. Signed
  /// in, Settings goes back by navigation instead.
  public var canCancelServerChange: Bool {
    if case .signingIn = session.state { return true }
    return false
  }

  /// Asks the typed server whether it is an OpenDiving instance and, when it is, points the
  /// app at it and saves it. Every other server keeps its session and its state.
  public func continueToServer() async {
    guard !isValidating else { return }
    notice = nil
    guard let origin = ServerOrigin(serverText) else {
      serverProblem = .unreadableAddress
      return
    }
    isValidating = true
    defer { isValidating = false }
    do {
      let info = try await session.validate(origin)
      // Choosing the active server again would drop its account for nothing.
      if session.state.origin != origin {
        session.select(origin, info: info)
      }
      serverText = ""
      serverProblem = nil
      restart(at: .email)
    } catch {
      serverProblem = ServerProblem(APIError(error), origin: origin)
    }
    refreshForgettable()
  }

  /// Points the app at a saved server without asking it anything — signed in there when the
  /// phone still holds that session — so a server that is gone is left, or reached to be
  /// forgotten, at once. The server left keeps its session.
  public func switchTo(_ origin: ServerOrigin) {
    guard origin != session.state.origin, signingOut == nil else { return }
    notice = nil
    serverProblem = nil
    session.select(origin)
    restart(at: .email)
    refreshForgettable()
  }

  public func useDifferentServer() {
    notice = nil
    serverProblem = nil
    chosenStep = .server
  }

  public func cancelServerChange() {
    guard canCancelServerChange else { return }
    notice = nil
    serverProblem = nil
    restart(at: .email)
  }

  public func dismissNotice() {
    notice = nil
  }

  /// Signs out of `origin` when the phone holds a session there, then removes everything kept
  /// for it whether or not that worked — a server that is gone can never answer the sign-out,
  /// and its sheet would otherwise stay on the phone for good. A sign-out that did not happen
  /// is reported, not a reason to stop. Answers why something kept for the server could not be
  /// removed, or nil when everything was.
  @discardableResult
  public func forget(_ origin: ServerOrigin) async -> String? {
    guard signingOut == nil else { return Self.stillSigningOut }
    var signOut: SignOutResult?
    if session.isSignedIn(to: origin) {
      signOut = await self.signOut(of: origin)
    }
    do {
      try session.forget(origin)
    } catch {
      let failure =
        "This phone could not remove everything kept for \(origin): \(error.localizedDescription)"
      notice = failure
      refreshForgettable()
      return failure
    }
    notice = KeptText.forgotten(origin) + (signOut.map(Self.sessionLeftOpen) ?? "")
    if session.state == .noServer {
      serverText = Self.emptyServerText(session)
      serverProblem = nil
      restart(at: .email)
    }
    refreshForgettable()
    return nil
  }

  // MARK: - Signing out

  /// Signs out of `origin` on its server, waiting no longer than ``signOutWait`` and only until
  /// ``stopWaiting()``. A sign-out left behind is cancelled: one that had not yet reached the
  /// server leaves the session open there, and on the phone unless it is forgotten.
  public func signOut(of origin: ServerOrigin) async -> SignOutResult {
    guard signingOut == nil else { return .failed(Self.stillSigningOut) }
    notice = nil
    signingOut = origin
    defer { signingOut = nil }
    let session = session
    let limit = waitLimit
    signOutWaits += 1
    let number = signOutWaits
    var waits: [Task<Void, Never>] = []
    let result = await withCheckedContinuation { continuation in
      signOutWaiter = (number, continuation)
      waits.append(
        Task { @MainActor in
          let result: SignOutResult
          do {
            try await session.signOut(of: origin)
            result = .signedOut
          } catch {
            let error = APIError(error)
            // A refused session is one the server already ended.
            result = error == .signedOut ? .signedOut : .failed(error.message)
          }
          self.finishSignOut(number, result)
        })
      waits.append(
        Task { @MainActor in
          guard (try? await Task.sleep(for: limit)) != nil else { return }
          self.finishSignOut(number, .timedOut)
        })
    }
    for wait in waits { wait.cancel() }
    return result
  }

  /// Ends the wait for a sign-out now, as ``SignOutResult/stopped``.
  public func stopWaiting() {
    guard let waiter = signOutWaiter else { return }
    finishSignOut(waiter.number, .stopped)
  }

  private func finishSignOut(_ number: Int, _ result: SignOutResult) {
    guard let waiter = signOutWaiter, waiter.number == number else { return }
    signOutWaiter = nil
    waiter.continuation.resume(returning: result)
  }

  private static let stillSigningOut = "A sign-out is still being waited for."

  /// What a *Forget* adds about the server's own session when it could not end it.
  private static func sessionLeftOpen(_ signOut: SignOutResult) -> String {
    switch signOut {
    case .signedOut:
      ""
    case .failed(let reason):
      " Signing out on the server failed (\(reason)), so the session there stays open until it"
        + " expires."
    case .timedOut:
      " The server did not answer in time, so the session there may stay open until it"
        + " expires."
    case .stopped:
      " You stopped waiting for the server to sign out, so the session there may stay open"
        + " until it expires."
    }
  }

  // MARK: - The email screen

  public func setEmail(_ text: String) {
    email = text
    emailError = nil
  }

  public var canSendCode: Bool {
    !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRequestingCode
  }

  /// Mails a code to the address and moves on to entering it.
  public func sendCode() async {
    guard canSendCode else { return }
    let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
    notice = nil
    isRequestingCode = true
    defer { isRequestingCode = false }
    do {
      let requestID = try await session.requestCode(email: address)
      code = ""
      codeError = nil
      resendMessage = nil
      codeSentAt = now()
      chosenStep = .code(email: address, requestID: requestID)
    } catch {
      emailError = APIError(error).message
    }
  }

  // MARK: - The code screen

  /// Keeps the digits of what was typed or pasted, up to six. Ignored while a code is being
  /// checked, as the web's field drops keystrokes then.
  public func setCode(_ text: String) {
    guard !isVerifying else { return }
    code = String(text.filter { ("0"..."9").contains($0) }.prefix(Self.codeLength))
  }

  /// The field submits itself on the sixth digit; this is the only gate on a short code.
  public var isCodeComplete: Bool { code.count == Self.codeLength }

  /// Redeems the code. Whatever goes wrong empties the field, since it submits itself and a
  /// rejected code left in place would spend an attempt on every keystroke of the correction.
  public func submitCode() async {
    guard case .code(_, let requestID) = chosenStep, isCodeComplete, !isVerifying else { return }
    isVerifying = true
    codeError = nil
    defer { isVerifying = false }
    do {
      switch try await session.verifyCode(requestID: requestID, code: code) {
      case .signedIn:
        email = ""
        restart(at: .email)
      case .onboardingRequired(let email, let name):
        chosenStep = .onboardingRequired(email: email, name: name)
      case .deletionPending(let email, let purgeAfter):
        chosenStep = .deletionPending(email: email, purgeAfter: purgeAfter.map(Self.day))
      }
    } catch {
      codeError = Self.codeErrorMessage(APIError(error))
    }
    code = ""
  }

  /// Seconds until *Resend* is offered, at `date`.
  public func resendSecondsLeft(at date: Date) -> Int {
    guard let codeSentAt else { return 0 }
    let left = Self.resendCooldown - date.timeIntervalSince(codeSentAt)
    return max(0, Int(left.rounded(.up)))
  }

  public func resendLabel(at date: Date) -> String {
    if isResending { return "Resending…" }
    let left = resendSecondsLeft(at: date)
    return left > 0 ? "Resend code in \(left)s" : "Resend code"
  }

  /// Mails a new code to the same address, once the cooldown is over.
  public func resendCode() async {
    guard case .code(let address, _) = chosenStep, !isResending,
      resendSecondsLeft(at: now()) == 0
    else { return }
    isResending = true
    resendMessage = nil
    codeError = nil
    defer { isResending = false }
    do {
      let requestID = try await session.requestCode(email: address)
      code = ""
      codeSentAt = now()
      chosenStep = .code(email: address, requestID: requestID)
      resendMessage = "Code resent — check your email."
    } catch {
      codeError = APIError(error).message
    }
  }

  /// Back to the email screen, from the code or from an outcome that was not a sign-in.
  public func useDifferentEmail() {
    restart(at: .email)
  }

  // MARK: - Internals

  private func restart(at step: Step) {
    code = ""
    codeError = nil
    resendMessage = nil
    codeSentAt = nil
    emailError = nil
    chosenStep = step
  }

  private func refreshForgettable() {
    forgettableOrigin = ServerOrigin(serverText).flatMap { session.hasState($0) ? $0 : nil }
  }

  /// The flagship's address for a phone with no server saved; empty beside a list to pick from.
  private static func emptyServerText(_ session: Session) -> String {
    session.savedServers.isEmpty ? defaultServer : ""
  }

  private static func codeErrorMessage(_ error: APIError) -> String {
    switch error {
    case .http(_, let message?):
      return message
    case .unreachable:
      return error.message
    default:
      // Not "that code is wrong": the code may be fine, and saying otherwise sends the diver
      // off to request another email for nothing.
      return "Couldn't check that code. Please try again."
    }
  }

  private static func day(_ timestamp: DiveTimestamp) -> String {
    timestamp.instant.map { DateText.date($0) } ?? DateText.diveDate(timestamp)
  }
}
