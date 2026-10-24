/// The checks every form shares, in the web's words. A length is counted in UTF-16 units, as a
/// JavaScript string's `length` counts it, so a sentence appears for the same text on both.
enum FormText {
  /// `Notes cannot exceed 100,000 characters` (`maxLengthMessage`).
  static func tooLong(_ label: String, _ max: Int) -> String {
    "\(label) cannot exceed \(NumberText.grouped(max)) characters"
  }

  /// The sentence for a string longer than `max`, or nil.
  static func length(_ value: String, _ label: String, max: Int) -> String? {
    value.utf16.count > max ? tooLong(label, max) : nil
  }

  /// A record's required name, checked on what is sent — trimmed (`requiredName`).
  static func requiredName(_ value: String, _ label: String, max: Int) -> String? {
    let trimmed = value.trimmedOfWhitespace
    if trimmed.isEmpty { return "\(label) is required" }
    return trimmed.utf16.count > max ? tooLong(label, max) : nil
  }

  /// Trimmed, and nil when nothing is left.
  static func trimmedOrNil(_ value: String) -> String? {
    let trimmed = value.trimmedOfWhitespace
    return trimmed.isEmpty ? nil : trimmed
  }
}
