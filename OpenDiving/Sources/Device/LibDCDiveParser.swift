import Foundation
import LibDiveJSON
import OpenDivingKit

/// One dive's bytes read by `libdivejson`, the shared libdivecomputer reader the server runs over
/// the same bytes, linked against libdc-swift's libdivecomputer. It resolves the parser from the
/// computer's descriptor and returns a DiveJSON dive, which the Kit takes as ``ComputerDive``.
nonisolated enum LibDCDiveParser {
  /// What the reader made of one buffer.
  enum Parsed: Hashable, Sendable {
    case dive(ComputerDive)
    /// The reader refused the buffer, with its reason, and the fingerprint's start where the
    /// family has one.
    case refused(start: ComputerDive.Start?, reason: String)
    /// No samples and no duration: not a dive. On the Nautic family, an empty or aborted
    /// session.
    case empty
  }

  /// Reads `bytes` as a dive of the computer `identity` names. `fallbackStart` is the start the
  /// fingerprint carries, for a family whose dives may have none in their data.
  static func parse(_ bytes: Data, identity: DiveComputerIdentity, fallbackStart: Date?) -> Parsed {
    var error = [CChar](repeating: 0, count: 512)
    let fallback = fallbackStart.map(ComputerDive.instantText)
    let dive: OpaquePointer? = bytes.withUnsafeBytes { buffer in
      identity.vendor.withCString { vendor in
        identity.product.withCString { product in
          withOptionalCString(fallback) { fallback in
            var input = divejson_libdivecomputer_input(
              data: buffer.bindMemory(to: UInt8.self).baseAddress, size: buffer.count,
              vendor: vendor, product: product, model: identity.modelNumber,
              fallback_start: fallback, uuid: nil)
            return divejson_libdivecomputer_read(&input, &error, error.count)
          }
        }
      }
    }
    let refusedStart = fallbackStart.map(ComputerDive.Start.instant)
    guard let dive else {
      let message = error.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
      return .refused(start: refusedStart, reason: String(decoding: message, as: UTF8.self))
    }
    defer { divejson_dive_free(dive) }
    guard let text = divejson_dive_json(dive),
      let read = ComputerDive(
        json: Data(String(cString: text).utf8), logsInstants: identity.family.logsInstants,
        fallbackStart: fallbackStart)
    else {
      return .refused(start: refusedStart, reason: "the reader's dive has no start")
    }
    return read.isEmpty ? .empty : .dive(read)
  }

  /// A Nautic dive's fingerprint is its start as little-endian Unix seconds.
  static func fingerprintStart(_ fingerprint: Data) -> Date? {
    guard fingerprint.count == 4 else { return nil }
    let seconds = fingerprint.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    return Date(timeIntervalSince1970: TimeInterval(seconds))
  }

  private static func withOptionalCString<Result>(
    _ text: String?, _ body: (UnsafePointer<CChar>?) -> Result
  ) -> Result {
    guard let text else { return body(nil) }
    return text.withCString(body)
  }
}
