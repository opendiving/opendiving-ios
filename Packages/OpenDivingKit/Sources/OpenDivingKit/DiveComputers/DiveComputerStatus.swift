import Foundation

/// A paired computer's one line in the *Dive Computers* list, read from the engine's state: the
/// walk in flight, the dives held for a zone, the dives waiting to upload, then what the record
/// says of its last download and its switch.
@MainActor
public enum DiveComputerStatus {
  public static func line(
    _ record: DiveComputerRecord, walk: DiveComputerWalk?, archives: [DownloadArchive],
    held: [DiveComputerEngine.HeldDives], in zone: TimeZone = .current
  ) -> String {
    if let walk, walk.isOf(record), let line = walk.statusLine { return line }
    let holding = held.filter { $0.record == record.id }.reduce(0) { $0 + $1.dives }
    if holding > 0 { return DiveComputerText.chooseTimeZone(holding) }
    let waiting = archives.filter { $0.record == record.id }.reduce(0) { $0 + $1.summary.dives }
    if waiting > 0 { return DiveComputerText.waitingToUpload(waiting) }
    if record.lastDownloadUnfinished { return DiveComputerText.lastUnfinished }
    if !record.downloadsAutomatically { return DiveComputerText.automaticOff }
    guard let last = record.lastDownloaded else { return DiveComputerText.noDivesYet }
    return DiveComputerText.lastDownloaded(last, in: zone)
  }
}
