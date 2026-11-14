import OpenDivingKit
import UserNotifications

/// The Kit's ``DiveComputerNotifier`` over the notification centre. It posts only where the diver
/// has allowed notifications, and asks only when the Dive Computers screen's row is tapped.
final class UserNotificationsDiveComputerNotifier: DiveComputerNotifier {
  func post(_ notice: DiveComputerNotice) {
    Task {
      let center = UNUserNotificationCenter.current()
      guard await center.notificationSettings().authorizationStatus == .authorized else { return }
      let content = UNMutableNotificationContent()
      content.title = notice.title
      content.body = notice.body
      content.userInfo = notice.target.userInfo
      content.interruptionLevel = notice.passive ? .passive : .active
      if !notice.passive { content.sound = .default }
      try? await center.add(
        UNNotificationRequest(identifier: notice.id, content: content, trigger: nil))
    }
  }

  func hasAsked() async -> Bool {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
      != .notDetermined
  }

  func ask() async {
    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
      .alert, .sound,
    ])
  }
}
