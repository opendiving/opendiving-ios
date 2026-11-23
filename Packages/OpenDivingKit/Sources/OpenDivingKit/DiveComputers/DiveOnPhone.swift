import Foundation

/// A downloaded dive of the account dives are kept for, on the phone and not yet answered for by
/// the server: in an archive, held for a time zone, or kept by the walk in flight
/// (``DiveComputerEngine/divesOnPhone``).
public struct DiveOnPhone: Hashable, Sendable, Identifiable {
  /// Why the dive is not on its way to the server now.
  public enum Wait: Hashable, Sendable {
    /// Nothing: it goes with the next upload, or is going now.
    case nothing
    /// No route to the server.
    case route
    /// Nobody is signed in to the account it is kept for.
    case signIn
    /// *Which time zone were these dives in?*: its start is an instant with no zone to write it
    /// in yet.
    case timeZone
    /// *Which computer comes first?*: its computer was paired beside one other.
    case order
    /// The server refused its archive, which is not sent again by itself.
    case refused
  }

  /// The uuid it is imported under.
  public let id: UUID
  /// *Shearwater Perdix 3*.
  public let computer: String
  /// What the computer's list said of it; nil where it said nothing, or an earlier build kept it.
  public let facts: ListedDiveFacts?
  /// The zone its watch reported, for showing an instant with no offset while a walk keeps it.
  public let watchZone: TimeZone?
  public let wait: Wait
  /// The archive that holds it; nil while a walk keeps it.
  public let archive: UUID?
}
