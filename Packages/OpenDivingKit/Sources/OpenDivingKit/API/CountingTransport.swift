import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Counts each request it sends on ``RequestActivity`` until its answer, or its failure, is in.
struct CountingTransport: HTTPTransport {
  let base: any HTTPTransport
  let activity: RequestActivity

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    await activity.begin()
    do {
      let answer = try await base.send(request)
      await activity.end()
      return answer
    } catch {
      await activity.end()
      throw error
    }
  }

  func upload(_ request: URLRequest, fromFile file: URL) async throws -> (Data, HTTPURLResponse) {
    try await base.upload(request, fromFile: file)
  }

  func download(_ request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    try await base.download(request)
  }
}
