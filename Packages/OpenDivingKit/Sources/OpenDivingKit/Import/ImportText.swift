import Foundation

/// The sentences and labels the import screen prints, as the web's Import page writes them.
/// Every `code`, `kind` and outcome is the API's string, so one this build does not know reads
/// as the bare fact rather than as a blank.
public enum ImportText {
  /// A preview that failed with no sentence of the API's, and any 5xx.
  public static let readFailed = "The files could not be read. Please check them and try again."
  /// An apply that failed with no sentence of the API's.
  public static let applyFailed = "The import could not be completed. Nothing has been changed."
  public static let staleSentence =
    "The files changed since they were read. Read them again to see what they would import."
  /// Said on the import screen when a file was shared to the app.
  public static let oneAtATime =
    "Shared files arrive one at a time; to import several, pick them with Import files."

  // MARK: - Files

  /// What the API read one file as, and what becomes of it; `refused` reads as a refusal.
  public static func memberStatus(_ member: ImportMemberReport) -> (text: String, refused: Bool) {
    if let refusal = member.refusal { return ("Refused: " + refusal, true) }
    guard let format = member.format else { return ("Not read", false) }
    let label = VocabularyLabels.importSource(format)
    if format == "zip" {
      return ("\(label) · opened into \(countNoun(member.opened ?? 0, "file"))", false)
    }
    if member.kept { return ("\(label) · kept on its dive", false) }
    return (member.notKept.map { "\(label) · \(notKept($0))" } ?? label, false)
  }

  /// Why a file that was read is not kept.
  public static func notKept(_ reason: String) -> String {
    [
      "several_dives": "Not kept: it holds several dives",
      "several_recordings": "Not kept: it holds several computers' records",
      "too_large": "Not kept: too large to keep as a dive's file",
      "already_stored": "Not kept: your account already has this file",
      "not_written": "Not kept: nothing is written for its dive",
    ][reason] ?? "Not kept"
  }

  // MARK: - Dives

  /// What an import does to one dive.
  public static func diveOutcome(_ row: ImportDiveReport) -> String {
    switch row.outcome {
    case "created": return "New"
    case "restored": return "Brought back from deletion"
    case "linked": return "Already in your logbook"
    case "updated":
      var gains: [String] = []
      if row.filesAdded > 0 {
        gains.append(row.filesAdded == 1 ? "a file" : "\(row.filesAdded) files")
      }
      if row.recordingsAdded > 0 {
        gains.append(
          row.recordingsAdded == 1
            ? "another computer's recording"
            : "\(row.recordingsAdded) other computers' recordings")
      }
      return gains.isEmpty
        ? "Adds to a dive you have" : "Adds \(gains.joined(separator: " and ")) to a dive you have"
    case "skipped":
      return row.reason.map { "Skipped: " + $0 } ?? "Skipped"
    default:
      return row.outcome
    }
  }

  /// The import button's label. It never says an import would write nothing: whether an
  /// apply changes a stored row is the writer's fact, and the report does not carry it.
  public static func buttonLabel(_ dives: [ImportDiveReport]) -> String {
    let brought = dives.filter { $0.outcome == "created" || $0.outcome == "restored" }.count
    if brought > 0 { return "Import \(countNoun(brought, "dive"))" }
    let updated = dives.filter { $0.outcome == "updated" }
    let files = updated.reduce(0) { $0 + $1.filesAdded }
    let recordings = updated.reduce(0) { $0 + $1.recordingsAdded }
    var gains: [String] = []
    if files > 0 { gains.append(countNoun(files, "file")) }
    if recordings > 0 { gains.append(countNoun(recordings, "recording")) }
    return gains.isEmpty ? "Import" : "Import \(gains.joined(separator: " and "))"
  }

  /// A dive's start as the file gives it: its wall clock, then the offset that clock was on
  /// where it records one.
  public static func start(_ start: DiveTimestamp?) -> String {
    guard let start else { return "—" }
    let when = DateText.diveDateTime(start)
    guard start.wallClock != nil, let offset = start.utcOffsetMinutes else { return when }
    let sign = offset < 0 ? "-" : "+"
    let magnitude = abs(offset)
    return when + " " + sign + pad(magnitude / 60) + ":" + pad(magnitude % 60)
  }

  /// `49:00`: minutes and seconds, as the web's import rows print a dive time.
  public static func diveTime(_ seconds: Int) -> String {
    "\(seconds / 60):\(pad(seconds % 60))"
  }

  /// The sentence under a dive's notes when the API cut its list.
  public static func truncatedDiveNotes(_ truncated: Int) -> String? {
    guard truncated > 0 else { return nil }
    return countNoun(
      truncated, "further note about this dive is", plural: "further notes about this dive are")
      + " listed with the import's notes below."
  }

  // MARK: - Notes

  /// A note's badge, or nil for a note with no kind.
  public static func noteKind(_ kind: String?) -> String? {
    guard let kind else { return nil }
    return [
      "absent": "Not recorded", "inferred": "Worked out", "resolved": "Resolved",
      "dropped": "Dropped",
    ][kind] ?? kind
  }

  /// Only `dropped` costs the diver something; an unfamiliar kind reads as information.
  public static func noteTone(_ kind: String?) -> ImportNoteTone {
    switch kind {
    case "dropped": .warning
    case "absent": .muted
    default: .neutral
    }
  }

  /// A note's text: its collection where the list is not already about it, then the sentence.
  public static func noteText(collection: String?, message: String, implied: String? = nil)
    -> String
  {
    guard let collection, collection != implied else { return message }
    return collectionLabel(collection) + ": " + message
  }

