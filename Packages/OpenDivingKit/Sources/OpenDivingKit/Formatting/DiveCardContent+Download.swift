extension DiveCardContent {
  /// A downloaded dive's card before its import is answered: its computer for a title, the start
  /// in the dive's own spelling and the line, then *Dive time* and *Max depth*, each a dash where
  /// the computer's list did not say. With no line, the facts are the start alone.
  public static func download(
    computer: String, start: DiveTimestamp?, facts: ListedDiveFacts?, line: DownloadRow.Line?,
    units: UnitSystem
  ) -> DiveCardContent {
    var shown: [Fact] = []
    if let start { shown.append(Fact(text: DateText.diveDateTime(start))) }
    if let line { shown.append(Fact(text: line.text)) }
    return DiveCardContent(
      title: computer,
      facts: shown,
      figures: [
        Figure(label: "Dive time", value: facts?.length.map { DateText.minutes(seconds: $0) }),
        Figure(
          label: "Max depth",
          value: facts?.maxDepth.map { UnitFormat.depth($0, units, decimals: 0) }),
      ])
  }
}
