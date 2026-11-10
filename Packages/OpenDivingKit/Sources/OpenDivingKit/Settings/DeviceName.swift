/// What a signed-in session's row calls its device, read from the raw `User-Agent` the server
/// stored: the web's reading, table for table, so one browser is never named two ways by the
/// web and the phone. A coarse read on purpose — a wrong but plausible label costs nothing, and
/// an unreadable one falls back to a label rather than an error.
public enum DeviceName {
  /// "Chrome on macOS", or the device alone on iOS, where every browser is the same engine.
  public static func forUserAgent(_ userAgent: String) -> String {
    let platform = firstMatch(platforms, userAgent)
    let browser = firstMatch(browsers, userAgent)
    if let platform, platform == "iPhone" || platform == "iPad" { return platform }
    if let browser, let platform { return "\(browser) on \(platform)" }
    return browser ?? platform ?? "Unknown device"
  }

  // Order matters in both tables: every Chromium browser says "Chrome", and Chrome on iOS
  // says "Safari" as well, so the specific token is looked for before the generic one.
  private static var browsers: [(Regex<Substring>, String)] {
    [
      (#/\bEdg[A-Za-z]*\//#, "Edge"),
      (#/\bOPR\/|\bOpera[\s\/]/#, "Opera"),
      (#/\bSamsungBrowser\//#, "Samsung Internet"),
      (#/\bCriOS\//#, "Chrome"),
      (#/\bFxiOS\//#, "Firefox"),
      (#/\bChrome\//#, "Chrome"),
      (#/\bFirefox\//#, "Firefox"),
      (#/\bSafari\//#, "Safari"),
    ]
  }

  private static var platforms: [(Regex<Substring>, String)] {
    [
      (#/\bCrOS\b/#, "ChromeOS"),
      (#/\bAndroid\b/#, "Android"),
      (#/\biPhone\b/#, "iPhone"),
      (#/\biPad\b/#, "iPad"),
      (#/\bWindows\b/#, "Windows"),
      // After the two iOS devices: an iPad in desktop mode reports itself as a Mac.
      (#/\bMac OS X\b|\bMacintosh\b/#, "macOS"),
      (#/\bLinux\b/#, "Linux"),
    ]
  }

  private static func firstMatch(_ table: [(Regex<Substring>, String)], _ userAgent: String)
    -> String?
  {
    // JavaScript's `\b`, between a word character and anything else, rather than Unicode's
    // default word boundaries.
    table.first { pattern, _ in
      userAgent.contains(pattern.wordBoundaryKind(.simple))
    }?.1
  }
}
