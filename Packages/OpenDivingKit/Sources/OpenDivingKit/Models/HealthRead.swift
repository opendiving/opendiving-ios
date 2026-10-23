/// `GET /health`: the build the instance is running. `commit` reads `unknown` outside an
/// image build.
public struct HealthRead: Codable, Hashable, Sendable {
  public let status: String
  public let version: String
  public let commit: String
  public let message: String?
}
