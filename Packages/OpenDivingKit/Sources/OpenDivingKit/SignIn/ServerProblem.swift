/// Why the server screen could not move on to signing in, as the sentence it shows.
public enum ServerProblem: Hashable, Sendable {
  /// Nothing an http or https origin can be read out of.
  case unreadableAddress
  /// No answer arrived. `localNetwork` says whether the address is one the Local Network
  /// permission gates, where a denied permission looks exactly like this.
  case unreachable(TransportFailure, localNetwork: Bool)
  /// App Transport Security refused a plain-http connection to a hostname.
  case refusedByATS
  /// The server answered, and not as an OpenDiving instance.
  case notAnInstance
  case failed(String)

  public init(_ error: APIError, origin: ServerOrigin) {
    switch error {
    case .unreachable(let failure) where failure.isRefusedByATS:
      self = .refusedByATS
    case .unreachable(let failure):
      self = .unreachable(failure, localNetwork: origin.isLocalNetwork)
    case .notAnInstance:
      self = .notAnInstance
    default:
      self = .failed(error.message)
    }
  }

  public var message: String {
    switch self {
    case .unreadableAddress:
      return "Enter a server address, such as https://opendiving.app."
    case .unreachable(let failure, let localNetwork):
      let reached = "The server could not be reached: \(failure.message)"
      guard localNetwork else { return reached }
      return reached
        + " If it is on your local network, check that OpenDiving is allowed in Settings"
        + " → Privacy & Security → Local Network."
    case .refusedByATS:
      return "In this version, plain http works only for a LAN address or a .local name."
        + " Use https for this server."
    case .notAnInstance:
      return APIError.notAnInstance.message
    case .failed(let message):
      return message
    }
  }
}
