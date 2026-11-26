import Foundation
import OpenDivingKit
import UIKit

extension Session {
  /// The app's session, over the Keychain, the app's defaults, the background-task API, the
  /// path monitor, the network configuration and, where the build carries an associated domain,
  /// the system's passkey sheet.
  static func device() -> Session {
    let secrets = KeychainSecretStore()
    // Before the session reads the Keychain, so that a reinstall starts signed out. A clear
    // that fails leaves the old tokens for this launch and is retried at the next.
    try? InstallMarker().clearOnFirstLaunch(secrets)
    let activeOrigin = DefaultsActiveOriginStore()
    #if targetEnvironment(simulator)
      // `scripts/simulator-sign-in.py` starts the app signed in; a device build has no such door.
      if let signIn = LaunchArguments(ProcessInfo.processInfo.arguments).signIn {
        try? ServerStateStore(
          root: .applicationSupportDirectory, secrets: secrets, activeOrigin: activeOrigin
        ).start(signIn)
      }
    #endif
    return Session(
      configuration: NetworkConfiguration.make(),
      secrets: secrets,
      activeOrigin: activeOrigin,
      background: ApplicationBackgroundExecution(),
      connectivity: PathMonitorConnectivity(),
      applicationSupport: URL.applicationSupportDirectory,
      userAgent: .device,
      passkeyAssociation: PasskeyAssociation(
        domain: Bundle.main.object(forInfoDictionaryKey: "OpenDivingAssociatedDomain") as? String,
        ceremony: AuthenticationServicesPasskeyCeremony()))
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
