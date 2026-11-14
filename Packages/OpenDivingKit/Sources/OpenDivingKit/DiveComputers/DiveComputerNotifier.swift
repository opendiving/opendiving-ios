/// Posts a download's notifications. A protocol because the Kit cannot import UserNotifications:
/// the app conforms it over the notification centre, posting only where the diver has allowed
/// notifications and never asking, and the Kit's tests over a fake.
@MainActor
public protocol DiveComputerNotifier: AnyObject {
  func post(_ notice: DiveComputerNotice)
}
