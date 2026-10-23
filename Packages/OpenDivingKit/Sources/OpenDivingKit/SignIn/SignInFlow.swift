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

  public let session: Session
  @ObservationIgnored private let now: () -> Date

  private var chosenStep = Step.email

  public private(set) var serverText: String
  public private(set) var isValidating = false
  public private(set) var serverProblem: ServerProblem?
  /// The typed origin, when the phone holds something for it that forgetting would remove —
  /// offered whether or not the server answers, since forgetting needs no server.
  public private(set) var forgettableOrigin: ServerOrigin?
  /// What the last *Forget* did, shown on the signed-out screen it lands on — the server
  /// screen when it worked, the screen it started from when it did not.
  public private(set) var notice: String?

  public private(set) var email = ""
  public private(set) var isRequestingCode = false
  public private(set) var emailError: String?

  public private(set) var code = ""
  public private(set) var isVerifying = false
  public private(set) var codeError: String?
  public private(set) var isResending = false
  public private(set) var resendMessage: String?
  private var codeSentAt: Date?

  public init(session: Session, now: @escaping () -> Date = { Date() }) {
    self.session = session
    self.now = now
    serverText = session.state.origin?.description ?? Self.defaultServer
    refreshForgettable()
  }

  /// The screen to show. With no server active it is always the server screen.
  public var step: Step {
    session.state == .noServer ? .server : chosenStep
  }

  /// Exactly what the sign-in screen offers besides signing in: everything while a server is
  /// active, nothing on the server screen with none.
  public var signedOutEntries: [SignedOutEntry] {
    if case .signingIn = session.state { return SignedOutEntry.allCases }
    return []
  }

  /// The active server, while signing in to it.
  public var origin: ServerOrigin? { session.state.origin }

  // MARK: - The server screen

  public func setServerText(_ text: String) {
    serverText = text
    serverProblem = nil
    refreshForgettable()
  }

  /// Whether the server screen can go back to signing in to the server already active.
  public var canCancelServerChange: Bool { session.state != .noServer }

  /// Asks the typed server whether it is an OpenDiving instance and, when it is, points the
  /// app at it. The previous server's state stays where it is.
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
      session.select(origin, info: info)
      serverText = origin.description
      serverProblem = nil
      restart(at: .email)
    } catch {
      serverProblem = ServerProblem(APIError(error), origin: origin)
    }
    refreshForgettable()
  }

  public func useDifferentServer() {
    notice = nil
    serverProblem = nil
    if let origin { setServerText(origin.description) }
    chosenStep = .server
  }

  public func cancelServerChange() {
    guard canCancelServerChange else { return }
    notice = nil
    serverProblem = nil
    restart(at: .email)
  }

  /// Signs out of `origin` when signed in to it, then removes everything kept for it whether
  /// or not that worked — a server that is gone can never answer the sign-out, and its sheet
  /// would otherwise stay on the phone for good. A failed sign-out is reported, not a reason
  /// to stop. False when something kept for the server could not be removed, which
  /// ``notice`` then says.
  @discardableResult
  public func forget(_ origin: ServerOrigin) async -> Bool {
    var signOutFailure: String?
    if session.state == .signedIn(origin) {
      do {
        try await session.signOut()
      } catch {
        let error = APIError(error)
        // A refused session is one the server already ended.
        if error != .signedOut { signOutFailure = error.message }
      }
    }
    do {
      try session.forget(origin)
    } catch {
      notice =
        "This phone could not remove everything kept for \(origin): \(error.localizedDescription)"
      refreshForgettable()
      return false
    }
    var message =
      "Removed everything this phone kept for \(origin): its sign-in, account"
      + " and check-in sheet."
    if let signOutFailure {
      message +=
        " Signing out on the server failed (\(signOutFailure)), so the session there stays"
        + " open until it expires."
    }
    notice = message
    if session.state == .noServer {
      serverText = Self.defaultServer
      serverProblem = nil
      restart(at: .email)
    }
    refreshForgettable()
    return true
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
