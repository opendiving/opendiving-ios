/// Posts a download's notifications, and asks for them. A protocol because the Kit cannot import
/// UserNotifications: the app conforms it over the notification centre, posting only where the
/// diver has allowed notifications, and the Kit's tests over a fake.
@MainActor
public protocol DiveComputerNotifier: AnyObject {
  func post(_ notice: DiveComputerNotice)
  /// Whether iOS has asked the diver yet, whatever they answered.
  func hasAsked() async -> Bool
  /// iOS's own question, once; returns when the diver has answered it.
  func ask() async
}
