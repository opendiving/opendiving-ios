import Foundation

/// How far one account's logbook has come with one dive computer: another account, on this server
/// or another, has not imported those dives.
struct DiveComputerProgress: Codable, Hashable, Sendable {
  var fingerprint: Data?
  var lastDownloaded: Date?
  var receivedBeforeAccountKnown: Bool
  /// Optional, as each below is, so that a file written before it existed still decodes.
  var lastDownloadUnfinished: Bool?
  var awaitsOrder: Bool?

  init(_ record: DiveComputerRecord) {
    fingerprint = record.fingerprint
    lastDownloaded = record.lastDownloaded
    receivedBeforeAccountKnown = record.receivedBeforeAccountKnown
    lastDownloadUnfinished = record.lastDownloadUnfinished ? true : nil
    awaitsOrder = record.awaitsOrder ? true : nil
  }
}
