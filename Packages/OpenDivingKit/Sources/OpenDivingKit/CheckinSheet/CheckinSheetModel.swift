import Foundation
import Observation

/// What the Cards view shows: the active server's cached sheet, refreshed on every signed-in
/// visit. Signed out it reads the cache and nothing else — it depends on the session only
/// for which server is active and whether a refresh may run.
@MainActor
@Observable
public final class CheckinSheetModel {
  public private(set) var sheet: CheckinSheet?
  public private(set) var isRefreshing = false
  /// Why the last refresh failed, shown beside the *last updated* line; nil once one lands.
  public private(set) var refreshError: String?

  @ObservationIgnored private let session: Session

  public init(session: Session) {
    self.session = session
  }

  /// Whether a refresh can run; signed out, the view offers *Sign in to refresh* instead.
  public var isSignedIn: Bool {
    if case .signedIn = session.state { true } else { false }
  }

  public var content: CheckinSheetContent? {
    sheet.map { CheckinSheetContent($0, today: Self.today()) }
  }

  /// Reads the cached sheet of the active server.
  public func load() {
    sheet = store?.load()
  }

  /// Refreshes the sheet when signed in, keeping the cached one whole on any failure.
  public func refresh() async {
    guard isSignedIn, !isRefreshing, let store else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    do {
      sheet = try await store.refresh(with: session)
      refreshError = nil
    } catch let error as APIError {
      refreshError = error.message
    } catch {
      refreshError = String(describing: error)
    }
  }

  /// A cached picture's bytes.
  public func data(for file: CheckinSheetFile) -> Data? {
    store?.data(for: file)
  }

  private var store: CheckinSheetStore? {
    session.state.origin.map { CheckinSheetStore(store: session.store, origin: $0) }
  }

  /// The phone's own calendar day, which is what a card's expiry is read against.
  private static func today() -> CalendarDate {
    let parts = Calendar(identifier: .gregorian).dateComponents(
      in: .current, from: Date())
    // Every component is present for a Gregorian calendar asked for them.
    return CalendarDate(year: parts.year!, month: parts.month!, day: parts.day!)!
  }
}
