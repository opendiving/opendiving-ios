/// *Preferences*' units, in the web's words.
public enum UnitsText {
  public static func label(_ system: UnitSystem) -> String {
    switch system {
    case .metric: "Metric (m · °C · bar · kg · L)"
    case .imperial: "Imperial (ft · °F · psi · lb · cuft)"
    }
  }

  public static let description =
    "Applies everywhere at once, on every device you sign in from. Your dives are stored in"
    + " metric whichever you pick, and the data export is metric too — so switching changes what"
    + " you read, never what is recorded."

  public static let entryDescription =
    "While logging a dive you can switch individual fields — depth, pressure, weight and the"
    + " rest — without changing this. Those choices are remembered on this phone only, and"
    + " affect what you type in, not what you read back."
}
