import Testing

@testable import OpenDivingKit

/// The code folds into an icon of its three eyes and five of its own modules.
struct InviteQRIconTests {
  @Test func fiveDrawnModulesFromTheBottomRightQuarterBecomeTheDots() throws {
    let layout = try #require(InviteQRLayout(matrix: InviteQRLayoutTests.matrix(37)))
    let modules = layout.iconDotModules.compactMap(\.self)
    #expect(modules.count == 5)
    #expect(Set(modules).count == 5)
    for module in modules {
      #expect(layout.isDrawn(row: module.row, column: module.column))
      #expect(module.row >= 18 && module.column >= 18)
    }
  }

  @Test func eachDotTakesTheModuleNearestWhereItSits() throws {
    let layout = try #require(InviteQRLayout(matrix: InviteQRLayoutTests.matrix(37)))
    let modules = layout.iconDotModules
    // The die's far corner falls on the symbol's bottom-right corner, its near one just short of
    // the alignment pattern.
    #expect(modules[4] == .init(row: 34, column: 34))
    #expect(modules[0] == .init(row: 24, column: 24))
  }

  @Test func aQuarterWithNoDrawnModuleLeavesTheDotsUnmatched() throws {
    let layout = try #require(InviteQRLayout(matrix: InviteQRLayoutTests.matrix(37, dark: [])))
    #expect(layout.iconDotModules.allSatisfy { $0 == nil })
  }

  @Test func theDotsFillTheQuarterTheEyesLeave() {
    for dot in InviteQRLayout.iconDots {
      #expect(dot.x >= 1 - InviteQRLayout.iconEyeSide && dot.y >= 1 - InviteQRLayout.iconEyeSide)
      #expect(dot.x + InviteQRLayout.iconDotSide <= 1 && dot.y + InviteQRLayout.iconDotSide <= 1)
    }
  }
}
