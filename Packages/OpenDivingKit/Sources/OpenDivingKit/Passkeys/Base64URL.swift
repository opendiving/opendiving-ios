import Foundation

/// WebAuthn's spelling of bytes: base64url, which the specification writes without padding.
public enum Base64URL {
  /// Unpadded, as every member of a credential's JSON is.
  public static func encode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// Padded or not, since the specification does not pad and a server may; nil for anything
  /// that is not base64url.
  public static func decode(_ text: String) -> Data? {
    guard !text.contains("+"), !text.contains("/") else { return nil }
    var base64 = text.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    if base64.count % 4 != 0 {
      base64 += String(repeating: "=", count: 4 - base64.count % 4)
    }
    return Data(base64Encoded: base64)
  }
}
