/// What the numbering card above the dives, the renumber sheet and an import's offer say, in the
/// web's words. Descriptive, never corrective: a gap is as often a log that continues a paper
/// logbook as a slip, and only the diver knows which of theirs are deliberate.
public enum DiveNumberingText {
  /// `Numbered #1–#40 — 3 numbers unused, 2 dives share a number.`; nil for an empty log and
  /// for one already numbered consecutively in date order, which takes every way in to a
  /// renumber off it.
  public static func description(_ summary: DiveNumberingSummary) -> String? {
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
    // Equal ends survive the notes only through duplicates: a range that collapsed.
    let range = lowest == highest ? "#\(lowest)" : "#\(lowest)–#\(highest)"
    return "Numbered \(range) — \(notes.joined(separator: ", "))."
  }

  /// An import's offer, after what the log's numbering now is.
  static func importOffer(_ description: String, from day: CalendarDate) -> String {
    description + " Renumbering from " + DateText.inSentence(DateText.date(day))
      + " numbers every dive from then on in date order."
  }

  /// Where an import's offer stood, once its renumber has written.
  public static let renumbered = "Your dives are renumbered."

  // MARK: - The sheet

  public static let intro =
    "Numbers your dives consecutively in date order. Nothing else about them changes. Worth "
    + "doing once your log is complete — if some of your dives are recorded elsewhere, the gaps "
    + "between your numbers may be deliberate."
  public static let startAtNote = "The number your earliest dive in scope gets."
  public static let fromDateNote = "Leave it unset to renumber the whole log."

  static let startAtRange =
    "Enter a starting number from 1 to \(NumberText.grouped(DiveFormBounds.integerMax))."
  static let working = "Working out what would change…"
  static let previewFailed = "Couldn't load a preview. Check your connection and try again."
  static let nothingInScope = "No dives fall in this range."
  static let alreadyNumbered = "Your dives are already numbered this way — nothing would change."

  /// `3 of 40 dives would be renumbered.`
  static func changeCount(_ result: DiveRenumberResult) -> String {
    "\(result.changes.count) of "
      + countNoun(result.divesInScope, "dive") + " would be renumbered."
  }

  /// `#12 → #10`.
  public static func move(_ change: DiveRenumberChange) -> String {
    "#\(change.diveNumber) → #\(change.newDiveNumber)"
  }

  private static func countNoun(_ count: Int, _ singular: String, plural: String? = nil)
    -> String
  {
    DiveDetailText.countNoun(count, singular, plural: plural)
  }
}
