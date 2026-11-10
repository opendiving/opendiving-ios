import Foundation
import Synchronization

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

  /// The configuration the session runs with, after the overrides above; for the tests.
  var effectiveConfiguration: URLSessionConfiguration {
    session.configuration
  }

  public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }
    return (data, http)
  }

  public func upload(_ request: URLRequest, fromFile file: URL) async throws
    -> (Data, HTTPURLResponse)
  {
    // The completion-handler task rather than `upload(for:fromFile:)`, which Linux's
    // Foundation does not have; cancelling the caller cancels the task.
    let box = TaskBox()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let task = session.uploadTask(with: request, fromFile: file) { data, response, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let http = response as? HTTPURLResponse {
            continuation.resume(returning: (data ?? Data(), http))
          } else {
            continuation.resume(throwing: URLError(.badServerResponse))
          }
        }
        box.start(task)
      }
    } onCancel: {
      box.cancel()
    }
  }

  public func download(_ request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    // The completion-handler task, as for the upload.
    let box = TaskBox()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let task = session.downloadTask(with: request) { location, response, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }
          guard let location, let http = response as? HTTPURLResponse else {
            continuation.resume(throwing: URLError(.badServerResponse))
            return
          }
          // The system removes its file once this handler returns.
          let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("download-\(UUID().uuidString)")
          do {
            try FileManager.default.moveItem(at: location, to: file)
            continuation.resume(returning: (file, http))
          } catch {
            continuation.resume(throwing: error)
          }
        }
        box.start(task)
      }
    } onCancel: {
      box.cancel()
    }
  }
}

/// The task, handed from the continuation to the cancellation handler, which may run on another
/// thread and before the task exists.
private final class TaskBox: Sendable {
  private let state = Mutex<(task: URLSessionTask?, cancelled: Bool)>((nil, false))

  func start(_ task: URLSessionTask) {
    let cancelled = state.withLock { state in
      state.task = task
      return state.cancelled
    }
    cancelled ? task.cancel() : task.resume()
  }

  func cancel() {
    state.withLock { state in
      state.cancelled = true
      return state.task
    }?.cancel()
  }
}
