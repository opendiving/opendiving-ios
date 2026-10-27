/// How each of the API's vocabularies reads on screen, keyed on the wire value.
///
/// Most fall back for a value this build has no label for — the API can grow a member
/// before the app ships its label — by de-snaking it (`semi_closed` → "Semi closed").
/// The chips' abbreviations deliberately have no fallback: salt water, open circuit and
/// any value the table lacks emit no chip.
public enum VocabularyLabels {
  /// The label `labels` gives `value`, or `value` de-snaked with its first letter
  /// capitalised.
  public static func labelOrFallback(_ labels: [String: String], _ value: String) -> String {
    if let label = labels[value] { return label }
    let spaced = value.replacingAll("_", with: " ")
    guard let first = spaced.first else { return spaced }
    return first.uppercased() + spaced.dropFirst()
  }

  public static func waterType(_ value: String) -> String {
    labelOrFallback(waterTypes, value)
  }

  /// The chip a dive's water type shows; nil for salt water and for any value without
  /// one.
  public static func waterTypeAbbreviation(_ value: String) -> String? {
    waterTypeAbbreviations[value]
  }

  public static func diveType(_ value: String) -> String {
    labelOrFallback(diveTypes, value)
  }

  /// The chip a dive's type shows; nil for open circuit and for any value without one.
  public static func diveTypeAbbreviation(_ value: String) -> String? {
    diveTypeAbbreviations[value]
  }

  public static func current(_ value: String) -> String {
    labelOrFallback(currents, value)
  }

  public static func waves(_ value: String) -> String {
    labelOrFallback(wavesLabels, value)
  }

  public static func weather(_ value: String) -> String {
    labelOrFallback(weatherLabels, value)
  }

  public static func entryType(_ value: String) -> String {
    labelOrFallback(entryTypes, value)
  }

  /// A cylinder's role, one word: the "gas" is said by whatever sits beside it.
  public static func gasRole(_ value: String) -> String {
    labelOrFallback(gasRoles, value)
  }

  public static func tankUsage(_ value: String) -> String {
    labelOrFallback(tankUsages, value)
  }

  /// A person's role on a dive, a trip or a course.
  public static func personRole(_ value: String) -> String {
    labelOrFallback(personRoles, value)
  }

  /// A gear item's type; nil for none.
  public static func gearType(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return labelOrFallback(gearTypes, value)
  }

  /// A sighting's abundance band: `Few`, `Many`, `Abundant`.
  public static func abundance(_ value: String) -> String {
    labelOrFallback(abundances, value)
  }

  /// The count a band stands for, `2–10`; nil for a band the table lacks, which then
  /// shows its label alone.
  public static func abundanceRange(_ value: String) -> String? {
    abundanceRanges[value]
  }

  /// A file's source format, as the converter names it.
  public static func importSource(_ value: String) -> String {
    labelOrFallback(importSources, value)
  }

  /// A certification's agency; nil for none. `other` reads as the diver's own
  /// `agency_other` where they wrote one.
  public static func certificationAgency(_ value: String?, other: String? = nil) -> String? {
    guard let value, !value.isEmpty else { return nil }
    if value == "other" {
      let own = other?.trimmedOfWhitespace ?? ""
      return own.isEmpty ? "Other" : own
    }
    return labelOrFallback(certificationAgencies, value)
  }

  /// The face of a card a stored image shows; nil for a side the table lacks.
  public static func certificationSide(_ value: String) -> String? {
    certificationSides[value]
  }

  static let waterTypes = ["salt": "Salt water", "fresh": "Fresh water", "brackish": "Brackish"]

  static let waterTypeAbbreviations = ["fresh": "Fresh", "brackish": "Brackish"]

  static let diveTypes = [
    "open_circuit": "Open circuit",
    "closed_circuit": "Closed circuit",
    "semi_closed": "Semi-closed circuit",
    "freedive": "Freediving",
    "snorkel": "Snorkeling",
    "surface_supplied": "Surface-supplied",
  ]

  static let diveTypeAbbreviations = [
    "closed_circuit": "CCR",
    "semi_closed": "SCR",
    "surface_supplied": "SSD",
    "freedive": "Freedive",
    "snorkel": "Snorkel",
  ]

