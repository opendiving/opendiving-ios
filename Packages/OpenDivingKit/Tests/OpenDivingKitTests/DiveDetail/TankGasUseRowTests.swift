import Foundation
import OpenDivingKit
import Testing

/// The web's `tankGasUseRows` cases, `src/lib/dive-gas.test.ts`.
struct TankGasUseRowTests {
  private func mixture(_ gasNumber: Int?, oxygen: Double = 21, role: String? = nil)
    throws -> DiveMixtureRead
  {
    let number = gasNumber.map(String.init) ?? "null"
    let role = role.map { "\"\($0)\"" } ?? "null"
    return try decode(
      #"{"id":1,"volume":12,"start_pressure":200,"end_pressure":50,"oxygen":\#(oxygen),"#
        + #""helium":0,"po2_limit":null,"gas_number":\#(number),"role":\#(role),"usage":null,"#
        + #""gear_item":null}"#)
  }

  private func tank(_ gasNumber: Int, used: Double = 1000) -> String {
    #"{"gas_number":\#(gasNumber),"gas_used":\#(used),"rmv":14,"sac_bar_per_min":1.2,"#
      + #""seconds_on_gas":1200,"mean_depth":18}"#
  }

  private func gasUse(_ tanks: [String]) throws -> DiveGasUse {
    try decode(
      #"{"gas_used":2000,"rmv":14,"sac_bar_per_min":null,"tanks":[\#(tanks.joined(separator: ","))],"#
        + #""attributed_seconds":2400,"duration":2400}"#)
  }

  private func decode<T: Decodable>(_ json: String) throws -> T {
    try APICoding.decoder().decode(T.self, from: Data(json.utf8))
  }

  @Test func emptyForASingleTankDerivation() throws {
    #expect(TankGasUseRow.rows(mixtures: [try mixture(1)], gasUse: try gasUse([])).isEmpty)
    #expect(TankGasUseRow.rows(mixtures: [try mixture(1)], gasUse: nil).isEmpty)
  }

  @Test func joinsEachTankToItsCylinderInTheDivesOrder() throws {
    let rows = TankGasUseRow.rows(
      mixtures: [try mixture(1, role: "bottom"), try mixture(2, oxygen: 50, role: "deco")],
      gasUse: try gasUse([tank(2, used: 400), tank(1)]))
    #expect(rows.map(\.label) == ["1", "2"])
    #expect(rows.map(\.gas) == ["Air", "EAN50"])
    #expect(rows.map(\.role) == ["bottom", "deco"])
    #expect(rows.map(\.use?.gasNumber) == [1, 2])
  }

  @Test func joinsOnGasNumberZero() throws {
    let rows = TankGasUseRow.rows(mixtures: [try mixture(0)], gasUse: try gasUse([tank(0)]))
    #expect(rows.first?.use?.gasNumber == 0)
  }

  @Test func twoCylindersSharingANumberAreBothUnattributed() throws {
    let rows = TankGasUseRow.rows(
      mixtures: [try mixture(1), try mixture(1)], gasUse: try gasUse([tank(1)]))
    #expect(rows.count == 3)
    #expect(rows[0].use == nil && rows[1].use == nil)
    #expect(rows[2].label == "Gas 1")
    #expect(rows[2].use?.gasNumber == 1)
  }

  @Test func twoTanksSharingANumberEachGetARow() throws {
    let rows = TankGasUseRow.rows(
      mixtures: [try mixture(1)], gasUse: try gasUse([tank(1, used: 100), tank(1, used: 50)]))
    #expect(rows[0].use == nil)
    #expect(rows.compactMap(\.use).map(\.gasUsed).reduce(0, +) == 150)
  }

  @Test func everyTankLandsInExactlyOneRow() throws {
    let rows = TankGasUseRow.rows(
      mixtures: [try mixture(0), try mixture(4), try mixture(4), try mixture(nil)],
      gasUse: try gasUse([tank(0), tank(4), tank(9)]))
    #expect(rows.compactMap(\.use).map(\.gasNumber).sorted() == [0, 4, 9])
  }

  @Test func anUnnumberedCylinderIsUnattributed() throws {
    let rows = TankGasUseRow.rows(mixtures: [try mixture(nil)], gasUse: try gasUse([tank(1)]))
    #expect(rows[0].use == nil)
    #expect(rows[1].label == "Gas 1")
  }

  @Test func anUnmatchedTankIsAppended() throws {
    let rows = TankGasUseRow.rows(
      mixtures: [try mixture(1)], gasUse: try gasUse([tank(1), tank(7)]))
    #expect(rows.count == 2)
    #expect(rows[1].label == "Gas 7")
    #expect(rows[1].gas == nil)
    #expect(rows[1].use?.gasNumber == 7)
  }
}
