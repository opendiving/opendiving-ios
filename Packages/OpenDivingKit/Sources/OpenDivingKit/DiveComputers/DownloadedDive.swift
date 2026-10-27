import Foundation

/// One dive off a computer: its original bytes, libdivecomputer's fingerprint for it, and what
/// the parser made of the bytes.
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

  public init(identity: DiveComputerIdentity, fingerprint: Data, bytes: Data, reading: Reading) {
    self.identity = identity
    self.fingerprint = fingerprint
    self.bytes = bytes
    self.reading = reading
  }

  public var dive: ComputerDive? {
    if case .dive(let dive) = reading { return dive }
    return nil
  }

  var start: ComputerDive.Start? {
    switch reading {
    case .dive(let dive): dive.start
    case .refused(let start): start
    }
  }
}