  static let currents = [
    "none": "None", "light": "Light", "moderate": "Moderate", "strong": "Strong",
    "extreme": "Extreme",
  ]

  static let wavesLabels = [
    "calm": "Calm", "slight": "Slight", "moderate": "Moderate", "rough": "Rough",
  ]

  static let weatherLabels = [
    "clear": "Clear", "partly_cloudy": "Partly cloudy", "overcast": "Overcast", "rain": "Rain",
    "storm": "Storm", "snow": "Snow", "fog": "Fog",
  ]

  static let entryTypes = ["shore": "Shore", "boat": "Boat", "pier": "Pier", "pool": "Pool"]

  static let gasRoles = [
    "bottom": "Bottom", "deco": "Deco", "diluent": "Diluent", "oxygen": "Oxygen",
  ]

  static let tankUsages = ["parallel": "Parallel", "staged": "Staged"]

  static let personRoles = [
    "buddy": "Buddy", "guide": "Guide", "instructor": "Instructor", "student": "Student",
    "companion": "Companion",
  ]

  static let gearTypes = [
    "mask": "Mask", "snorkel": "Snorkel", "fins": "Fins", "wetsuit": "Wetsuit",
    "drysuit": "Drysuit", "vest": "Vest", "hood": "Hood", "gloves": "Gloves", "boots": "Boots",
    "bcd": "BCD", "backplate": "Backplate", "wing": "Wing", "regulator": "Regulator",
    "rebreather": "Rebreather", "computer": "Dive computer", "transmitter": "Transmitter",
    "cylinder": "Cylinder", "light": "Light", "scooter": "Scooter", "smb": "SMB",
    "mirror": "Mirror", "whistle": "Whistle", "reel": "Reel", "knife": "Knife",
    "line_cutter": "Line cutter", "shears": "Shears", "compass": "Compass", "camera": "Camera",
    "other": "Other",
  ]

  static let abundances = ["few": "Few", "many": "Many", "abundant": "Abundant"]

  static let abundanceRanges = ["few": "2–10", "many": "11–100", "abundant": "101+"]

  static let importSources = [
    "uddf": "UDDF", "ssrf": "Subsurface", "fit": "FIT", "suunto_json": "Suunto app JSON",
    "suunto_xml": "Suunto DM5 XML", "divejson": "DiveJSON", "archive": "OpenDiving archive",
    "zip": "Zip",
    // The import's key for any restored file this server does not read. The phone's downloads
    // are what carries it — a dive computer's original bytes, kept as downloaded — so it is
    // named for them; a restored file of another unread kind wears the same label.
    "divejson_import": "Dive computer original (.bin)",
  ]

  static let certificationAgencies = [
    "padi": "PADI", "ssi": "SSI", "naui": "NAUI", "sdi": "SDI", "tdi": "TDI", "cmas": "CMAS",
    "raid": "RAID", "bsac": "BSAC", "gue": "GUE", "iantd": "IANTD", "psai": "PSAI",
    "dan": "DAN", "efr": "EFR", "andi": "ANDI", "snsi": "SNSI", "acuc": "ACUC", "pss": "PSS",
    "ida": "IDA", "ndl": "NDL", "utd": "UTD", "saa": "SAA", "scotsac": "ScotSAC", "iac": "IAC",
    "protec": "ProTec", "pdic": "PDIC", "nase": "NASE", "sei": "SEI", "ymca": "YMCA",
    "erdi": "ERDI", "aida": "AIDA", "molchanovs": "Molchanovs", "pfi": "PFI",
    "apnea_academy": "Apnea Academy", "fii": "FII", "nss_cds": "NSS-CDS", "nacd": "NACD",
    "idea": "IDEA", "diwa": "DIWA", "other": "Other",
  ]

  static let certificationSides = ["front": "Front", "back": "Back"]
}

extension String {
  fileprivate func replacingAll(_ target: Character, with replacement: String) -> String {
    var result = ""
    for character in self {
      if character == target { result += replacement } else { result.append(character) }
    }
    return result
  }
}
