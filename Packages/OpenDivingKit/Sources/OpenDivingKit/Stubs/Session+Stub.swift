import Foundation

extension Session {
  /// A session signed in to `origin` over `transport`, with nothing of the device behind it —
  /// for the app bundle's tests and for previews, which cannot reach the Kit's own test
  /// helpers. `transport` answers `GET user` and `GET people` for ``loadAccount()``.
  public static func stub(
    origin: ServerOrigin = ServerOrigin("https://stub.opendiving.invalid")!,
    transport: any HTTPTransport
  ) -> Session {
    Session(
      transport: transport,
      secrets: InMemorySecretStore([origin.description: "stub-refresh-token"]),
      activeOrigin: InMemoryActiveOriginStore(origin),
      background: NoBackgroundExecution(),
      applicationSupport: FileManager.default.temporaryDirectory
        .appendingPathComponent("OpenDivingStub-\(UUID().uuidString)", isDirectory: true),
      userAgent: UserAgent(appVersion: "0", systemVersion: "0", model: "iPhone"),
      accessToken: "stub-access-token")
  }
}
