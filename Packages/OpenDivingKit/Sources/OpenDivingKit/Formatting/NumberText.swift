/// Numbers written exactly as the web writes them: `String(n)`, `n.toFixed(d)` and
/// `Math.round`. Swift's own spellings differ on every one — `"\(28.0)"` is `"28.0"`,
/// `%.0f` rounds a tie to even, `rounded()` sends `-2.5` away from zero — and each
/// difference is a figure that disagrees with the web while looking right. Nothing here
/// reads a `Locale`, so a phone set to another region prints the same digits.
public enum NumberText {
  /// `String(value)`: the shortest digits that read back as the same double, with no
  /// trailing zeros — `"28"`, `"30.52"`, `"0.000001"` — and exponent notation below a
  /// millionth (`"5e-7"`).
  public static func plain(_ value: Double) -> String {
    if value.isNaN { return "NaN" }
    if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
    if value == 0 { return "0" }

    let (digits, exponent) = shortestDigits(of: value.magnitude)
    let sign = value < 0 ? "-" : ""
    let count = digits.count

    // ECMAScript's Number::toString, `exponent` being its n: value = 0.digits × 10^n.
    if count <= exponent && exponent <= 21 {
      return sign + digits + String(repeating: "0", count: exponent - count)
    }
    if 0 < exponent && exponent <= 21 {
      return sign + digits.prefix(exponent) + "." + digits.dropFirst(exponent)
    }
    if -6 < exponent && exponent <= 0 {
      return sign + "0." + String(repeating: "0", count: -exponent) + digits
    }
    let power = exponent - 1
    let mantissa = count == 1 ? digits : digits.prefix(1) + "." + digits.dropFirst()
    return sign + mantissa + "e" + (power < 0 ? "-" : "+") + String(power.magnitude)
  }

  /// `value.toFixed(decimals)`: the exact binary value rounded half up at `decimals`
  /// places, a negative value keeping its sign when it rounds to zero (`"-0"`).
  public static func fixed(_ value: Double, decimals: Int) -> String {
    precondition((0...20).contains(decimals), "toFixed takes 0 to 20 decimals")
    if !value.isFinite || value.magnitude >= 1e21 { return plain(value) }

    var digits = String(nearestScaledInteger(value.magnitude, decimals: decimals))
    if digits.count <= decimals {
      digits = String(repeating: "0", count: decimals + 1 - digits.count) + digits
    }
    let sign = value < 0 ? "-" : ""
    guard decimals > 0 else { return sign + digits }
    return sign + digits.dropLast(decimals) + "." + digits.suffix(decimals)
  }

  /// `Math.round`: the nearest integer, a tie going towards positive infinity, so
  /// `-2.5` is `-2`.
  public static func round(_ value: Double) -> Double {
    let floor = value.rounded(.down)
    // Exact: a double minus its own floor is always representable.
    return value - floor >= 0.5 ? floor + 1 : floor
  }

  /// `Math.round(value × 10^decimals) / 10^decimals`, the web's `roundTo`.
  public static func round(_ value: Double, decimals: Int) -> Double {
    let factor = powerOfTen(decimals)
    return round(value * factor) / factor
  }

  /// `10^exponent`, exact for every exponent asked of it here: a double holds the powers
  /// of ten exactly up to 10^22.
  static func powerOfTen(_ exponent: Int) -> Double {
    var result = 1.0
    for _ in 0..<exponent { result *= 10 }
    return result
  }

  /// The integer nearest the exact product `value × 10^decimals`, ties up. The product is
  /// split into its rounded double and the exact error of that rounding, so 1.005, whose
  /// double sits just under the tie, is not carried over it.
  private static func nearestScaledInteger(_ value: Double, decimals: Int) -> Int {
    let factor = powerOfTen(decimals)
    let high = value * factor
    let low = (-high).addingProduct(value, factor)
    let floor = high.rounded(.down)
    let remainder = high - floor
    return Int(floor) + (remainder - 0.5 >= -low ? 1 : 0)
  }

  /// The shortest round-tripping digits of a positive finite double, and where the
  /// decimal point sits relative to them, read off Swift's own shortest representation.
  private static func shortestDigits(of value: Double) -> (digits: String, exponent: Int) {
    let text = value.description
    let parts = text.split(separator: "e", maxSplits: 1)
    var power = 0
    if parts.count > 1 {
      let written = parts[1]
      power = Int(written.first == "+" ? written.dropFirst() : written) ?? 0
    }

    let pieces = parts[0].split(separator: ".", omittingEmptySubsequences: false)
    let whole = pieces[0]
    var digits = Substring(whole + (pieces.count > 1 ? pieces[1] : ""))
    var point = whole.count + power

    while digits.first == "0" {
      digits = digits.dropFirst()
      point -= 1
    }
    while digits.last == "0" { digits = digits.dropLast() }
    return (String(digits), point)
  }
}
