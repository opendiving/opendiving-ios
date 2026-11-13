import Testing

@testable import OpenDivingKit

struct LaunchArgumentsTests {
  @Test func theWalksArgumentIsReadAfterThePath() {
    #expect(LaunchArguments(["/OpenDiving", "--end-in-background"]).endsInBackground)
    #expect(!LaunchArguments(["/OpenDiving"]).endsInBackground)
    #expect(!LaunchArguments(["--end-in-background"]).endsInBackground)
  }
}
