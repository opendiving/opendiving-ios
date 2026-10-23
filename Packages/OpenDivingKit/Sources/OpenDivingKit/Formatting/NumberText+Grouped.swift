extension NumberText {
  /// `n.toLocaleString()` as an `en-US` reader sees it: commas between groups of three,
  /// `"3,600"`, `"-1,200"`.
  public static func grouped(_ n: Int) -> String {
    var digits = Array(String(n.magnitude))
    var index = digits.count - 3
    while index > 0 {
      digits.insert(",", at: index)
      index -= 3
    }
    return (n < 0 ? "-" : "") + String(digits)
  }
}
