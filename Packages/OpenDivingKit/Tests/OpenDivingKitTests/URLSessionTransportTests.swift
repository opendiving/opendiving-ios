import Foundation
import Testing

@testable import OpenDivingKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The cookie jar and the cache are off whatever configuration the app hands in: the
/// refresh token must exist only in the ``SecretStore``, and nothing may be cached outside
/// the per-server directory that `forget` removes.
struct URLSessionTransportTests {
  @Test func switchesOffCookiesAndTheCacheOnTheConfigurationItRunsWith() {
    let handedIn = URLSessionConfiguration.default
    handedIn.httpShouldSetCookies = true
    handedIn.httpCookieAcceptPolicy = .always
    handedIn.urlCache = URLCache.shared
    handedIn.requestCachePolicy = .useProtocolCachePolicy

    let configuration = URLSessionTransport(configuration: handedIn).effectiveConfiguration

    #expect(configuration.httpShouldSetCookies == false)
    #expect(configuration.httpCookieAcceptPolicy == .never)
    #expect(configuration.urlCache == nil)
    #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
  }

  @Test func leavesTheConfigurationItWasHandedAlone() {
    let handedIn = URLSessionConfiguration.default
    handedIn.httpShouldSetCookies = true
    _ = URLSessionTransport(configuration: handedIn)
    #expect(handedIn.httpShouldSetCookies)
  }
}
