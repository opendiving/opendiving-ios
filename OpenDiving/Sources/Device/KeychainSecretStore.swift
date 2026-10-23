import Foundation
import OpenDivingKit
import Security

/// The Kit's ``SecretStore`` over the Keychain: one generic-password item per server origin,
/// readable after the phone's first unlock so that a refresh in the background still finds it.
nonisolated struct KeychainSecretStore: SecretStore {
  /// A Keychain call that answered anything but success or "no such item".
  struct Failure: Error, Equatable {
    let status: OSStatus
  }

  static let service = "app.opendiving.ios.refresh-token"

  var service = Self.service

  func secret(for account: String) throws -> String? {
    var query = itemQuery(account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      guard let data = result as? Data else { throw Failure(status: errSecDecode) }
      return String(decoding: data, as: UTF8.self)
    case errSecItemNotFound:
      return nil
    default:
      throw Failure(status: status)
    }
  }

  func setSecret(_ value: String, for account: String) throws {
    // Delete then add, so that the accessibility below is the item's whatever an older
    // write set.
    try removeSecret(for: account)
    var item = itemQuery(account)
    item[kSecValueData as String] = Data(value.utf8)
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw Failure(status: status) }
  }

  func removeSecret(for account: String) throws {
    let status = SecItemDelete(itemQuery(account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Failure(status: status)
    }
  }

  /// Removes the item of every server at once. Removing none is not an error.
  func removeAllSecrets() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Failure(status: status)
    }
  }

  func itemQuery(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}
