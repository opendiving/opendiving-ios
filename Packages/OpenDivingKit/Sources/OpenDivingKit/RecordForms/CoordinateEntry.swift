/// A latitude or a longitude as a site or contact form takes it: typed text, read as the web
/// reads it (`-?\d+(\.\d+)?`) except that a comma stands for the point, as on every other number
/// the phone takes — the decimal keypad types the region's separator.
enum CoordinateEntry {
  /// The coordinate typed, or nil for a blank box or text that is not one.
  static func value(_ text: String) -> Double? {
    let trimmed = text.trimmedOfWhitespace
    if trimmed.contains(".") && trimmed.contains(",") { return nil }
    let normalized = trimmed.replacingFirst(",", with: ".")
    var body = Substring(normalized)
    if body.first == "-" { body = body.dropFirst() }
    let pieces = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard !pieces[0].isEmpty, pieces[0].allSatisfy(\.isASCIIDigit) else { return nil }
    if pieces.count == 2 {
      guard !pieces[1].isEmpty, pieces[1].allSatisfy(\.isASCIIDigit) else { return nil }
    }
    return Double(normalized)
  }

  static func isSet(_ text: String) -> Bool { !text.trimmedOfWhitespace.isEmpty }

  /// The sentence for one box (`coordinateField`): not a decimal number, or out of range.
  static func message(_ text: String, limit: Double, label: String, example: String) -> String? {
    guard isSet(text) else { return nil }
    guard let value = value(text) else {
      return "\(label) must be a decimal number, e.g. \(example)"
    }
    let bound = NumberText.plain(limit)
    return abs(value) <= limit ? nil : "\(label) must be between -\(bound) and \(bound)"
  }

  /// Both boxes, and the pair's rule — both or neither, the message on the half missing.
  static func check(latitude: String, longitude: String, into list: inout FormIssueList) {
    list.add(
      "latitude", message(latitude, limit: 90, label: "Latitude", example: "27.8506"))
    list.add(
      "longitude", message(longitude, limit: 180, label: "Longitude", example: "34.3136"))
    if isSet(longitude) && !isSet(latitude) {
      list.add("latitude", "Latitude is required when longitude is given")
    }
    if isSet(latitude) && !isSet(longitude) {
      list.add("longitude", "Longitude is required when latitude is given")
    }
  }
}
