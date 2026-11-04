import Foundation
import Testing

@testable import OpenDivingKit

struct NauticLoggedZoneTests {
  private func bytes(_ hex: String) -> Data {
    Data("SBEM0103".utf8) + [0x01, 0x08]
      + stride(from: 0, to: hex.count, by: 2).map { at -> UInt8 in
        let start = hex.index(hex.startIndex, offsetBy: at)
        return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
      }
  }

  private func offset(_ hex: String, at seconds: TimeInterval) -> Int? {
    NauticLoggedZone.zone(in: bytes(hex), at: Date(timeIntervalSince1970: seconds))?
      .secondsFromGMT()
  }

  /// Two Ocean dives in Egypt either side of the end of its summer time, and a Nautic S in
  /// Sweden, as each watch logged them.
  @Test func theOffsetIsTheOneTheWatchLogged() {
    #expect(offset("3265bb78a101000c", at: 1_793_016_109) == 3 * 3600)
    #expect(offset("30b86091a1010008", at: 1_793_433_197) == 2 * 3600)
    #expect(offset("bcecc13ea0010008", at: 1_787_752_091) == 2 * 3600)
  }

  @Test func westOfUTCIsANegativeByte() {
    let local = UInt64(1_793_016_109 - 5 * 3600) * 1000
    let clock = (0..<7).map { String(format: "%02x", UInt8(local >> (8 * UInt64($0)) & 0xFF)) }
    #expect(offset(clock.joined() + "ec", at: 1_793_016_109) == -5 * 3600)
  }

  @Test func aClockThatIsNotTheDivesStartGivesNoZone() {
    #expect(offset("3265bb78a101000c", at: 1_793_016_109 + 3600) == nil)
    #expect(offset("3265bb78a10100f4", at: 1_793_016_109) == nil)
  }

  @Test func bytesWithoutTheBaseGiveNoZone() {
    let instant = Date(timeIntervalSince1970: 1_793_016_109)
    #expect(NauticLoggedZone.zone(in: Data("perdix dive".utf8), at: instant) == nil)
    #expect(NauticLoggedZone.zone(in: bytes("3265"), at: instant) == nil)
    #expect(NauticLoggedZone.zone(in: Data(), at: instant) == nil)
  }
}
