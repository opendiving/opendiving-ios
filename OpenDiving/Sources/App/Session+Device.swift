import Foundation
import OpenDivingKit
import UIKit

extension Session {
  /// The app's session, over the Keychain, the app's defaults, the background-task API, the
  /// path monitor and the network configuration.
  static func device() -> Session {
    let secrets = KeychainSecretStore()
    // Before the session reads the Keychain, so that a reinstall starts signed out. A clear
    // that fails leaves the old tokens for this launch and is retried at the next.
    try? InstallMarker().clearOnFirstLaunch(secrets)
    return Session(
      configuration: NetworkConfiguration.make(),
      secrets: secrets,
      activeOrigin: DefaultsActiveOriginStore(),
      background: ApplicationBackgroundExecution(),
      connectivity: PathMonitorConnectivity(),
      applicationSupport: URL.applicationSupportDirectory,
      userAgent: .device)
  }
}

extension UserAgent {
  /// `UIDevice.model` is the bare word, `iPhone`, which is what the web's sessions page
  /// recognises.
  static var device: UserAgent {
    UserAgent(
      appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "0",
      systemVersion: UIDevice.current.systemVersion,
      model: UIDevice.current.model)
  }
}
