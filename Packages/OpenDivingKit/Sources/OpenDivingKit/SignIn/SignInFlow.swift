import Foundation
import Observation

/// The signed-out screens: choosing a server, an email, the code or the link — or a passkey,
/// where the build is associated with the server — what redeeming any of them led to — the
/// sign-up for an address with no account among it — and the goodbye after an account is
/// deleted. The root holds one for the app's life, so that the
/// servers screen Settings and the sign-in push reads the same state, and a *Forget* or a
/// deletion can report what it did on the screen that follows it.
@MainActor
@Observable
public final class SignInFlow {
  public enum Step: Hashable, Sendable {
    case server
    case email
    case code(email: String, requestID: UUID)
    /// The address has no account: the sign-up screen, with the name the outcome carried.
    case onboardingRequired(email: String?, name: String?)
    /// `purgeAfter` is the day the account stops being recoverable, ready to print.
    case deletionPending(email: String?, purgeAfter: String?)
    /// The account was just deleted from this phone, and is recoverable by signing in until
    /// `purgeAfter`, ready to print.
    case accountDeleted(purgeAfter: String)
  }

  /// What the sign-in screens say of a held connect link.
  public enum Invitation: Hashable, Sendable {
    /// Its owner has not been read yet.
    case reading
    case from(name: String, picture: ConnectedPicture?)
    /// The link was reset or removed, and is no longer held.
    case gone
  }

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

  /// The sign-up screen's offer, in memory only and only while it shows.
  private var onboardingOffer: OnboardingOffer?
  public private(set) var signUpName = ""
  public private(set) var signUpUsername = ""
  public private(set) var isSigningUp = false
  /// Why the last *Finish setting up* created nothing, until the next.
  public private(set) var signUpError: String?

  public private(set) var isRedeemingLink = false
  /// Why the last sign-in link signed nobody in, until it is dismissed or the next.
  public private(set) var linkError: String?

  /// A record or a connect link from outside, for the server it was received on, held while the
  /// diver signs in there; in memory only, so a relaunch forgets it, since a connect link's
  /// token is a credential.
  @ObservationIgnored private var held: (origin: ServerOrigin, screen: AppLink.Screen)?
  /// Who the held connect link is from, for the sign-in screens to say, and for which server.
  public private(set) var invitation: Invitation?
  @ObservationIgnored private var invitationOrigin: ServerOrigin?
  @ObservationIgnored private var isReadingInvitation = false

  public private(set) var isSigningInWithPasskey = false
  /// Why the last *Sign in with a passkey* signed nobody in, until the next or the email.
  public private(set) var passkeyError: String?
  /// The servers the sheet on arrival was asked for in this launch, once each.
  @ObservationIgnored private var arrivals: Set<ServerOrigin> = []
  /// The sheet on arrival's request while it is out, numbered so that a dropped one's answer
  /// is ignored.
  @ObservationIgnored private var arrival: Int?
  @ObservationIgnored private var arrivalCount = 0

  /// The deletion-pending outcome's offer, in memory only and only while it shows.
  private var restoreOffer: RestoreOffer?
  public private(set) var isRestoring = false
  /// Why the last *Restore* brought nothing back, until the next.
  public private(set) var restoreError: String?

  /// `signOutWait` stands in for ``signOutWait`` in a test.
  public init(
    session: Session, now: @escaping () -> Date = { Date() },
    signOutWait: Duration = SignInFlow.signOutWait
  ) {
    self.session = session
    self.now = now
    waitLimit = signOutWait
    serverText = ""
    refreshForgettable()
  }

  /// The screen to show. With no server active it is always the server screen.
  public var step: Step {
    session.state == .noServer ? .server : chosenStep
  }

  /// Exactly what the sign-in screen offers besides signing in: everything while a server is
  /// active — the dive form and the pending screen only once an account has loaded there,
  /// since they are that account's — and nothing on the server screen with none.
  public var signedOutEntries: [SignedOutEntry] {
    guard case .signingIn(let origin) = session.state else { return [] }
    let hasAccount = session.store.lastAccount(for: origin) != nil
    return SignedOutEntry.allCases.filter { entry in
      switch entry {
      case .logDive, .waitingToSync: hasAccount
      case .checkInSheet: true
      }
    }
  }

  /// The active server, while signing in to it.
  public var origin: ServerOrigin? { session.state.origin }

  // MARK: - The servers screen

