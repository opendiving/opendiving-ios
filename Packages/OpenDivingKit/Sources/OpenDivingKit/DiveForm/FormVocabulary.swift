/// Every pick-list the forms offer, in the order the web's menus offer it; the labels are
/// ``VocabularyLabels``'. Each is a hand-kept mirror of an API enum, as the web's are.
public enum FormVocabulary {
  public static let waterTypes = ["salt", "fresh", "brackish"]
  public static let diveTypes = [
    "open_circuit", "closed_circuit", "semi_closed", "freedive", "snorkel", "surface_supplied",
  ]
  public static let currents = ["none", "light", "moderate", "strong", "extreme"]
  public static let waves = ["calm", "slight", "moderate", "rough"]
  public static let weather = [
    "clear", "partly_cloudy", "overcast", "rain", "storm", "snow", "fog",
  ]
  public static let entryTypes = ["shore", "boat", "pier", "pool"]
  public static let gasRoles = ["bottom", "deco", "diluent", "oxygen"]
  public static let tankUsages = ["parallel", "staged"]
  public static let abundances = ["few", "many", "abundant"]
  public static let personRoles = ["buddy", "guide", "instructor", "student", "companion"]
  /// The way a diver lays kit out, mask first.
  public static let gearTypes = [
    "mask", "snorkel", "fins", "wetsuit", "drysuit", "vest", "hood", "gloves", "boots", "bcd",
    "backplate", "wing", "regulator", "rebreather", "computer", "transmitter", "cylinder",
    "light", "scooter", "smb", "mirror", "whistle", "reel", "knife", "line_cutter", "shears",
    "compass", "camera", "other",
  ]
  public static let cylinderMaterials = ["steel", "aluminium", "carbon"]
  public static let contactRoles = [
    "dive_center", "school", "shop", "accommodation", "liveaboard", "club", "other",
  ]
  public static let courseStatuses = [
    "planned", "in_progress", "completed", "incomplete", "provisional", "not_passed",
  ]
  /// A new course's status, the API's default: back-filling a finished course is the common case.
  public static let defaultCourseStatus = "completed"
  public static let certificationAgencies = [
    "padi", "ssi", "naui", "sdi", "tdi", "cmas", "raid", "bsac", "gue", "iantd", "psai", "dan",
    "efr", "andi", "snsi", "acuc", "pss", "ida", "ndl", "utd", "saa", "scotsac", "iac", "protec",
    "pdic", "nase", "sei", "ymca", "erdi", "aida", "molchanovs", "pfi", "apnea_academy", "fii",
    "nss_cds", "nacd", "idea", "diwa", "other",
  ]
}
