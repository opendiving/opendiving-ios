/// The thirteen classified markers a profile's `events[].type` can name. An event the
/// device recorded with no classification arrives with `type: null` and its own
/// `label`; a type this build has never heard of is treated the same way, never as one
/// of these.
public enum ProfileEventKind: String, Sendable, Hashable, CaseIterable {
  case gasSwitch = "gas_switch"
  case deepStop = "deep_stop"
  case safetyStop = "safety_stop"
  case bookmark
  case ascentRate = "ascent_rate"
  case safetyStopMandatory = "safety_stop_mandatory"
  case safetyStopViolation = "safety_stop_violation"
  case deepStopViolation = "deep_stop_violation"
  case ceilingViolation = "ceiling_violation"
  case ndlReached = "ndl_reached"
  case ppo2High = "ppo2_high"
  case pressureLow = "pressure_low"
  case depthAlarm = "depth_alarm"

  /// What the marker says for every kind whose sentence needs nothing but its kind; nil
  /// for a gas switch, which names its cylinder.
  var sentence: String? {
    switch self {
    case .gasSwitch: nil
    case .deepStop: "Deep stop"
    case .safetyStop: "Safety stop"
    case .bookmark: "Bookmark"
    case .ascentRate: "Ascent rate"
    case .safetyStopMandatory: "Mandatory safety stop"
    case .safetyStopViolation: "Safety stop broken"
    case .deepStopViolation: "Deep stop broken"
    case .ceilingViolation: "Deco ceiling broken"
    case .ndlReached: "No-deco limit reached"
    case .ppo2High: "ppO₂ high"
    case .pressureLow: "Tank pressure low"
    case .depthAlarm: "Depth alarm"
    }
  }
}
