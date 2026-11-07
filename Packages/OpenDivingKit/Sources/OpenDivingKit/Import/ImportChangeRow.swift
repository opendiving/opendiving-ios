import Foundation

/// One line of a modified dive's sheet, in the diver's words and units: an element of a list
/// added or removed as a sentence, or a value with what it was and what it becomes.
public enum ImportChangeRow: Hashable, Sendable {
  case element(String)
  case value(label: String, before: String, after: String)

  /// One entry of a modified dive's `changes`. Never drops one: the list is the writer's, and a
  /// build that predates a member shows it by its path rather than swallowing what the import
  /// does.
  public static func row(_ change: LogbookImportChange, units: UnitSystem) -> ImportChangeRow {
    labelled(change, units)
      ?? value(change.member, change, Self.plain, units)
  }

  private typealias Format = @Sendable (ImportChangeValue, UnitSystem) -> String
  private typealias Summary = @Sendable (ImportChangeValue) -> String?

  private struct Member: Sendable {
    let label: String
    let format: Format

    init(_ label: String, _ format: @escaping Format) {
      self.label = label
      self.format = format
    }
  }

  private struct Element: Sendable {
    let noun: String
    var summary: Summary?
  }

  // MARK: - Paths

  private static func labelled(_ change: LogbookImportChange, _ units: UnitSystem)
    -> ImportChangeRow?
  {
    let path = change.member.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard path.count > 1 else {
      return diveMembers[change.member].map { value($0.label, change, $0.format, units) }
    }
    guard let index = Int(path[1]) else { return nil }
    let rest = Array(path.dropFirst(2))
    switch path[0] {
    case "recordings": return recording(index, rest, change, units)
    case "mixtures": return mixture(index, rest, change, units)
    default:
      guard rest.isEmpty, let list = diveElements[path[0]] else { return nil }
      return element(list.noun, change, list.summary, units)
    }
  }

  private static func recording(
    _ index: Int, _ rest: [String], _ change: LogbookImportChange, _ units: UnitSystem
  ) -> ImportChangeRow? {
    let prefix = "Recording \(index + 1): "
    guard let first = rest.first else {
      return element("Recording \(index + 1)", change, recordingSummary, units)
    }
    let second = rest.count > 1 ? rest[1] : nil
    if first == "files", let second, Int(second) != nil {
      if rest.count == 2 { return element("File", change, { $0["original_filename"].text }, units) }
      return rest.count == 3 && rest[2] == "original_filename"
        ? value(prefix + "File name", change, plain, units) : nil
    }
    if rest.count == 1, let member = recordingMembers[first] {
      return value(prefix + member.label, change, member.format, units)
    }
    if first == "profile", second == "channels", rest.count == 3, Int(rest[2]) != nil {
      return element(prefix + "Curve", change, { $0.text }, units)
    }
    let nested = ["device": deviceMembers, "deco_model": decoMembers, "profile": profileMembers]
    if rest.count == 2, let second, let member = nested[first]?[second],
      let owner = recordingMembers[first]?.label
    {
      return value("\(prefix)\(owner) \(lowered(member.label))", change, member.format, units)
    }
    return nil
  }

  private static func mixture(
    _ index: Int, _ rest: [String], _ change: LogbookImportChange, _ units: UnitSystem
  ) -> ImportChangeRow? {
    let tank = "Tank \(index + 1)"
    if rest.isEmpty { return element(tank, change, mixtureSummary, units) }
    guard rest.count == 1, let member = mixtureMembers[rest[0]] else { return nil }
    return value("\(tank): \(member.label)", change, member.format, units)
  }

  // MARK: - Rows

  private static func value(
    _ label: String, _ change: LogbookImportChange, _ format: Format, _ units: UnitSystem
  ) -> ImportChangeRow {
    let shown = { (value: ImportChangeValue) in value == .null ? "—" : format(value, units) }
    return .value(label: label, before: shown(change.before), after: shown(change.after))
  }

  /// An element added or removed reads as one line; a list position holding another value is a
  /// change of a value like any.
  private static func element(
    _ noun: String, _ change: LogbookImportChange, _ summary: Summary?, _ units: UnitSystem
  ) -> ImportChangeRow {
    guard change.before == .null || change.after == .null else {
      return value(noun, change, { value, _ in summary?(value) ?? value.asSent }, units)
    }
    let removed = change.after == .null
    let text = summary?(removed ? change.before : change.after)
    return .element("\(noun) \(removed ? "removed" : "added")" + (text.map { " — " + $0 } ?? ""))
  }

  private static func lowered(_ label: String) -> String {
    guard let first = label.first, first.isUppercase, label.dropFirst().first?.isLowercase == true
    else { return label }
    return first.lowercased() + label.dropFirst()
  }

