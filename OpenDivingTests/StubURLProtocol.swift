import Foundation

/// Answers every request beneath `URLSession`, so the session's own cookie and cache handling
/// runs on the response: a sign-in that sets the refresh cookie, and bytes a private cache
/// may keep for five minutes.
nonisolated final class StubURLProtocol: URLProtocol {
  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url else { return }
    let (headers, body) = Self.answer(url.path)
    let response = HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func answer(_ path: String) -> ([String: String], Data) {
    if path.hasSuffix("/auth/email/verify-code") {
      return (
        [
          "Content-Type": "application/json",
          "Set-Cookie":
            "refresh_token=from-the-wire; HttpOnly; Max-Age=604800; Path=/; SameSite=lax",
        ],
        Data(
          #"{"status":"authenticated","access_token":"access-1","token_type":"bearer"}"#.utf8)
      )
    }
    return (
      [
        "Content-Type": "image/webp", "Cache-Control": "private, max-age=300",
        "ETag": "\"portrait-1\"",
      ],
      Data([0x52, 0x49, 0x46, 0x46])
    )
  }
}