  /// The saved servers and the flagship, saved or not, each with whether the phone is signed in
  /// there: the active one first, then the rest by when each was last used, most recent first.
  /// A server no build has marked used goes last, in the order it was saved.
  public var savedServers: [SavedServer] {
    let active = session.state.origin
    var origins = session.savedServers
    if !origins.contains(.flagship) { origins.append(.flagship) }
    let ranked = origins.enumerated().map { index, origin in
      (index: index, origin: origin, used: session.store.lastUsed(origin))
    }
    let ordered = ranked.sorted { a, b in
      if (a.origin == active) != (b.origin == active) { return a.origin == active }
      switch (a.used, b.used) {
      case (let x?, let y?) where x != y: return x > y
      case (.some, nil): return true
      case (nil, .some): return false
      default: return a.index < b.index
      }
    }
    return ordered.map(\.origin).map { origin in
      let status: String
      if session.isSignedIn(to: origin) {
        status = session.account(on: origin).map { "Signed in as \($0.email)" } ?? "Signed in"
      } else {
        status = "Signed out"
      }
      return SavedServer(origin: origin, isActive: origin == active, status: status)
    }
  }

  public func setServerText(_ text: String) {
    serverText = text
    serverProblem = nil
    refreshForgettable()
  }

  /// Asks the typed server whether it is an OpenDiving instance and, when it is, points the
  /// app at it and saves it. Every other server keeps its session and its state. Answers
  /// whether it is now the active server, which leaves the screen that asked with nothing to do.
  @discardableResult
  public func continueToServer() async -> Bool {
    guard !isValidating else { return false }
    notice = nil
    guard let origin = ServerOrigin(serverText) else {
      serverProblem = .unreadableAddress
      return false
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
      refreshForgettable()
      return true
    } catch is CancellationError {
      // The app left the server being asked; nothing about it is worth a line.
      return false
    } catch {
      serverProblem = ServerProblem(APIError(error), origin: origin)
      refreshForgettable()
      return false
    }
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
    // Deliberate, and the owner's call: the flagship offers no Forget, though the list would
    // show it again anyway. What the phone keeps for it outlives a sign-out.
    guard !origin.isFlagship else { return Self.flagshipStays }
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
    // A Forget that worked says nothing; only a session it could not end is worth a line.
    notice = signOut.flatMap(Self.sessionLeftOpen)
    if session.state == .noServer {
      serverText = ""
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
          // The diver's own sign-out, the one a session the server had already ended counts
          // as: the passkey sheet stays down there until a sign-in.
          if result == .signedOut { try? session.store.setDiverSignedOut(true, for: origin) }
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
  private static let flagshipStays = "\(ServerOrigin.flagship) stays on this phone's list."

  /// What a *Forget* adds about the server's own session when it could not end it.
  private static func sessionLeftOpen(_ signOut: SignOutResult) -> String? {
    switch signOut {
    case .signedOut:
      nil
    case .failed(let reason):
      "Signing out on the server failed (\(reason)), so the session there stays open until it"
        + " expires."
    case .timedOut:
      "The server did not answer in time, so the session there may stay open until it expires."
    case .stopped:
      "You stopped waiting for the server to sign out, so the session there may stay open until"
        + " it expires."
    }
  }

  // MARK: - The email screen

  public func setEmail(_ text: String) {
    dropPasskeyArrival()
    email = text
    emailError = nil
    passkeyError = nil
  }

  public var isEmailEmpty: Bool {
    email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Mails a code to the address and moves on to entering it.
  public func sendCode() async {
    dropPasskeyArrival()
    guard !isEmailEmpty, !isRequestingCode, !isSigningInWithPasskey else { return }
    passkeyError = nil
    let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
    notice = nil
    isRequestingCode = true
    defer { isRequestingCode = false }
    do {
      let requestID = try await requestCode(address)
      code = ""
      codeError = nil
      resendMessage = nil
      codeSentAt = now()
      chosenStep = .code(email: address, requestID: requestID)
    } catch is CancellationError {
      // The server was left while it was asked; its screen has started over.
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
      take(try await session.verifyCode(requestID: requestID, code: code))
    } catch is CancellationError {
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
      let requestID = try await requestCode(address)
      code = ""
      codeSentAt = now()
      chosenStep = .code(email: address, requestID: requestID)
      resendMessage = "Code resent — check your email."
    } catch is CancellationError {
    } catch {
      codeError = APIError(error).message
    }
  }

  /// Back to the email screen, from the code, from an outcome that was not a sign-in, or from
  /// the goodbye.
  public func useDifferentEmail() {
    restart(at: .email)
  }

  // MARK: - A sign-in link

  /// Redeems a sign-in link's token, from whichever sign-in screen shows, and goes on as a code
  /// does. A refusal is the API's sentence, in ``linkError``, and keeps the screen.
  public func redeemLink(_ token: String) async {
    guard !isRedeemingLink else { return }
    dropPasskeyArrival()
    isRedeemingLink = true
    linkError = nil
    defer { isRedeemingLink = false }
    do {
      take(try await session.verifyLink(token: token))
    } catch is CancellationError {
    } catch {
      linkError = APIError(error).message
    }
  }

  public func dismissLinkError() {
    linkError = nil
  }

  public static let linkFailedTitle = "This sign-in link didn't work"
  public static let redeemingLink = "Signing in…"

  // MARK: - A link held while signed out

  /// Holds a record or a connect link from outside while the diver signs in on the server the
  /// app is on, replacing one held before, and reads whose a connect link is for the sign-in
  /// screens.
  public func hold(_ screen: AppLink.Screen) async {
    guard let origin = session.state.origin else { return }
    held = (origin, screen)
    invitationOrigin = origin
    guard case .connect = screen else {
      invitation = nil
      return
    }
    invitation = .reading
    await readInvitation()
  }

  /// Switches to the flagship for a connect link on it, the diver having chosen to: its screen
  /// comes back to open where the phone is signed in there, and is held while the diver signs in
  /// where it is not. Nil too while a sign-out keeps the app where it is.
  public func switchToFlagship(_ offer: FlagshipOffer) async -> AppLink.Screen? {
    switchTo(.flagship)
    switch session.state {
    case .signedIn(let origin) where origin.isFlagship:
      return offer.screen
    case .signingIn(let origin) where origin.isFlagship:
      // Held before the root reads the state that follows the switch, which would drop it.
      await hold(offer.screen)
      return nil
    default:
      return nil
    }
  }

  /// Reads whose the held connect link is, while it has not been read: a link that is no longer
  /// active is dropped and said to be, and a read that fails is tried again by the next call.
  public func readInvitation() async {
    guard invitation == .reading, !isReadingInvitation, let held,
      case .connect(let token) = held.screen, held.origin == session.state.origin
    else { return }
    isReadingInvitation = true
    let owner: ConnectLinkOwner?
    do {
      owner = try await session.requireClient().anonymousConnectLinkOwner(token)
    } catch {
      // Held still, and the token still goes with the email; the screens say nothing of it.
      isReadingInvitation = false
      return
    }
    isReadingInvitation = false
    guard self.held?.screen == .connect(token: token), invitation == .reading else {
      // Another link was held while this one was read.
      await readInvitation()
      return
    }
    if let owner {
      invitation = .from(name: owner.name, picture: .of(owner, token: token))
    } else {
      self.held = nil
      invitation = .gone
    }
  }

  /// The held link's screen, once `state` is signed in on its server, which then holds nothing.
  /// A state on any other server, or on none, drops what is held.
  public func takeHeldScreen(_ state: Session.State) -> AppLink.Screen? {
    if let origin = held?.origin ?? invitationOrigin, state.origin != origin {
      dropHeld()
      return nil
    }
    guard case .signedIn = state else { return nil }
    let screen = held?.screen
    dropHeld()
    return screen
  }

  public static func invitationTitle(_ name: String) -> String {
    "\(name) invited you to connect on OpenDiving"
  }

  /// The line under it, in the web's words: the project's voice only where the server says the
  /// project runs it.
  public func invitationNote(_ name: String) -> String {
    let start =
      session.server?.config.projectOperated == true
      ? "Enter your email to sign in, or to join the OpenDiving beta."
      : "Enter your email to sign in, or to create your account."
    return start + " A new account starts with \(name) in its people, and \(name) sees its name,"
      + " username and picture."
  }

  public static let invitationGone =
    "The connect link you opened is no longer active. Ask whoever gave it to you for their new one."

  /// `POST /auth/email/request`, carrying the held connect link's token. An invite-only server
  /// refuses the email outright for a token that names no live link, account or not, so a
  /// refusal while one is carried reads the link again, and a link found gone is dropped and the
  /// email asked for without it.
  private func requestCode(_ address: String) async throws -> UUID {
    guard let via = heldConnectToken, let origin = session.state.origin else {
      return try await session.requestCode(email: address)
    }
    do {
      return try await session.requestCode(email: address, via: via)
    } catch let error where Self.isForbidden(error) {
      let before = invitation
      invitation = .reading
      await readInvitation()
      // The server was left while the link was read; its screen has started over.
      guard session.state.origin == origin else { throw CancellationError() }
      guard invitation == .gone else {
        if invitation == .reading, heldConnectToken == via { invitation = before }
        throw error
      }
      return try await session.requestCode(email: address)
    }
  }

  private static func isForbidden(_ error: any Error) -> Bool {
    if case .http(status: 403, _) = APIError(error) { true } else { false }
  }

  private var heldConnectToken: String? {
    guard let held, held.origin == session.state.origin, case .connect(let token) = held.screen
    else { return nil }
    return token
  }

  private func dropHeld() {
    held = nil
    invitation = nil
    invitationOrigin = nil
  }

  // MARK: - Signing up

  public func setSignUpName(_ text: String) {
    signUpName = text
    signUpError = nil
  }

  public func setSignUpUsername(_ text: String) {
    signUpUsername = text
    signUpError = nil
  }

  /// Why `field` as typed would be refused, once something is typed in it.
  public func signUpProblem(_ field: AccountFieldModel.Field) -> String? {
    let text = signUpText(field)
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? nil : field.problem(text)
  }

  public var canSignUp: Bool {
    onboardingOffer != nil && !isSigningUp
      && [.name, .username].allSatisfy { (field: AccountFieldModel.Field) in
        field.problem(signUpText(field)) == nil
      }
  }

  /// Creates the account and signs in to it. A taken username and the registration gate's
  /// refusal are the API's sentence on the screen; an onboarding token that expired leads back
  /// to the email, with the API's sentence there, since only a new sign-in mints another.
  public func signUp() async {
    guard canSignUp, case .onboardingRequired(let address, _) = chosenStep,
      let offer = onboardingOffer
    else { return }
    isSigningUp = true
    signUpError = nil
    defer { isSigningUp = false }
    do {
      try await session.completeSignUp(
        offer, name: signUpName.trimmingCharacters(in: .whitespacesAndNewlines),
        username: signUpUsername.trimmingCharacters(in: .whitespacesAndNewlines))
      email = ""
      restart(at: .email)
    } catch is CancellationError {
    } catch {
      let error = APIError(error)
      if case .http(status: 401, _) = error {
        restart(at: .email)
        if let address { email = address }
        emailError = error.message
      } else {
        signUpError = error.message
      }
    }
  }

  /// The sign-up screen's sentence on the terms, in the web's words, each document linked on the
  /// server's web, `url` nil for the words between them.
  public static func signUpTerms(_ origin: ServerOrigin) -> [(text: String, url: URL?)] {
    [
      ("By creating an account, you agree to our ", nil),
      ("Terms of Service", origin.url.appendingPathComponent("terms")),
      (" and ", nil),
      ("Privacy Policy", origin.url.appendingPathComponent("privacy")),
    ]
  }

  public static let signUpTitle = "Complete Your Profile"
  public static let signUpNote = "Just a couple more details and you're in."
  public static let signUpButton = "Finish setting up"
  public static let signingUp = "Creating your account…"

  private func signUpText(_ field: AccountFieldModel.Field) -> String {
    switch field {
    case .name: signUpName
    case .username: signUpUsername
    }
  }

  // MARK: - Deleting and restoring

  /// Whether the deletion-pending outcome showing can offer *Restore*.
  public var canRestore: Bool {
    guard case .deletionPending = chosenStep else { return false }
    return restoreOffer != nil
  }

  /// Redeems the deletion-pending outcome's offer and goes on as an authenticated code does:
  /// signed in, the account loading. A refusal shows the API's sentence and keeps the screen.
  public func restore() async {
    guard canRestore, let offer = restoreOffer, !isRestoring else { return }
    isRestoring = true
    restoreError = nil
    defer { isRestoring = false }
    do {
      try await session.restore(offer)
      email = ""
      restart(at: .email)
    } catch is CancellationError {
    } catch {
      restoreError = APIError(error).message
    }
  }

  /// Deletes the account signed in on the active server and shows the goodbye, which names the
  /// day the answer gives. With no route nothing is sent; a failure, thrown, changes nothing.
  public func deleteAccount() async throws {
    let origin = session.state.origin
    let deletion = try await session.deleteAccount()
    if let origin { try? session.store.setDiverSignedOut(true, for: origin) }
    restart(at: .accountDeleted(purgeAfter: Self.day(deletion.purgeAfter)))
  }

  // MARK: - A passkey

  /// Whether the email screen offers a passkey: where the build is associated with the server.
  public var offersPasskey: Bool { session.offersPasskeys }

  public static let passkeyButton = "Sign in with a passkey"
  public static let passkeyFailed = "Couldn't sign in with that passkey. Please try again."

  /// *Sign in with a passkey*: any passkey for the server, on the phone or on a device nearby.
  /// A dismissed sheet says nothing; a refusal says the API's sentence where it gave one, and
  /// ``passkeyFailed`` where it did not.
  public func signInWithPasskey() async {
    dropPasskeyArrival()
    guard offersPasskey, !isSigningInWithPasskey, !isRequestingCode,
      let origin = session.state.origin
    else { return }
    isSigningInWithPasskey = true
    passkeyError = nil
    emailError = nil
    defer { isSigningInWithPasskey = false }
    let answer = await passkeySignIn(onlyOnThisPhone: false) { session.state.origin == origin }
    switch answer {
    case .outcome(let outcome): take(outcome)
    case .refused(let sentence): passkeyError = sentence
    case .dismissed, nil: break
    }
  }

  /// The sheet on arrival: as the email screen comes into view where a passkey is offered, the
  /// system is asked for a passkey the phone holds, so that its sheet shows by itself when the
  /// phone holds one and nothing shows when it holds none. Once a launch for a server, never
  /// while the diver's own sign-out stands there or a sign-in link is being redeemed, and
  /// nothing it ends in is ever said.
  public func arriveAtEmail() async {
    guard step == .email, case .signingIn(let origin) = session.state, offersPasskey,
      !arrivals.contains(origin), !session.store.diverSignedOut(origin), !isRedeemingLink,
      !isSigningInWithPasskey, !isRequestingCode
    else { return }
    arrivals.insert(origin)
    arrivalCount += 1
    let number = arrivalCount
    arrival = number
    let answer = await passkeySignIn(onlyOnThisPhone: true) {
      arrival == number && session.state.origin == origin && !isRedeemingLink
    }
    if arrival == number { arrival = nil }
    if case .outcome(let outcome) = answer { take(outcome) }
  }

  /// Drops the sheet on arrival, its answer ignored: the diver typed, or tapped a control.
  public func dropPasskeyArrival() {
    guard arrival != nil else { return }
    arrival = nil
    session.passkeyCeremony?.cancel()
  }

  private enum PasskeyAnswer {
    case outcome(Session.SignInOutcome)
    case dismissed
    case refused(String)
  }

  /// The options, the system's sheet and the verification; nil once `stillWanted` says the
  /// answer is not, at either wait.
  private func passkeySignIn(onlyOnThisPhone: Bool, stillWanted: () -> Bool) async
    -> PasskeyAnswer?
  {
    guard let ceremony = session.passkeyCeremony else { return .refused(Self.passkeyFailed) }
    do {
      let options = try await session.passkeySignInOptions()
      guard stillWanted() else { return nil }
      guard let request = options.request(onlyOnThisPhone: onlyOnThisPhone) else {
        return .refused(Self.passkeyFailed)
      }
      let result = await ceremony.signIn(request)
      guard stillWanted() else { return nil }
      switch result {
      case .done(let assertion):
        return .outcome(
          try await session.verifyPasskey(
            flowID: options.flowId, credential: PasskeyCredential(assertion)))
      case .dismissed, .matchedExcludedCredential:
        return .dismissed
      case .failed:
        return .refused(Self.passkeyFailed)
      }
    } catch is CancellationError {
      return nil
    } catch {
      guard case .http(_, let message?) = APIError(error) else {
        return .refused(Self.passkeyFailed)
      }
      return .refused(message)
    }
  }

  // MARK: - Internals

  /// Where redeeming a code or a link leads.
  private func take(_ outcome: Session.SignInOutcome) {
    switch outcome {
    case .signedIn:
      email = ""
      restart(at: .email)
    case .onboardingRequired(let email, let name, let offer):
      restart(at: .onboardingRequired(email: email, name: name))
      onboardingOffer = offer
      signUpName = name ?? ""
    case .deletionPending(let email, let purgeAfter, let offer):
      restart(at: .deletionPending(email: email, purgeAfter: purgeAfter.map(Self.day)))
      restoreOffer = offer
    }
  }

  private func restart(at step: Step) {
    code = ""
    codeError = nil
    resendMessage = nil
    codeSentAt = nil
    emailError = nil
    passkeyError = nil
    restoreOffer = nil
    restoreError = nil
    onboardingOffer = nil
    signUpName = ""
    signUpUsername = ""
    signUpError = nil
    chosenStep = step
  }

  private func refreshForgettable() {
    forgettableOrigin = ServerOrigin(serverText).flatMap {
      !$0.isFlagship && session.hasState($0) ? $0 : nil
    }
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

  /// Always the date: it is printed after *on*, where `today` would not read.
  private static func day(_ timestamp: DiveTimestamp) -> String {
    timestamp.instant.map { DateText.date($0, relativeTo: nil) }
      ?? DateText.diveDate(timestamp, relativeTo: nil)
  }
}
