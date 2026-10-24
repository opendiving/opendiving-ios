/// The checks the record forms share beyond ``FormText``'s.
enum RecordFormRules {
  /// An address that may be blank, checked as it is sent — trimmed (`optionalEmailField`).
  static func optionalEmail(_ value: String) -> String? {
    if let tooLong = FormText.length(value, "Email", max: 255) { return tooLong }
    let trimmed = value.trimmedOfWhitespace
    return trimmed.isEmpty || isEmail(trimmed) ? nil : "Please enter a valid email address"
  }

  /// Zod's email pattern: a local part of letters, digits and `_'+-.` that neither starts with
  /// nor doubles a dot and ends on a letter, digit or `_+-`; then labels of letters, digits and
  /// hyphens, each starting on a letter or digit; then a top-level part of two or more letters.
  static func isEmail(_ text: String) -> Bool {
    guard !text.hasPrefix("."), !text.contains("..") else { return false }
    let halves = text.split(separator: "@", omittingEmptySubsequences: false)
    guard halves.count == 2, let last = halves[0].last else { return false }
    let local = halves[0]
    guard local.allSatisfy({ $0.isASCIILetterOrDigit || "_'+-.".contains($0) }),
      isLocalEnd(last)
    else { return false }
    let labels = halves[1].split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count >= 2, let tld = labels.last, tld.count >= 2,
      tld.allSatisfy({ $0.isASCII && $0.isLetter })
    else { return false }
    return labels.dropLast().allSatisfy { label in
      guard let first = label.first, first.isASCIILetterOrDigit else { return false }
      return label.allSatisfy { $0.isASCIILetterOrDigit || $0 == "-" }
    }
  }

  private static func isLocalEnd(_ character: Character) -> Bool {
    character.isASCIILetterOrDigit || "_+-".contains(character)
  }
}

extension Character {
  var isASCIILetterOrDigit: Bool { isASCII && (isLetter || isNumber) }
}
