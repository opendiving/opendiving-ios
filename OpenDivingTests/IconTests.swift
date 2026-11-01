import OpenDivingKit
import Testing
import UIKit

@testable import OpenDiving

/// The Kit names the symbols and the asset catalog holds them; both are generated together,
/// and this catches one written without the other.
struct IconTests {
  @Test(arguments: Icon.allCases)
  func everyIconIsASymbolInTheCatalog(icon: Icon) throws {
    let image = try #require(UIImage(named: icon.rawValue))
    #expect(image.isSymbolImage)
  }
}
