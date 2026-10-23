extension ServerOrigin {
  /// Whether the connection to this server is encrypted.
  public var isEncrypted: Bool { scheme == "https" }

  /// Whether the host is one iOS's local-network privacy gates: a `.local` name, a name with no
  /// dot, or a private, link-local or unique-local address. Loopback is the phone itself and is
  /// not gated.
  public var isLocalNetwork: Bool {
    if host.hasSuffix(".local") { return true }
    if let octets = Self.ipv4(host) {
      switch (octets[0], octets[1]) {
      case (10, _), (192, 168), (169, 254): return true
      case (172, let second): return (16...31).contains(second)
      default: return false
      }
    }
    if host.contains(":") {
      let first = host.split(separator: ":", omittingEmptySubsequences: false).first ?? ""
      guard let group = UInt16(first, radix: 16) else { return false }
      // fe80::/10 is link-local, fc00::/7 unique-local.
      return group & 0xffc0 == 0xfe80 || group & 0xfe00 == 0xfc00
    }
    return !host.contains(".")
  }

  private static func ipv4(_ host: String) -> [Int]? {
    let parts = host.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return nil }
    let octets = parts.compactMap { Int($0) }.filter { (0...255).contains($0) }
    return octets.count == 4 ? octets : nil
  }
}
