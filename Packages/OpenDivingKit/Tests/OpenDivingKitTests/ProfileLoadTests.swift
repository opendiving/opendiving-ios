import Foundation
import OpenDivingKit
import Testing

/// What the chart shows for each answer to `GET /dive/{uuid}/recording/{rid}/profile`.
struct ProfileLoadTests {
  private let dive = UUID()
  private let recording = UUID()

  private func load(_ response: StubTransport.Response) async -> ProfileLoad {
    let harness = ClientHarness(accessToken: "access-1") { _ in response }
    return await ProfileLoad.fetch(dive: dive, recording: recording, from: harness.client)
  }

  @Test func aProfileIsLoaded() async throws {
    let fixture = try KitFixture.text("profile-all-channels")
    let loaded = await load(.json(fixture))
    #expect(
      loaded == .loaded(try KitFixture.decode(RecordingProfileRead.self, "profile-all-channels")))
  }

  /// No *Try again* on a 404: the recording has no profile, said in the API's words.
  @Test func aMissingProfileShowsTheAPIsMessage() async {
    let loaded = await load(.json(#"{"detail":"Recording has no profile"}"#, status: 404))
    #expect(loaded == .missing("Recording has no profile"))
  }

  @Test func anyOtherFailureIsOneToRetry() async {
    #expect(await load(.json(#"{"detail":"Boom"}"#, status: 500)) == .failed("Boom"))
    #expect(await load(.json("not json")) == .failed("The server's answer could not be read."))
  }

  @Test func aSignedOutSessionCannotLoad() async {
    let loaded = await ProfileLoad.fetch(dive: dive, recording: recording, from: nil)
    #expect(loaded == .failed("You are signed out."))
  }

  @Test func asksForTheRecordingItWasGiven() async {
    let harness = ClientHarness(accessToken: "access-1") { _ in .json("{}", status: 404) }
    _ = await ProfileLoad.fetch(dive: dive, recording: recording, from: harness.client)
    #expect(
      harness.transport.requests.map(\.route) == [
        "GET dive/\(dive.uuidString.lowercased())/recording/\(recording.uuidString.lowercased())/profile"
      ])
  }
}
