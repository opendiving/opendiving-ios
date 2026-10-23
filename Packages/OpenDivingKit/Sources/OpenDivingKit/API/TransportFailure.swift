/// Why a request never got an answer: the `URLError` code and its description.
public struct TransportFailure: Hashable, Sendable {
  /// `URLError.Code`'s raw value.
  public let code: Int
  public let message: String

  public init(code: Int, message: String) {
    self.code = code
    self.message = message
  }

  /// App Transport Security refused a plain-http connection — the code is
  /// `URLError.appTransportSecurityRequiresSecureConnection`, which Linux's Foundation lacks.
  public var isRefusedByATS: Bool { code == -1022 }
}