  // MARK: - Formats

  private static let plain: Format = { value, _ in value.asSent }

  /// A value this build cannot read as its member's type is shown as the API sent it.
  private static func measured(_ format: @escaping @Sendable (Double, UnitSystem) -> String)
    -> Format
  {
    { value, units in value.number.map { format($0, units) } ?? value.asSent }
  }

  private static func worded(_ label: @escaping @Sendable (String) -> String) -> Format {
    { value, _ in value.text.map(label) ?? value.asSent }
  }

  private static let when: Format = { value, _ in
    value.text.flatMap(DiveTimestamp.init(wireValue:)).map(DateText.diveDateTime) ?? value.asSent
  }

  private static let depth = measured { UnitFormat.depth($0, $1) }
  private static let temperature = measured { UnitFormat.temperature($0, $1) }
  private static let pressure = measured { UnitFormat.pressure($0, $1) }
  private static let percent = measured { value, _ in NumberText.plain(value) + "%" }
  private static let bar = measured { value, _ in NumberText.plain(value) + " bar" }
  private static let beats = measured { value, _ in NumberText.plain(value) + " bpm" }

  /// A link to a record held by uuid alone, which names nothing a diver can read: that the dive
  /// has one is what can be said without reading another route.
  private static let linked: Format = { _, _ in "Linked" }

  // MARK: - Members

  /// The dive's own members, in the dive form's words.
  private static let diveMembers: [String: Member] = [
    "start_time": Member("Start time", when),
    "dive_number": Member("Dive number", plain),
    "submerged_time": Member(
      "Dive time", measured { value, _ in DateText.hoursMinutes(seconds: value) }),
    "max_depth": Member("Maximum depth", depth),
    "avg_depth": Member("Average depth", depth),
    "bottom_temperature": Member("Bottom temperature", temperature),
    "air_temperature": Member("Air temperature", temperature),
    "visibility": Member("Visibility", measured { UnitFormat.visibility($0, $1) }),
    "altitude": Member("Altitude", measured { UnitFormat.altitude($0, $1) }),
    "weight": Member("Weight", measured { UnitFormat.weight($0, $1) }),
    "water_type": Member("Water type", worded(VocabularyLabels.waterType)),
    "type": Member("Dive type", worded(VocabularyLabels.diveType)),
    "entry_type": Member("Entry type", worded(VocabularyLabels.entryType)),
    "waves": Member("Waves", worded(VocabularyLabels.waves)),
    "current": Member("Current", worded(VocabularyLabels.current)),
    "weather": Member("Weather", worded(VocabularyLabels.weather)),
    "boat_name": Member("Boat name", plain),
    "notes": Member("Notes", plain),
    "rating": Member("Rating", measured { value, _ in NumberText.plain(value) + " / 5" }),
    "entry_latitude": Member("Entry latitude", plain),
    "entry_longitude": Member("Entry longitude", plain),
    "exit_latitude": Member("Exit latitude", plain),
    "exit_longitude": Member("Exit longitude", plain),
    "trip_uuid": Member("Trip", linked),
    "course_uuid": Member("Course", linked),
    "contact_uuid": Member("Dive center", linked),
  ]

  private static let mixtureMembers: [String: Member] = [
    "volume": Member("Volume", measured { value, _ in NumberText.plain(value) + " L" }),
    "start_pressure": Member("Start pressure", pressure),
    "end_pressure": Member("End pressure", pressure),
    "oxygen": Member("O₂", percent),
    "helium": Member("He", percent),
    "po2_limit": Member("ppO₂ limit", bar),
    "role": Member("Role", worded(VocabularyLabels.gasRole)),
    "usage": Member("Usage", worded(VocabularyLabels.tankUsage)),
    "gear_item": Member("Cylinder") { value, _ in
      value["name"].text.map {
        DiveDetailText.gearItemLabel(name: $0, brand: value["brand"].text)
      } ?? value.asSent
    },
  ]

  private static let recordingMembers: [String: Member] = [
    "mode": Member(
      "Mode", worded { VocabularyLabels.labelOrFallback(RecordingLabels.modes, $0) }),
    "salinity": Member(
      "Salinity", worded { VocabularyLabels.labelOrFallback(RecordingLabels.salinities, $0) }),
    "started_at": Member("Start", when),
    "cns_start": Member("CNS at the start", percent),
    "cns_end": Member("CNS at the end", percent),
    "otu_start": Member("OTU at the start", plain),
    "otu_end": Member("OTU at the end", plain),
    "surface_pressure_bar": Member("Surface pressure", bar),
    "device": Member("Device") { value, _ in deviceLabel(value) },
    "deco_model": Member("Decompression model") { value, _ in
      RecordingLabels.settings(
        mode: nil, decoName: value["name"].text, decoAlgorithm: value["algorithm"].text,
        gfLow: value["gf_low"].integer, gfHigh: value["gf_high"].integer,
        conservatism: value["conservatism"].integer, salinity: nil) ?? value.asSent
    },
    "profile": Member("Profile", profileSummary),
  ]

