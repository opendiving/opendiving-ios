import Foundation
import OpenDivingKit

/// The Kit's ``ServerWake`` over a background session: one request for the server's health,
/// which names no account and carries no dive, and which iOS completes once there is a route —
/// relaunching the app if it has ended. Its session is made at launch, so a relaunch for its
/// events finds it.
final class BackgroundSessionServerWake: NSObject, ServerWake {
  static let identifier = "app.opendiving.server-wake"

  /// The request completed: the app has a route to try the upload on, and returns once it has.
  var onWake: (() async -> Void)?
  /// iOS's handler for a relaunch to deliver the session's events, called once the upload they
  /// led to has settled, since it lets iOS suspend the app.
  var eventsDelivered: (() -> Void)?
  private var session: URLSession!
  private var waking: Task<Void, Never>?

  override init() {
    super.init()
    let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    configuration.sessionSendsLaunchEvents = true
    // Nothing of the diver's rides along: no cookie, and nothing kept of the answer.
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
  }

  func leave(for origin: ServerOrigin) {
    let url = origin.apiBaseURL.appendingPathComponent("health")
    Task {
      guard await session.allTasks.isEmpty else { return }
      session.downloadTask(with: url).resume()
    }
  }
}

// The delegate queue is the main queue, so each callback runs on the main actor.
extension BackgroundSessionServerWake: URLSessionDownloadDelegate {
  nonisolated func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {}

  nonisolated func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    MainActor.assumeIsolated {
      let previous = waking
      waking = Task { [onWake] in
        await previous?.value
        await onWake?()
      }
    }
  }

  nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    MainActor.assumeIsolated {
      let waking = waking
      Task {
        await waking?.value
        eventsDelivered?()
        eventsDelivered = nil
      }
    }
  }
}
