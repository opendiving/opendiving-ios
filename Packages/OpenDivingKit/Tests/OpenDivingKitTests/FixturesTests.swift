import Foundation
import Testing

struct FixturesTests {
  // The directory later fixtures land in has to reach the bundle before any of them exist.
  @Test func fixturesDirectoryIsCopiedIntoTheTestBundle() {
    #expect(
      Bundle.module.url(forResource: "README", withExtension: "md", subdirectory: "Fixtures")
        != nil)
  }
}
