/// A number as a diver types it, on whichever keypad the phone shows: the decimal keypad types
/// the region's separator, a comma across much of Europe, so `12,5` and `12.5` are one depth.
/// Two characters are looked at and no `Locale` is asked (`parseDecimal`).
public enum DecimalEntry {
  /// The number in `text`, with a point or a comma before its decimals; nil when it is not one —
  /// including when it carries both, which is a thousands separator and a guess not made here.
  public static func parse(_ text: String) -> Double? {
    let trimmed = text.trimmedOfWhitespace
    if trimmed.contains(".") && trimmed.contains(",") { return nil }
    var body = Substring(trimmed.replacingFirst(",", with: "."))
    var sign = ""
    if let first = body.first, first == "+" || first == "-" {
      sign = first == "-" ? "-" : ""
      body = body.dropFirst()
    }
    let pieces = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let whole = pieces[0]
    let fraction = pieces.count > 1 ? pieces[1] : ""
    guard whole.allSatisfy(\.isASCIIDigit), fraction.allSatisfy(\.isASCIIDigit),
      !whole.isEmpty || !fraction.isEmpty
    else { return nil }
    return Double(sign + (whole.isEmpty ? "0" : whole) + "." + (fraction.isEmpty ? "0" : fraction))
  }

  /// What is wrong with `text` as a number from `min` to `max`, as the form says it under the
  /// box (`decimalEntryMessage`); nil when nothing is, an empty box included — that is a
  /// required check's business.
  public static func message(_ text: String, min: Double? = nil, max: Double? = nil) -> String? {
    if text.trimmedOfWhitespace.isEmpty { return nil }
    guard let value = parse(text) else { return "Enter a number." }
    if let min, value < min { return "Enter \(NumberText.plain(min)) or more." }
    if let max, value > max { return "Enter \(NumberText.plain(max)) or less." }
    return nil
  }
}

extension String {
  func replacingFirst(_ target: Character, with replacement: Character) -> String {
    guard let index = firstIndex(of: target) else { return self }
    var copy = self
    copy.replaceSubrange(index...index, with: String(replacement))
    return copy
  }
}
