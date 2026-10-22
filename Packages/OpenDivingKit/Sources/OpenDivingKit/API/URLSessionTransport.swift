import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The device's transport, over a `URLSession` built from the configuration the app target
/// hands in — which is where waiting for connectivity is set, a property Linux's Foundation
/// does not have.
public final class URLSessionTransport: HTTPTransport {
  private let session: URLSession

  /// Copies `configuration` and switches off its cookie handling and its cache: the refresh
  /// token is read off `Set-Cookie` and kept in the ``SecretStore``, and a response cached
  /// outside the per-server directory would survive forgetting the server.
  public init(configuration: URLSessionConfiguration) {
    let configuration = configuration.copy() as! URLSessionConfiguration
    configuration.httpShouldSetCookies = false
    configuration.httpCookieAcceptPolicy = .never
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration)
  }

  public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return (data, http)
  }
}
