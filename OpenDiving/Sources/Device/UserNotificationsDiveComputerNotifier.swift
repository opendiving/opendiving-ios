import OpenDivingKit
import UserNotifications

/// The Kit's ``DiveComputerNotifier`` over the notification centre. It posts only where the diver
/// has allowed notifications, and never asks for them.
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
}
