import Foundation

/// A computer a scan found advertising nearby.
public struct FoundComputer: Hashable, Sendable, Identifiable {
  /// Core Bluetooth's per-app identifier for the peripheral. iOS rotates it for some
  /// computers, so it is a hint for finding the remembered one, never its key.
  public let id: UUID
  /// The name the computer advertises.
  public let name: String
  /// What the conformance resolved from the name, where it could: the family, the descriptor's
  /// vendor and product, and libdivecomputer's model number to open it with.
  public let family: DiveComputerFamily?
  public let vendor: String?
  public let product: String?
  public let modelNumber: UInt32?

  public init(
    id: UUID, name: String, family: DiveComputerFamily? = nil, vendor: String? = nil,
    product: String? = nil, modelNumber: UInt32? = nil
  ) {
    self.id = id
    self.name = name
    self.family = family
    self.vendor = vendor
    self.product = product
    self.modelNumber = modelNumber
  }

  /// The serial the advertised name carries, for a family whose name does.
  public var advertisedSerial: String? { family?.serial(advertisedIn: name) }

  /// *Shearwater Perdix 3* where the name resolved, the advertised name otherwise.
  public var title: String {
    guard let vendor, let product else { return name }
    return DiveComputerText.title(vendor: vendor, product: product)
  }
}
