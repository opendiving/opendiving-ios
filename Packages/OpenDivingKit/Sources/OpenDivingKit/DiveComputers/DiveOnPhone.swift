import Foundation

/// A downloaded dive of the account dives are kept for, on the phone and not yet answered for by
/// the server: in an archive, held for a time zone, or kept by the walk in flight
/// (``DiveComputerEngine/divesOnPhone``).
public struct DiveOnPhone: Hashable, Sendable, Identifiable {
  /// Why the dive is not on its way to the server now, from every reason the upload does not send
  /// it: the first that holds of an order's question, a refusal, nobody signed in, no route, a
  /// walk begun before the account loaded, a failed last try, in that order, and the time-zone
  /// question before them all.
  public enum Wait: Hashable, Sendable {
    /// Nothing: it goes with the next upload — the walk's next turn while one runs, or after an
    /// archive cut before it — or is going now.
    case nothing
    /// The walk in flight keeps it until it ends, nothing for the diver to do: it began before
    /// the account loaded, so its dives may yet move to the account the load names.
    case walkEnd
    /// The last try at its archive in this process met a conflict, the server's budget, an error
    /// or no answer (``DiveComputerEngine/lastTries``): it goes again at the next occasion.
    case retry
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
