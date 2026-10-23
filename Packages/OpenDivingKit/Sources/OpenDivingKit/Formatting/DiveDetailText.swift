import Foundation

/// The small sentences and labels the dive page prints, as the web writes them.
public enum DiveDetailText {
  /// A stored file's size: `1 KB` at the least for a non-empty file, then one decimal of
  /// MB from 1024 KB and of GB from 1024 MB, ties rounded up (`formatFileSize`).
  public static func fileSize(_ bytes: Int) -> String {
    guard bytes > 0 else { return "0 KB" }
    let kb = Double(bytes) / 1024
    if kb < 1024 { return NumberText.plain(max(1, NumberText.round(kb))) + " KB" }
    let mb = kb / 1024
    if mb < 1024 { return NumberText.fixed(mb, decimals: 1) + " MB" }
    return NumberText.fixed(mb / 1024, decimals: 1) + " GB"
  }

  /// `1 marker`, `3 markers` (`countNoun`).
  public static func countNoun(_ count: Int, _ singular: String, plural: String? = nil) -> String {
    "\(count) " + (count == 1 ? singular : plural ?? singular + "s")
  }

  /// A linked gear item as its brand then its name, or the name alone (`gearItemLabel`).
  public static func gearItemLabel(name: String, brand: String?) -> String {
    guard let brand, !brand.isEmpty else { return name }
    return brand + " " + name
  }

  /// `Recording 2`: a recording's 1-based place on its dive.
  public static func recordingLabel(ordinal: Int) -> String {
    "Recording \(ordinal + 1)"
  }

  /// Why a recording lists no file, by where its samples came from; nil when it has one.
  public static func noFileKeptSentence(fileCount: Int, provenance: String?) -> String? {
    guard fileCount == 0 else { return nil }
    switch provenance {
    case "divejson_import":
      return "No file kept — these samples were imported through the converter."
    case "merge":
      return "No file kept — these samples were merged from two recordings."
    default:
      return "No file kept — nothing was stored here to re-read this recording from."
    }
  }

  /// A contact's address on one line, its empty parts left out; nil when none is left
  /// (`formatContactAddress`).
  public static func contactAddress(_ parts: [String?]) -> String? {
    let kept = parts.compactMap { $0?.trimmedOfWhitespace }.filter { !$0.isEmpty }
    return kept.isEmpty ? nil : kept.joined(separator: ", ")
  }

  /// A website as a link reads it — host and path without the scheme or a lone `/` —
  /// or the text as stored where it does not parse (`formatWebsite`).
  public static func website(_ website: String) -> String {
    guard let components = URLComponents(string: website), components.scheme != nil,
      let host = components.host, !host.isEmpty
    else { return website }
    var text = host.lowercased()
    if let port = components.port { text += ":\(port)" }
    let path = components.percentEncodedPath
    if !path.isEmpty && path != "/" { text += path }
    if let query = components.percentEncodedQuery, !query.isEmpty { text += "?" + query }
    return text
  }

  /// A phone number as a `tel:` link dials it: the digits and a `+`, nothing else.
  public static func dialable(_ phone: String) -> String {
    String(phone.filter { $0 == "+" || ("0"..."9").contains($0) })
  }

  /// A stretch on one cylinder, `<1min` under half a minute, where whole minutes would
  /// print `0min` beside real litres.
  public static func timeOnGas(seconds: Int) -> String {
    seconds < 30 ? "<1min" : DateText.hoursMinutes(seconds: seconds)
  }

  /// How much of the dive the per-tank figures cover, or nil when the remainder is under a
  /// minute (`gasAttributionNote`). The total is the profile's span, which runs past the
  /// dive time, so the sentence names the dive computer as its source.
  public static func gasAttributionNote(attributedSeconds: Int?, duration: Int?) -> String? {
    guard let attributed = attributedSeconds, let total = duration, total > 0,
      attributed < total, total - attributed >= unattributedNoteSeconds
    else { return nil }
    return "These figures cover \(DateText.hoursMinutes(seconds: attributed)) of the "
      + "\(DateText.hoursMinutes(seconds: total)) the dive computer recorded - the rest "
      + "couldn't be assigned to a cylinder."
  }

  /// The pager's spoken name for a neighbouring dive — `Previous dive: #531, Oct 2, 2026` —
  /// whose date rides the label rather than the button, which keeps one width.
  public static func neighborLabel(_ direction: String, number: Int, start: DiveTimestamp)
    -> String
  {
    "\(direction): #\(number), " + DateText.diveDate(start)
  }

  /// Below this the unattributed remainder is rounding, not a gap worth a sentence.
  static let unattributedNoteSeconds = 60
}
