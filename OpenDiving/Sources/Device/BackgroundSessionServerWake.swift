import Foundation
import OpenDivingKit

/// The Kit's ``ServerWake`` over a background session: one request for the server's health,
/// which names no account and carries no dive, and which iOS completes once there is a route —
/// relaunching the app if it has ended. Its session is made at launch, so a relaunch for its
/// events finds it.
final class BackgroundSessionServerWake: NSObject, ServerWake {
  static let identifier = "app.opendiving.server-wake"

  /// The request completed: the app has a route to try the upload on.
  var onWake: (() -> Void)?
  /// iOS's handler for a relaunch to deliver the session's events, called once they are.
  var eventsDelivered: (() -> Void)?
  private var session: URLSession!

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
    MainActor.assumeIsolated { onWake?() }
  }

  nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    MainActor.assumeIsolated {
      eventsDelivered?()
      eventsDelivered = nil
    }
  }
}
