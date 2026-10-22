import Foundation
import Security
import Testing

@testable import OpenDiving

struct KeychainSecretStoreTests {
  private let store = KeychainSecretStore(service: "app.opendiving.ios.tests")
  private let account = "https://keychain-\(UUID().uuidString).example"

  @Test func writesReadsBackReplacesAndDeletes() throws {
    defer { try? store.removeSecret(for: account) }
    #expect(try store.secret(for: account) == nil)
    try store.setSecret("first", for: account)
    #expect(try store.secret(for: account) == "first")
    try store.setSecret("second", for: account)
    #expect(try store.secret(for: account) == "second")
    try store.removeSecret(for: account)
    #expect(try store.secret(for: account) == nil)
    try store.removeSecret(for: account)
  }

  @Test func theItemIsReadableAfterFirstUnlock() throws {
    defer { try? store.removeSecret(for: account) }
    try store.setSecret("token", for: account)
    var query = store.itemQuery(account)
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
    let attributes = try #require(result as? [String: Any])
    #expect(
      attributes[kSecAttrAccessible as String] as? String
        == kSecAttrAccessibleAfterFirstUnlock as String)
  }
}
