import OpenDivingKit
import UIKit

/// What the app starts before any view, on every launch, by the diver or by iOS in the
/// background: the watch over the paired dive computers, and the watch walk's launch argument.
final class AppDelegate: NSObject, UIApplicationDelegate {
  private var restoringWatcher = false
  private var ending: Task<Void, Never>?
  private var endsInBackground = false

  lazy var watch = DiveComputerWatch(
    log: .device,
    pairings: { DiveComputerStore.pairings(applicationSupport: .applicationSupportDirectory) },
    makeWatcher: { [unowned self] in
      CoreBluetoothDiveComputerWatcher.make(restoring: restoringWatcher)
    })

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Only Bluetooth state restoration launches this app in the background.
    let restoring = launchOptions?[.bluetoothCentrals] as? [String] ?? []
    restoringWatcher = restoring.contains(CoreBluetoothDiveComputerWatcher.restoreIdentifier)
    watch.launched(restoring.isEmpty ? .byUser : .byIOS(restoring: restoring))
    endsInBackground = LaunchArguments(ProcessInfo.processInfo.arguments).endsInBackground
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification,
      object: nil)
    center.addObserver(
      self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    return true
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

extension DiveComputerWatchLog {
  /// The phone's: one file in Application Support beside the download's log.
  nonisolated static let device = DiveComputerWatchLog(
    file: URL.applicationSupportDirectory.appendingPathComponent("dive-computer-watch.log"))
}
