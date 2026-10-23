extension StringProtocol {
  /// Without leading and trailing whitespace, as JavaScript's `trim()` leaves a string.
  var trimmedOfWhitespace: String {
    guard let first = firstIndex(where: { !$0.isWhitespace }),
      let last = lastIndex(where: { !$0.isWhitespace })
    else { return "" }
    return String(self[first...last])
  }
}
