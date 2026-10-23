/// Everything a call to the server can fail with.
public enum APIError: Error, Hashable, Sendable {
  /// No answer arrived: no route to the host, a refused connection, a timeout, ATS.
  case unreachable(TransportFailure)
  /// The server answered, but `GET /config` was not an OpenDiving instance's.
  case notAnInstance
  /// The server answered with an error status. `message` is the API's `detail` sentence,
  /// which is shown as it is and never branched on.
  case http(status: Int, message: String?)
  /// The session is over: there is no refresh token, or the server refused it. Nothing was
  /// sent that could have changed that.
  case signedOut
  /// A success status whose body this version could not read.
  case unreadableResponse(String)
  /// The phone's own store for the refresh token failed; nothing about the session changed.
  case secretStore(String)

  /// One sentence to put in front of the user.
  public var message: String {
    switch self {
    case .unreachable(let failure):
      return failure.message
    case .notAnInstance:
      return "This server is not an OpenDiving instance."
    case .http(let status, let message):
      return message ?? "The server answered \(status)."
    case .signedOut:
      return "You are signed out."
    case .unreadableResponse:
      return "The server's answer could not be read."
    case .secretStore:
      return "The sign-in could not be read from this phone's keychain."
    }
  }

  /// Any error a call threw, as an `APIError`.
  public init(_ error: any Error) {
    if let error = error as? APIError {
      self = error
    } else {
      self = .unreadableResponse(String(describing: error))
    }
  }
}
