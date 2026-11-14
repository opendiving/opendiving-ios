import OpenDivingKit
import UIKit
import UserNotifications

/// What the app starts before any view, on every launch, by the diver or by iOS in the
/// background — a view may never be built on one of iOS's: the session and the account's load,
/// the watch over the paired dive computers, the engine that downloads and imports from them, the
/// notifications it posts, and the watch walk's launch arguments. Nothing here asks who launched
/// the process: a scene-based app is told neither way.
final class AppDelegate: NSObject, UIApplicationDelegate {
  let session = Session.device()
  lazy var account = AccountLoader(session: session)
  lazy var inbox = InboxModel(session: session)
  let notices = NoticeRoute()
  private let notifier = UserNotificationsDiveComputerNotifier()
  private let wake = BackgroundSessionServerWake()
  private var ending: Task<Void, Never>?
  private var endsInBackground = false

  lazy var watch = DiveComputerWatch(
    log: .device,
    pairings: { DiveComputerStore.pairings(applicationSupport: .applicationSupportDirectory) },
    makeWatcher: { CoreBluetoothDiveComputerWatcher.make() })

  lazy var engine = DiveComputerEngine(
    session: session, makeLink: { LibDCDiveComputerLink() }, generator: DiveComputerView.generator,
    watch: watch, notifier: notifier, wake: wake,
    loadAccount: { [account] in await account.loadQuietly() })

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    watch.launched()
    let arguments = LaunchArguments(ProcessInfo.processInfo.arguments)
    endsInBackground = arguments.endsInBackground
    if arguments.endsAfterFirstDive {
      engine.diveKept = { [watch] in
        watch.note("ending itself, as \(LaunchArguments.endAfterFirstDive) asks")
        exit(0)
      }
    }
    UNUserNotificationCenter.current().delegate = self
    wake.onWake = { [engine] in engine.upload() }
    engine.launched()
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification,
      object: nil)
    center.addObserver(
      self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    return true
  }

  func application(
    _ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    guard identifier == BackgroundSessionServerWake.identifier else {
      completionHandler()
      return
    }
    wake.eventsDelivered = completionHandler
  }

  @objc private func becameActive() {
    watch.note("active")
    ending?.cancel()
    ending = nil
  }

  @objc private func enteredBackground() {
    watch.note("background")
    guard endsInBackground, ending == nil else { return }
    ending = Task { [watch] in
      let background = ApplicationBackgroundExecution()
      let token = await background.begin(name: "Ending for the watch walk")
      try? await Task.sleep(for: .seconds(5))
      guard !Task.isCancelled else {
        await background.end(token)
        return
      }
      watch.note("ending itself, as \(LaunchArguments.endInBackground) asks")
      // Ended this way rather than by a force-quit, iOS still relaunches the app for Bluetooth.
      exit(0)
    }
  }
}

// The centre calls its delegate on the main thread.
extension AppDelegate: UNUserNotificationCenterDelegate {
  /// With the app in front, a download's notification shows as a banner, as it would behind.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    nonisolated(unsafe) let userInfo = response.notification.request.content.userInfo
    guard let target = DiveComputerNotice.Target(userInfo: userInfo) else { return }
    await MainActor.run { notices.open(target) }
  }
}

extension DiveComputerWatchLog {
  /// The phone's: one file in Application Support beside the download's log.
  nonisolated static let device = DiveComputerWatchLog(
    file: URL.applicationSupportDirectory.appendingPathComponent("dive-computer-watch.log"))
}
