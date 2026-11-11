import Foundation
import Observation

/// *Authentication*'s signed-in devices: this phone's session first, marked and with no
/// control — ending it is what *Sign out* does — then every other in the server's
/// most-recently-used order, each signed out after a confirmation, and all of them at once.
/// Direct calls, online only.
@MainActor
@Observable
public final class SignedInDevicesModel {
  public let list: OptionalList<[UserSessionRead]>
  /// The device waiting for the diver to confirm its sign-out.
  public var confirmingSignOut: UserSessionRead?
  public var confirmingSignOutOthers = false
  public private(set) var signingOut: UUID?
  public private(set) var isSigningOutOthers = false
  /// Why the last sign-out failed.
  public private(set) var failure: String?
  /// How many devices *Sign out other sessions* signed out, as the server counted them.
  public private(set) var outcome: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
    list = OptionalList(session: session) { try await $0.userSessions() }
  }

  /// This phone's session first; the rest keep the server's order.
  public var rows: [UserSessionRead] {
    let sessions = list.value ?? []
    return sessions.filter(\.current) + sessions.filter { !$0.current }
  }

  /// Whether a device other than this phone is signed in.
  public var hasOthers: Bool { rows.contains { !$0.current } }

  public var isBusy: Bool { signingOut != nil || isSigningOutOthers }

  /// Signs `device` out, the one the confirmation named. It is handed in rather than read from
  /// ``confirmingSignOut``, which the dialog clears as it closes, before this runs.
  public func confirmSignOut(_ device: UserSessionRead) async {
    guard !device.current, !isBusy else { return }
    confirmingSignOut = nil
    failure = nil
    outcome = nil
    signingOut = device.uuid
    defer { signingOut = nil }
    do {
      try await session.routedClient().revokeUserSession(device.uuid)
    } catch {
      failure = APIError(error).message
      return
    }
    await list.load()
  }

  /// Signs every device but this phone out.
  public func confirmSignOutOthers() async {
    guard !isBusy else { return }
    confirmingSignOutOthers = false
    failure = nil
    outcome = nil
    isSigningOutOthers = true
    defer { isSigningOutOthers = false }
    do {
      let revoked = try await session.routedClient().revokeOtherUserSessions()
      outcome = Self.signedOut(revoked.revoked)
    } catch {
      failure = APIError(error).message
      return
    }
    await list.load()
  }

  // MARK: - What the block says

  public static let description =
    "Every browser and app currently signed in to your account. Sign one out if you do not"
    + " recognise it, or if you left yourself signed in somewhere."
  public static let empty =
    "Nothing is signed in right now, including this phone. It will be signed out the next time"
    + " it checks in."
  public static let thisDevice = "This device"
  public static let staysSignedInLonger = "Stays signed in longer"
  public static let loadFailed = "Couldn't load your signed-in devices."
  public static let signOutOthersButton = "Sign out other sessions"
  public static let signOutTitle = "Sign this device out"
  public static let signOutButton = "Sign out"
  public static let signOutOthersMessage =
    "Every other browser and app will have to sign in again. This one stays signed in. Each of"
    + " them loses access immediately, on its very next request."
  public static let signOutOthersConfirm = "Sign them out"

  /// The row's name for the device.
  nonisolated public static func label(_ device: UserSessionRead) -> String {
    DeviceName.forUserAgent(device.userAgent)
  }

  /// `203.0.113.7 · Last used Nov 9, 2026, 22:14`, with the time of day: when a session was
  /// last used is the whole question for a diver deciding whether they recognise it.
  nonisolated public static func details(
    _ device: UserSessionRead, in timeZone: TimeZone = .current
  ) -> String {
    let used =
      device.lastUsedAt.instant.map { DateText.dateTime($0, in: timeZone) }
      ?? DateText.diveDateTime(device.lastUsedAt)
    return device.ip + " · Last used " + used
  }

  public static func signOutMessage(_ device: UserSessionRead) -> String {
    "\(label(device)) (\(device.ip)) will have to sign in again. It loses access immediately,"
      + " on its very next request."
  }

  nonisolated public static func signedOut(_ count: Int) -> String {
    count == 1 ? "1 other device was signed out." : "\(count) other devices were signed out."
  }
}
