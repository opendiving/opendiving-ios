/// libdivecomputer's ERROR and WARN lines from a Suunto Nautic-family link, read for another app on
/// it: the library logs another app's traffic only as packets it skips or as a stream it could not
/// close.
public enum NauticLinkLog {
  /// Whether `message` shows another app's handshake breaking the link: the watch's hello reply
  /// to a handshake the walk never sent, opcode `0x13`, or a stream whose unsubscribe answered
  /// 404 because the watch dropped it, which a handshake that garbled a frame leaves with no
  /// hello line of its own. A line it cannot read shows none.
  public static func showsOtherApp(_ message: String) -> Bool {
    if let hello = message.range(of: "Skipping an unexpected packet (13 ") {
      let rest = message[hello.upperBound...]
      guard let close = rest.firstIndex(of: ")") else { return false }
      let sequence = rest[..<close]
      return !sequence.isEmpty && sequence.allSatisfy { $0.isASCII && $0.isNumber }
    }
    guard let unsubscribe = message.range(of: "Failed to unsubscribe from ") else { return false }
    return message[unsubscribe.upperBound...].contains(" (status 404).")
  }
}
