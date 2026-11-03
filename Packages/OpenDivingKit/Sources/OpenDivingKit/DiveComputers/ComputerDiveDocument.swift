import Foundation

/// One downloaded dive as the archive's document holds it: the reader's dive, with what is the
/// host's put on it — the uuid derived from the computer and the fingerprint, the start in the
/// zone the download resolved, the device block, and the stored original. Every other member is
/// the reader's, as it returned it; what DiveJSON defers, the original bytes keep.
enum ComputerDiveDocument {
  static func dive(
    _ dive: ComputerDive, identity: DiveComputerIdentity, uuid: UUID, startedAt: String,
    storedFile: ArchiveJSON
  ) -> ArchiveJSON {
    var out = dive.body
    out["uuid"] = .string(uuid.uuidString.lowercased())
    out["started_at"] = .string(startedAt)
    guard case .object(var recording)? = out["recordings"]?.arrayValue?.first else {
      return .object(out)
    }
    var device: [String: ArchiveJSON] = [:]
    func put(_ key: String, _ value: String?, limit: Int) {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
      else { return }
      device[key] = .string(String(value.prefix(limit)))
    }
    put(
      "model", identity.family.deviceModel(vendor: identity.vendor, product: identity.product),
      limit: 64)
    put("serial", identity.serial, limit: 64)
    put("firmware", identity.firmware, limit: 32)
    if !device.isEmpty { recording["device"] = .object(device) }
    recording["source_files"] = .array([storedFile])
    out["recordings"] = .array([.object(recording)])
    return .object(out)
  }
}
