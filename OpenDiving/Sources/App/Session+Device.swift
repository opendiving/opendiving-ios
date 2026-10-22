import Foundation
import OpenDivingKit
import UIKit

extension Session {
  /// The app's session, over the Keychain, the app's defaults, the background-task API and
  /// the network configuration.
  static func device() -> Session {
    Session(
      configuration: NetworkConfiguration.make(),
      secrets: KeychainSecretStore(),
      activeOrigin: DefaultsActiveOriginStore(),
      background: ApplicationBackgroundExecution(),
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
