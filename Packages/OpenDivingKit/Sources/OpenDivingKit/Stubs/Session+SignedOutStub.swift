import Foundation

extension Session {
  /// A session with no sign-in over `transport`: pointed at `origin` and signing in there, or at
  /// no server when it is nil — for previews and the app bundle's tests of the signed-out
  /// screens. `secrets` holds whatever the phone is to have kept.
  public static func signedOutStub(
    origin: ServerOrigin? = ServerOrigin("https://stub.opendiving.invalid")!,
    transport: any HTTPTransport,
    secrets: InMemorySecretStore = InMemorySecretStore()
  ) -> Session {
    Session(
      transport: transport,
      secrets: secrets,
      activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("OpenDivingStub-\(UUID().uuidString)", isDirectory: true),
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"))
  }
}
