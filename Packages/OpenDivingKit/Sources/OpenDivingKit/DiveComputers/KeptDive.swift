import Foundation

/// One dive of a walk as the phone keeps it from the moment it arrives until an archive holds
/// it: what rebuilds the ``DownloadedDive``, its bytes in a file of its own beside the walk.
struct KeptDive: Codable, Hashable, Sendable {
  enum Reading: Codable, Hashable, Sendable {
    /// The reader's dive object, and the fallback start it was read with.
    case dive(json: String, fallbackStart: Date?)
    case refused(start: KeptStart?)
  }

  var identity: DiveComputerIdentity
  /// libdivecomputer's fingerprint, in hex.
  var fingerprint: String
  /// The bytes' file, inside the walk's folder.
  var file: String
  var reading: Reading

  init(_ dive: DownloadedDive, file: String) {
    identity = dive.identity
    fingerprint = Hex.lowercase(dive.fingerprint)
    self.file = file
    switch dive.reading {
    case .dive(let read):
      reading = .dive(json: String(decoding: read.json, as: UTF8.self), fallbackStart: read.fallbackStart)
    case .refused(let start):
      reading = .refused(start: start.map(KeptStart.init))
    }
  }

  /// The dive again, its bytes read from `folder`; nil where they or its reading are gone.
  func downloaded(in folder: URL) -> DownloadedDive? {
    guard let bytes = try? Data(contentsOf: folder.appendingPathComponent(file)),
      let fingerprint = Hex.data(fingerprint)
    else { return nil }
    let read: DownloadedDive.Reading
    switch reading {
    case .dive(let json, let fallbackStart):
      guard
        let dive = ComputerDive(
          json: Data(json.utf8), logsInstants: identity.family.logsInstants,
          fallbackStart: fallbackStart)
      else { return nil }
      read = .dive(dive)
    case .refused(let start):
      read = .refused(start: start?.start)
    }
    return DownloadedDive(identity: identity, fingerprint: fingerprint, bytes: bytes, reading: read)
  }
}

/// A refused dive's start, as a ``KeptDive`` writes it.
struct KeptStart: Codable, Hashable, Sendable {
  var wallClock: DiveTimestamp?
  var utcOffsetSeconds: Int?
  var instant: Date?

  init(_ start: ComputerDive.Start) {
    switch start {
    case .wallClock(let clock, let offset):
      wallClock = .wallClock(clock)
      utcOffsetSeconds = offset
    case .instant(let instant):
      self.instant = instant
    }
  }

  var start: ComputerDive.Start? {
    if let instant { return .instant(instant) }
    guard let clock = wallClock?.wallClock else { return nil }
    return .wallClock(clock, utcOffsetSeconds: utcOffsetSeconds)
  }
}
