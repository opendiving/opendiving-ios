/// A metric value as the string a diver reads in their own units — `"30.52 m"`,
/// `"100 ft"`, `"24°C"` — with the web's constants, decimals and rounding exactly.
///
/// Metric shows up to two decimals with trailing zeros trimmed (whole metres for
/// visibility and altitude); imperial shows ``Measure``'s fixed decimals. A call site's
/// `decimals` coarsens the **metric** rendering only: a whole foot is already finer
/// than a tenth of a metre, so there is nothing left to coarsen on the imperial side.
public enum UnitFormat {
  /// Metres in one international foot, exactly.
  public static let metersPerFoot = 0.3048
  /// Kilograms in one avoirdupois pound, exactly.
  public static let kgPerPound = 0.45359237
  /// Litres in one cubic foot, exactly (0.3048³ m³).
  public static let litersPerCubicFoot = 28.316846592
  /// Pascals in one psi, from the exact pound, standard gravity and inch rather than a
  /// typed-out decimal, which would be a truncated copy.
  public static let pascalsPerPsi = (kgPerPound * 9.80665) / (0.0254 * 0.0254)
  /// Psi in one bar, about 14.5038.
  public static let psiPerBar = 100_000 / pascalsPerPsi
  /// Feet in one international mile.
  public static let feetPerMile = 5280.0

  /// The bare number `metric` shows as in `units`, with no unit after it.
  public static func number(
    _ metric: Double, _ measure: Measure, _ units: UnitSystem, decimals: Int? = nil
  ) -> String {
    let shown = measure.toDisplay(metric, units)
    let places =
      units == .imperial ? measure.imperialDecimals : (decimals ?? measure.metricDecimals)
    guard let places else { return NumberText.plain(NumberText.round(shown, decimals: 2)) }
    return NumberText.fixed(NumberText.round(shown, decimals: places), decimals: places)
  }

  /// A metric value with its unit.
  public static func format(
    _ metric: Double, _ measure: Measure, _ units: UnitSystem, decimals: Int? = nil
  ) -> String {
    number(metric, measure, units, decimals: decimals) + measure.separator + measure.label(units)
  }

  /// A depth in metres, as `"30.52 m"` or `"100 ft"`.
  public static func depth(_ meters: Double, _ units: UnitSystem, decimals: Int? = nil) -> String {
    format(meters, .depth, units, decimals: decimals)
  }

  /// A temperature in Celsius, as `"23.89°C"` or `"75°F"`.
  public static func temperature(
    _ celsius: Double, _ units: UnitSystem, decimals: Int? = nil
  ) -> String {
    format(celsius, .temperature, units, decimals: decimals)
  }

  /// A weight in kilograms, as `"6 kg"` or `"13 lb"`.
  public static func weight(_ kg: Double, _ units: UnitSystem, decimals: Int? = nil) -> String {
    format(kg, .weight, units, decimals: decimals)
  }

  /// A cylinder pressure in bar, as `"206.84 bar"` or `"3000 psi"`.
  public static func pressure(_ bar: Double, _ units: UnitSystem, decimals: Int? = nil) -> String {
    format(bar, .pressure, units, decimals: decimals)
  }

  /// A visibility in metres, whole in both systems.
  public static func visibility(_ meters: Double, _ units: UnitSystem) -> String {
    format(meters, .visibility, units)
  }

  /// An altitude in metres, whole in both systems.
  public static func altitude(_ meters: Double, _ units: UnitSystem) -> String {
    format(meters, .altitude, units)
  }

  /// A surface air consumption in bar/min, as `"0.82 bar/min"` or `"11.9 psi/min"`.
  public static func sac(_ barPerMinute: Double, _ units: UnitSystem, decimals: Int? = nil)
    -> String
  {
    format(barPerMinute, .sac, units, decimals: decimals)
  }

  /// A respiratory minute volume in L/min, as `"18.24 L/min"` or `"0.64 cuft/min"`.
  public static func rmv(_ litersPerMinute: Double, _ units: UnitSystem, decimals: Int? = nil)
    -> String
  {
    format(litersPerMinute, .rmv, units, decimals: decimals)
  }

  /// A volume of gas in litres, as `"3618 L"` or `"127.8 cuft"`.
  public static func gasVolume(_ liters: Double, _ units: UnitSystem, decimals: Int? = nil)
    -> String
  {
    format(liters, .gasVolume, units, decimals: decimals)
  }

  /// A depth at the scale two depths can be told apart at — two metric decimals, a tenth
  /// of a foot — for a MOD and both depths of a MOD warning, where whole feet would put
  /// the same number on both sides of "is past" for a gas breached by centimetres.
  ///
  /// `floor` rounds down, for a value that is itself a limit: a limit rounded up names a
  /// depth past itself. The scaled value is settled to six places before it is floored,
  /// because the scaling is inexact (`9.2 × 100` is 919.9999999999999).
  public static func comparableDepth(_ meters: Double, _ units: UnitSystem, floor: Bool = false)
    -> String
  {
    let shown = Measure.depth.toDisplay(meters, units)
    let places = units == .imperial ? 1 : 2
    let value: Double
    if floor {
      let factor = NumberText.powerOfTen(places)
      value = NumberText.round(shown * factor, decimals: 6).rounded(.down) / factor
    } else {
      value = NumberText.round(shown, decimals: places)
    }
    return NumberText.plain(value) + Measure.depth.separator + Measure.depth.label(units)
  }
}
