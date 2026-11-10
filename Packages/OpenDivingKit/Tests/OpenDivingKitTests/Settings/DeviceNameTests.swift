import OpenDivingKit
import Testing

/// The web's reading of a session's `User-Agent`, case for case: every string the web's tests
/// read through its session label lands on the same name here.
struct DeviceNameTests {
  // Real strings, as the web's tests have them: the risk is in the tokens browsers share.
  private static let named: [(String, String)] = [
    (
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " Chrome/140.0.0.0 Safari/537.36", "Chrome on macOS"
    ),
    (
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
        + " Version/18.3 Safari/605.1.15", "Safari on macOS"
    ),
    (
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0", "Edge on Windows"
    ),
    (
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " Chrome/140.0.0.0 Safari/537.36 OPR/125.0.0.0", "Opera on Windows"
    ),
    (
      "Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0",
      "Firefox on Linux"
    ),
    (
      "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " Chrome/140.0.0.0 Mobile Safari/537.36", "Chrome on Android"
    ),
    (
      "Mozilla/5.0 (Linux; Android 15; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " SamsungBrowser/27.0 Chrome/125.0.0.0 Mobile Safari/537.36",
      "Samsung Internet on Android"
    ),
    (
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like"
        + " Gecko) Version/18.3 Mobile/15E148 Safari/604.1", "iPhone"
    ),
    (
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like"
        + " Gecko) CriOS/140.0.0.0 Mobile/15E148 Safari/604.1", "iPhone"
    ),
    (
      "Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko)"
        + " Chrome/140.0.0.0 Safari/537.36", "Chrome on ChromeOS"
    ),
  ]

  @Test(arguments: named)
  func namesTheBrowserAndThePlatformAsTheWebDoes(_ userAgent: String, _ name: String) {
    #expect(DeviceName.forUserAgent(userAgent) == name)
  }

  @Test func namesWhicheverHalfItRecognises() {
    #expect(DeviceName.forUserAgent("Mozilla/5.0 (Windows NT 10.0)") == "Windows")
    #expect(DeviceName.forUserAgent("Firefox/135.0") == "Firefox")
  }

  @Test(arguments: ["curl/8.7.1", ""])
  func fallsBackToADeviceShapedLabel(_ userAgent: String) {
    #expect(DeviceName.forUserAgent(userAgent) == "Unknown device")
  }

  @Test func thisAppIsNamedAsThePhoneItRunsOn() {
    let header = UserAgent(appVersion: "1.4", systemVersion: "18.6", model: "iPhone").headerValue
    #expect(DeviceName.forUserAgent(header) == "iPhone")
  }
}
