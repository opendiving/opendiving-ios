import Foundation
import Testing

@testable import OpenDivingKit

struct ConnectQRLayoutTests {
  static func matrix(_ size: Int, dark: Set<ConnectQRLayout.Module>? = nil) -> [[Bool]] {
    (0..<size).map { row in
      (0..<size).map { dark?.contains(.init(row: row, column: $0)) ?? true }
    }
  }

  @Test func aSizeThatIsNoQRCodeHasNoLayout() {
    #expect(ConnectQRLayout(matrix: Self.matrix(22)) == nil)
    #expect(ConnectQRLayout(matrix: Self.matrix(17)) == nil)
    #expect(ConnectQRLayout(matrix: Array(Self.matrix(21).dropLast())) == nil)
  }

  @Test func versionFivePlacesTheMarkAtTheCentre() throws {
    let layout = try #require(ConnectQRLayout(matrix: Self.matrix(37)))
    #expect(layout.version == 5)
    #expect(
      layout.finders == [
        .init(row: 0, column: 0), .init(row: 0, column: 30), .init(row: 30, column: 0),
      ])
    #expect(layout.alignments == [.init(row: 30, column: 30)])
    let mark = try #require(layout.mark)
    #expect(abs(mark.offset - 13.992) < 1e-9)
    #expect(abs(mark.scale - 9.016 / 24) < 1e-12)
  }

  @Test func patternsAreNotDrawnAsModules() throws {
    let layout = try #require(ConnectQRLayout(matrix: Self.matrix(37)))
    for (row, column) in [(0, 0), (6, 6), (0, 36), (36, 6), (28, 28), (32, 30)] {
      #expect(!layout.isDrawn(row: row, column: column))
    }
    for (row, column) in [(7, 7), (27, 27), (36, 36), (6, 20)] {
      #expect(layout.isDrawn(row: row, column: column))
    }
    #expect(!layout.isDrawn(row: -1, column: 10))
    #expect(!layout.isDrawn(row: 10, column: 37))
  }

  @Test func onlyTheModulesNearABubbleGiveWay() throws {
    let layout = try #require(ConnectQRLayout(matrix: Self.matrix(37)))
    // Under the large, the middle and the small bubble.
    #expect(!layout.isDrawn(row: 16, column: 20))
    #expect(!layout.isDrawn(row: 19, column: 18))
    #expect(!layout.isDrawn(row: 21, column: 15))
    // The empty corners of the mark's diagonal keep their data.
    #expect(layout.isDrawn(row: 13, column: 23))
    #expect(layout.isDrawn(row: 23, column: 13))
  }

  @Test func theFormatInformationNeverGivesWay() throws {
    // At version 1 the large bubble's gap reaches the format information beside it.
    let layout = try #require(ConnectQRLayout(matrix: Self.matrix(21)))
    #expect(!layout.isDrawn(row: 9, column: 12))
    #expect(layout.isDrawn(row: 8, column: 13))
  }

  @Test func fromVersionSevenTheCentreIsAnAlignmentPatternAndHasNoMark() throws {
    let layout = try #require(ConnectQRLayout(matrix: Self.matrix(45)))
    #expect(layout.mark == nil)
    #expect(layout.alignments.count == 6)
    #expect(layout.alignments.contains(.init(row: 22, column: 22)))
    #expect(!layout.isDrawn(row: 20, column: 20))
    #expect(layout.isDrawn(row: 19, column: 19))
  }

  @Test func alignmentCentresFollowTheStandardsTable() {
    func line(_ version: Int) -> [Int] {
      let size = 4 * version + 17
      let centres = ConnectQRLayout.alignmentCentres(version: version, size: size)
      return Array(Set(centres.flatMap { [$0.row, $0.column] })).sorted()
    }
    #expect(ConnectQRLayout.alignmentCentres(version: 1, size: 21).isEmpty)
    #expect(ConnectQRLayout.alignmentCentres(version: 2, size: 25) == [.init(row: 18, column: 18)])
    #expect(line(7) == [6, 22, 38])
    #expect(line(14) == [6, 26, 46, 66])
    #expect(line(32) == [6, 34, 60, 86, 112, 138])
    #expect(line(36) == [6, 24, 50, 76, 102, 128, 154])
    #expect(ConnectQRLayout.alignmentCentres(version: 7, size: 45).count == 6)
  }

  @Test func aModuleRoundsOnlyWhereNothingDrawnMeetsIt() throws {
    let lone = ConnectQRLayout.Module(row: 10, column: 2)
    let pair = [ConnectQRLayout.Module(row: 10, column: 15), .init(row: 10, column: 16)]
    let layout = try #require(
      ConnectQRLayout(matrix: Self.matrix(21, dark: Set([lone] + pair))))
    #expect(
      layout.roundedCorners(row: 10, column: 2) == [.topLeft, .topRight, .bottomRight, .bottomLeft])
    #expect(layout.roundedCorners(row: 10, column: 15) == [.topLeft, .bottomLeft])
    #expect(layout.roundedCorners(row: 10, column: 16) == [.topRight, .bottomRight])
    #expect(layout.drawnModules == [lone] + pair)
  }
}
