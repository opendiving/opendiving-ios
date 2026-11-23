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
  /// The Type picker's headings, which the web's flat menu lacks, in the order a diver kits up.
  /// Exposure reads head to toe, a suit before the layers worn with it.
  public static let gearTypeGroups = [
    GearTypeGroup(title: "Basics", types: ["mask", "snorkel", "fins"]),
    GearTypeGroup(
      title: "Exposure",
      types: [
        "hood", "wetsuit", "drysuit", "vest", "undergarment", "gloves", "tech_shorts", "boots",
      ]),
    // The breathing and buoyancy unit alone: what a diver assembles on the cylinder.
    GearTypeGroup(
      title: "SCUBA",
      types: ["bcd", "backplate", "wing", "regulator", "cylinder", "rebreather"]),
    GearTypeGroup(title: "Instruments", types: ["computer", "transmitter", "compass"]),
    GearTypeGroup(
      title: "Safety",
      types: ["smb", "reel", "whistle", "mirror", "knife", "line_cutter", "shears"]),
    GearTypeGroup(title: "Accessories", types: ["light", "slate", "camera", "scooter"]),
    GearTypeGroup(title: nil, types: ["other"]),
  ]
  public static let gearTypes = gearTypeGroups.flatMap(\.types)
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
    "andi", "snsi", "acuc", "pss", "ida", "ndl", "utd", "scotsac", "iac", "protec", "pdic", "nase",
    "sei", "ymca", "erdi", "aida", "molchanovs", "pfi", "apnea_academy", "fii", "nss_cds", "nacd",
    "idea", "diwa", "cdaa", "isc", "ise", "other",
  ]
}
