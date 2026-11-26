import Foundation

/// `POST /auth/passkey/verify`'s body: the flow the options were stored under, the assertion,
/// and the window of the session it starts.
public struct PasskeySignInVerifyRequest: Codable, Hashable, Sendable {
  public let flowId: String
  public let credential: PasskeyCredential
  public let idleTimeout: IdleTimeout

  public init(flowId: String, credential: PasskeyCredential, idleTimeout: IdleTimeout) {
    self.flowId = flowId
    self.credential = credential
    self.idleTimeout = idleTimeout
  }

  enum CodingKeys: String, CodingKey {
    case flowId = "flow_id"
    case credential
    case idleTimeout = "idle_timeout"
  }

  /// The body as sent: with the credential's members as WebAuthn spells them.
  public func body() throws -> Data {
    try PasskeyCredential.encoder.encode(self)
  }
}

extension PasskeyCredential {
  /// No key strategy: the keys are each body's own.
  static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}
