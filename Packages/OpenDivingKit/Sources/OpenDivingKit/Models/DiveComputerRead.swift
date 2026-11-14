import Foundation

/// One row of `GET /dive-computers`: a computer the account's recordings name, or a serial its
/// stored order holds that no recording names yet, whose brand, model and name are then null.
/// The array is the account's order, first to last; the first computer's recording is shown by
/// default where several recorded one dive.
public struct DiveComputerRead: Codable, Hashable, Sendable {
  /// As the latest recording spells it, or folded as the order stores it: compare with
  /// ``DiveComputerRead/fold(_:)``.
  public let serial: String
  public let brand: String?
  public let model: String?
  public let name: String?
  /// 0 for the first.
  public let position: Int

  public init(serial: String, brand: String?, model: String?, name: String?, position: Int) {
    self.serial = serial
    self.brand = brand
    self.model = model
    self.name = name
    self.position = position
  }

  /// No recording names it: the order holds its serial alone.
  public var isUnlabelled: Bool { brand == nil && model == nil && name == nil }

  /// *Shearwater Perdix 3*, the recording's own name, or the serial alone.
  public var title: String {
    let named = [brand, model].compactMap { $0 }.joined(separator: " ")
    if !named.isEmpty { return named }
    return name ?? serial
  }

  /// A serial as the api compares it: trimmed and case-folded.
  public static func fold(_ serial: String) -> String {
    serial.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}

/// `PUT /dive-computers/order`'s body: the whole order, first to last.
struct DiveComputerOrder: Encodable, Sendable {
  let serials: [String]
}
