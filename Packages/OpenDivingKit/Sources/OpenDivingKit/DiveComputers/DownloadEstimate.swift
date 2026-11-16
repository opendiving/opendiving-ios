import Foundation

/// A walk's time left, reckoned as it goes.
///
/// After a listing, each entry still to come costs its length at the pace — this walk's, measured
/// from the dives it has delivered, where it has one, else the pace kept from the computer's
/// earlier walks — or the pace per dive where its length is not known; the entry in flight costs
/// what is left of its share. A family that reports libdivecomputer's progress instead is
/// reckoned from the rate that progress has moved at. With neither, there is no estimate.
///
/// A dive is timed from the listing or the entry before it to its delivery, and is not timed where
/// the computer said it was busy, or another app's handshake broke a transfer, meanwhile.
struct DownloadEstimate: Sendable {
  /// The pace kept from the computer's earlier walks.
  var kept: DownloadPace?

  private var downloads: [DiveComputerListing.Download] = []
  private var seen: Set<Data> = []
  /// When the entry in flight began: at the listing, then at each dive or skip.
  private var started: Date?
  private var interrupted = false

  private var timedLengths = 0.0
  private var timedLengthsTook = 0.0
  private var timedDives = 0
  private var timedDivesTook = 0.0

  /// The first progress report and the last, as fractions up to 1.
  private var firstProgress: (at: Date, fraction: Double)?
  private var lastProgress: (at: Date, fraction: Double)?

  init(kept: DownloadPace? = nil) {
    self.kept = kept
  }

  /// The pace this walk measured, nil before it timed a dive.
  var measured: DownloadPace? {
    guard timedDives > 0 else { return nil }
    return DownloadPace(
      perDiveSecond: timedLengths > 0 ? timedLengthsTook / timedLengths : nil,
      perDive: timedDivesTook / Double(timedDives))
  }

  mutating func listed(_ listing: DiveComputerListing, at date: Date) {
    downloads = listing.downloads
    started = date
    interrupted = false
  }

  /// The computer said it was busy, or another app broke a transfer: the entry in flight is not
  /// timed.
  mutating func interrupt() {
    interrupted = true
  }

  mutating func delivered(_ fingerprint: Data, at date: Date) {
    if let started, !interrupted {
      let took = date.timeIntervalSince(started)
      timedDives += 1
      timedDivesTook += took
      if let length = length(of: fingerprint), length > 0 {
        timedLengths += length
        timedLengthsTook += took
      }
    }
    passed(fingerprint, at: date)
  }

  mutating func skipped(_ fingerprint: Data, at date: Date) {
    passed(fingerprint, at: date)
  }

  mutating func progressed(_ fraction: Double, at date: Date) {
    if firstProgress == nil { firstProgress = (date, fraction) }
    lastProgress = (date, fraction)
  }

  private mutating func passed(_ fingerprint: Data, at date: Date) {
    seen.insert(fingerprint)
    started = date
    interrupted = false
  }

  private func length(of fingerprint: Data) -> TimeInterval? {
    downloads.first { $0.fingerprint == fingerprint }?.length
  }

  /// Something is left that an estimate would count down: a listed dive not yet delivered or
  /// skipped, or progress short of the end.
  var hasLeft: Bool {
    if let lastProgress, lastProgress.fraction < 1 { return true }
    return downloads.contains { !seen.contains($0.fingerprint) }
  }

  /// The seconds left at `date`, nil where nothing gives an estimate.
  func remaining(at date: Date) -> TimeInterval? {
    if let progressed = remainingByProgress(at: date) { return progressed }
    let left = downloads.filter { !seen.contains($0.fingerprint) }
    guard let started, !left.isEmpty else { return nil }
    let pace = (measured ?? DownloadPace()).over(kept)
    var costs: [TimeInterval] = []
    for download in left {
      let byLength = download.length.flatMap { length in pace.perDiveSecond.map { length * $0 } }
      guard let cost = byLength ?? pace.perDive else { return nil }
      costs.append(cost)
    }
    let inFlight = interrupted ? 0 : min(max(0, date.timeIntervalSince(started)), costs[0])
    return costs.reduce(0, +) - inFlight
  }

  /// From the rate libdivecomputer's progress moved at between its first report and its last.
  private func remainingByProgress(at date: Date) -> TimeInterval? {
    guard let firstProgress, let lastProgress, lastProgress.fraction < 1 else { return nil }
    let moved = lastProgress.fraction - firstProgress.fraction
    let took = lastProgress.at.timeIntervalSince(firstProgress.at)
    guard moved >= Self.leastProgress, took > 0 else { return nil }
    let left = (1 - lastProgress.fraction) * took / moved
    return max(0, left - date.timeIntervalSince(lastProgress.at))
  }

  /// How far progress moves before its rate is trusted.
  static let leastProgress = 0.02
}
