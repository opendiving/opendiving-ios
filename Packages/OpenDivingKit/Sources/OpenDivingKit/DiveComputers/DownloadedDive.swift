import Foundation

/// One dive off a computer: its original bytes, libdivecomputer's fingerprint for it, what the
/// parser made of the bytes, and what the computer's list said of it before it was read.
public struct DownloadedDive: Hashable, Sendable {
  /// What the parser made of a dive's bytes.
  public enum Reading: Hashable, Sendable {
    case dive(ComputerDive)
    /// The parser could not read the bytes. They are kept in the archive as a member its
    /// document does not name, under the dive's start where one is known — for a Nautic, from
    /// its fingerprint — and under the fingerprint otherwise.
    case refused(start: ComputerDive.Start?)
  }

  public let identity: DiveComputerIdentity
  public let fingerprint: Data
  public let bytes: Data
  public let reading: Reading
  /// Nil for a family that lists nothing before it reads, and for a dive an earlier build kept.
  public let facts: ListedDiveFacts?

  public init(
    identity: DiveComputerIdentity, fingerprint: Data, bytes: Data, reading: Reading,
    facts: ListedDiveFacts? = nil
  ) {
    self.identity = identity
    self.fingerprint = fingerprint
    self.bytes = bytes
    self.reading = reading
    self.facts = facts
  }

  /// The uuid the dive is imported under.
  var uuid: UUID { DiveComputerArchive.diveUUID(identity, fingerprint: fingerprint) }

  public var dive: ComputerDive? {
    if case .dive(let dive) = reading { return dive }
    return nil
  }

  /// The zone the computer logged the dive in, for a family that reports the start as an
  /// instant and keeps its offset in the bytes.
  var loggedZone: TimeZone? {
    guard case .instant(let instant)? = start else { return nil }
    return NauticLoggedZone.zone(in: bytes, at: instant)
  }

  var start: ComputerDive.Start? {
    switch reading {
    case .dive(let dive): dive.start
    case .refused(let start): start
    }
  }
}
