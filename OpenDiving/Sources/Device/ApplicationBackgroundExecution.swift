import OpenDivingKit
import UIKit

/// The Kit's ``BackgroundExecution`` over `UIApplication`'s background tasks.
nonisolated final class ApplicationBackgroundExecution: BackgroundExecution {
  @MainActor
  func begin(name: String) async -> BackgroundExecutionToken {
    let task = TaskIdentifier()
    // Expiry ends the task, as the system requires; `end` then ending it again is harmless.
    task.value = UIApplication.shared.beginBackgroundTask(withName: name) {
      UIApplication.shared.endBackgroundTask(task.value)
    }
    return BackgroundExecutionToken(rawValue: task.value.rawValue)
  }

  @MainActor
  func end(_ token: BackgroundExecutionToken) async {
    let identifier = UIBackgroundTaskIdentifier(rawValue: token.rawValue)
    guard identifier != .invalid else { return }
    UIApplication.shared.endBackgroundTask(identifier)
  }
}

/// Lets the expiration handler name the task it was handed out with.
private final class TaskIdentifier {
  var value = UIBackgroundTaskIdentifier.invalid
}
