import Testing

@testable import OpenDivingKit

struct LaunchArgumentsTests {
  @Test func theWalksArgumentIsReadAfterThePath() {
    #expect(LaunchArguments(["/OpenDiving", "--end-in-background"]).endsInBackground)
    #expect(!LaunchArguments(["/OpenDiving"]).endsInBackground)
    #expect(!LaunchArguments(["--end-in-background"]).endsInBackground)
  }

  @Test func aSignInIsAServerAndATokenTogether() {
    let arguments = LaunchArguments([
      "/OpenDiving", "--server", "http://localhost:8000/", "--refresh-token", "refresh-0",
    ])
    #expect(
      arguments.signIn
        == LaunchSignIn(origin: ServerOrigin("http://localhost:8000")!, refreshToken: "refresh-0"))
    #expect(LaunchArguments(["/OpenDiving", "--server", "http://localhost:8000"]).signIn == nil)
    #expect(LaunchArguments(["/OpenDiving", "--refresh-token", "refresh-0"]).signIn == nil)
    #expect(
      LaunchArguments(["/OpenDiving", "--server", "ftp://x", "--refresh-token", "r"]).signIn == nil)
    #expect(
      LaunchArguments(["/OpenDiving", "--refresh-token", "r", "--server"]).signIn == nil)
  }
}