  private static let deviceMembers: [String: Member] = [
    "brand": Member("Brand", plain),
    "model": Member("Model", plain),
    "serial": Member("Serial number", plain),
    "firmware": Member("Firmware", plain),
    "name": Member("Name", plain),
    "dive_number": Member("Its dive number", plain),
  ]

  private static let decoMembers: [String: Member] = [
    "algorithm": Member("Algorithm", plain),
    "name": Member("Name", plain),
    "gf_low": Member("GF low", percent),
    "gf_high": Member("GF high", percent),
    "conservatism": Member("Conservatism", plain),
  ]

  private static let profileMembers: [String: Member] = [
    "duration": Member(
      "Span", measured { value, _ in DateText.hoursMinutes(seconds: value / 1000) }),
    "depth_sample_count": Member("Samples", plain),
    "event_count": Member("Markers", plain),
    "max_depth": Member("Maximum depth", depth),
    "max_ceiling": Member("Deepest ceiling", depth),
    "min_temperature": Member("Lowest temperature", temperature),
    "max_temperature": Member("Highest temperature", temperature),
    "min_pressure": Member("Lowest pressure", pressure),
    "max_pressure": Member("Highest pressure", pressure),
    "max_heart_rate": Member("Highest heart rate", beats),
    "average_heart_rate": Member("Average heart rate", beats),
  ]

  /// A dive's lists, whose elements are added and removed whole.
  private static let diveElements: [String: Element] = [
    "dive_sites": Element(noun: "Dive site") { $0["name"].text },
    "gear_items": Element(noun: "Gear") { value in
      value["name"].text.map {
        DiveDetailText.gearItemLabel(name: $0, brand: value["brand"].text)
      }
    },
    "sightings": Element(noun: "Species") { value in
      value["scientific_name"].text.map {
        SpeciesNames.displayName(scientificName: $0, commonName: value["common_name"].text)
      }
    },
    "tags": Element(noun: "Tag") { $0.text },
    "people": Element(noun: "Person"),
  ]

  // MARK: - Summaries

  private static func deviceLabel(_ value: ImportChangeValue) -> String {
    RecordingLabels.device(
      brand: value["brand"].text, model: value["model"].text, serial: value["serial"].text,
      name: value["name"].text) ?? RecordingLabels.unnamedDevice
  }

  /// What a recording's samples come to, on one line: span, depth and how many.
  private static let profileSummary: Format = { value, units in
    guard let duration = value["duration"].number, let samples = value["depth_sample_count"].integer
    else { return value.asSent }
    return [
      DateText.hoursMinutes(seconds: duration / 1000),
      value["max_depth"].number.map { UnitFormat.depth($0, units) },
      DiveDetailText.countNoun(samples, "sample"),
    ].compactMap { $0 }.joined(separator: " · ")
  }

  /// A cylinder on one line: its gas, then its vessel's size where it has one.
  private static let mixtureSummary: Summary = { value in
    [
      GasMath.name(oxygen: value["oxygen"].number, helium: value["helium"].number)
        ?? "Gas not recorded",
      value["volume"].number.map { NumberText.plain($0) + " L" },
    ].compactMap { $0 }.joined(separator: ", ")
  }

  private static let recordingSummary: Summary = { value in
    var files: [ImportChangeValue] = []
    if case .array(let list) = value["files"] { files = list }
    return ([deviceLabel(value["device"])] + files.compactMap { $0["original_filename"].text })
      .joined(separator: ", ")
  }
}

extension ImportChangeValue {
  fileprivate subscript(key: String) -> ImportChangeValue {
    if case .object(let members) = self { members[key] ?? .null } else { .null }
  }

  fileprivate var text: String? {
    if case .string(let value) = self { value } else { nil }
  }

  fileprivate var number: Double? {
    if case .number(let value) = self { value } else { nil }
  }

  fileprivate var integer: Int? { number.flatMap { Int(exactly: $0) } }

  /// As the API sent it, for a value nothing here has words for.
  fileprivate var asSent: String {
    switch self {
    case .null: return "—"
    case .bool(let value): return String(value)
    case .number(let value): return NumberText.plain(value)
    case .string(let value): return value
    case .array, .object:
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
      return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
  }
}
