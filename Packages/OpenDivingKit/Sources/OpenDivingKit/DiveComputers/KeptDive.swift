import Foundation

/// One dive of a walk as the phone keeps it from the moment it arrives until an archive holds
/// it: what rebuilds the ``DownloadedDive``. Its bytes and its reading are files of their own
/// beside the walk's record, which so stays a list of names however long the walk.
struct KeptDive: Codable, Hashable, Sendable {
  enum Reading: Codable, Hashable, Sendable {
    /// The reader's dive object, and the fallback start it was read with.
    case dive(json: String, fallbackStart: Date?)
    case refused(start: KeptStart?)
  }

  var identity: DiveComputerIdentity
  /// libdivecomputer's fingerprint, in hex.
  var fingerprint: String
  /// The bytes' file, inside the walk's folder; the reading's is ``readingFile``.
  var file: String

  var readingFile: String { file + ".reading.json" }

  init(_ dive: DownloadedDive, file: String) {
    identity = dive.identity
    fingerprint = Hex.lowercase(dive.fingerprint)
    self.file = file
  }

  /// What the parser made of the dive, as its reading's file holds it.
  static func reading(of dive: DownloadedDive) -> Reading {
    switch dive.reading {
    case .dive(let read):
      .dive(json: String(decoding: read.json, as: UTF8.self), fallbackStart: read.fallbackStart)
    case .refused(let start):
      .refused(start: start.map(KeptStart.init))
    }
  }

  /// Writes the dive's bytes and its reading into `folder`.
  func write(_ dive: DownloadedDive, into folder: URL) throws {
    try dive.bytes.write(to: folder.appendingPathComponent(file), options: .atomic)
    try JSONEncoder().encode(Self.reading(of: dive)).write(
      to: folder.appendingPathComponent(readingFile), options: .atomic)
  }

  /// Removes the dive's files from `folder`.
  func remove(from folder: URL) {
    try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
    try? FileManager.default.removeItem(at: folder.appendingPathComponent(readingFile))
  }

  /// The dive again, read from `folder`; nil where its files are gone or no longer read.
  func downloaded(in folder: URL) -> DownloadedDive? {
    guard let bytes = try? Data(contentsOf: folder.appendingPathComponent(file)),
      let stored = try? Data(contentsOf: folder.appendingPathComponent(readingFile)),
      let reading = try? JSONDecoder().decode(Reading.self, from: stored),
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