  /// How often a group came up and where, or nil for a note that came up once and names no
  /// place.
  public static func notePlaces(_ group: ImportNoteGroup) -> String? {
    if group.wheres.isEmpty { return group.count > 1 ? "\(group.count) times" : nil }
    let more = group.count - group.wheres.count
    let listed = group.wheres.joined(separator: ", ") + (more > 0 ? " and \(more) more" : "")
    return countNoun(group.count, "place") + " — " + listed
  }

  /// The sentence that says the note list is not all of them.
  public static func truncatedNotes(_ truncated: Int) -> String? {
    guard truncated > 0 else { return nil }
    return countNoun(truncated, "further note is", plural: "further notes are")
      + " not shown. The counts above are complete."
  }

  // MARK: - Records and stored files

  /// A collection's display name.
  public static func collectionLabel(_ collection: String) -> String {
    [
      "dives": "Dives", "trips": "Trips", "courses": "Courses", "sites": "Dive sites",
      "species": "Marine life", "gear": "Gear", "gear_sets": "Gear sets",
      "gear_service_schedules": "Service schedules", "gear_service_records": "Service records",
      "certifications": "Certifications", "contacts": "Contacts", "people": "People",
    ][collection] ?? collection
  }

  /// The rows the Records table shows: empty rows left out, and the dives row wherever the
  /// report has dive rows, which are the report on dives.
  public static func recordRows(_ report: ImportReport) -> [ImportCollectionReport] {
    report.collections.filter { row in
      !(row.created == 0 && row.linked == 0 && row.restored == 0 && row.skipped == 0)
        && !(row.collection == "dives" && !report.dives.isEmpty)
    }
  }

  /// The Stored files line, or nil when the documents name none.
  public static func storedFiles(_ files: ImportFileReport) -> String? {
    guard files.referenced > 0 else { return nil }
    return "\(files.referenced) named — \(files.restored) restored, "
      + "\(files.notContained) not carried, \(files.skipped) skipped."
  }

  /// What a bare document cannot do, said once.
  public static func fileRestoreHint(_ report: ImportReport, archive: Bool) -> String? {
    let count = report.files.notContained
    guard !archive, count > 0 else { return nil }
    return (count == 1 ? "This file is" : "These \(count) files are")
      + " named by the document but not carried in it — import the full archive (.zip) to "
      + "restore the bytes as well."
  }

  // MARK: - Numbering

  /// What a renumber would tidy in a log, or nil for a tidy one.
  public static func numbering(_ summary: DiveNumberingSummary) -> String? {
    guard summary.totalDives > 0, let lowest = summary.lowest, let highest = summary.highest
    else { return nil }
    var notes: [String] = []
    if summary.missingCount > 0 {
      notes.append(countNoun(summary.missingCount, "number") + " unused")
    }
    if summary.duplicateCount > 0 {
      notes.append(
        countNoun(summary.duplicateCount, "dive shares", plural: "dives share") + " a number")
    }
    if summary.outOfDateOrderCount > 0 {
      notes.append("\(summary.outOfDateOrderCount) out of date order")
    }
    guard !notes.isEmpty else { return nil }
    let range = lowest == highest ? "#\(lowest)" : "#\(lowest)–#\(highest)"
    return "Numbered \(range) — \(notes.joined(separator: ", "))."
  }

  /// The result's numbering sentence: only where the import brought dives in and left more
  /// dives sharing a number or out of date order than the log had. Renumbering stays on the
  /// web, so it is a sentence and offers nothing.
  public static func numberingSuggestion(
    before: DiveNumberingSummary?, after: DiveNumberingSummary?, dives: [ImportDiveReport]
  ) -> String? {
    guard let before, let after,
      dives.contains(where: {
        ($0.outcome == "created" || $0.outcome == "restored") && $0.startTime != nil
      }),
      after.duplicateCount > before.duplicateCount
        || after.outOfDateOrderCount > before.outOfDateOrderCount,
      let description = numbering(after)
    else { return nil }
    return description + " Renumber them on the web, from the Dives page."
  }

  // MARK: - Check-in details

  /// A check-in detail's name.
  public static func checkInLabel(_ detail: ImportCheckInDetail) -> String {
    switch detail {
    case .email: "Email"
    case .phone: "Phone number"
    case .dateOfBirth: "Date of birth"
    case .emergencyContacts: "Emergency contacts"
    case .insurancePolicies: "Insurance policies"
    case .other(let name): name
    }
  }

  /// One side of a detail as one line, or nil when it holds nothing.
  public static func checkInSummary(_ detail: ImportCheckInDetail, proposed: Bool) -> String? {
    switch detail {
    case .email(let account, let offered), .phone(let account, let offered):
      let value = proposed ? offered : account
      return value?.isEmpty == false ? value : nil
    case .dateOfBirth(let account, let offered):
      return (proposed ? offered : account).map(DateText.date)
    case .emergencyContacts(let account, let offered):
      let line = (proposed ? offered : account)
        .map { joined([$0.name, $0.phone, $0.relationship]) }.joined(separator: "; ")
      return line.isEmpty ? nil : line
    case .insurancePolicies(let account, let offered):
      let line = (proposed ? offered : account)
        .map {
          joined([$0.provider, $0.number, $0.expiresOn.map { "expires " + DateText.date($0) }])
        }
        .joined(separator: "; ")
      return line.isEmpty ? nil : line
    case .other:
      return nil
    }
  }

  // MARK: - Helpers

  static func countNoun(_ count: Int, _ singular: String, plural: String? = nil) -> String {
    DiveDetailText.countNoun(count, singular, plural: plural)
  }

  private static func joined(_ parts: [String?]) -> String {
    parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
  }

  private static func pad(_ value: Int) -> String {
    value < 10 ? "0\(value)" : String(value)
  }
}

/// How loudly a note reads.
public enum ImportNoteTone: Hashable, Sendable {
  case warning, neutral, muted
}
