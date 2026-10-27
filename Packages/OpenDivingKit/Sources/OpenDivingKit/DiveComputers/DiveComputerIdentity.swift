/// One dive computer as the device reported itself, with its serial spelled as its family's
/// exports spell it (``DiveComputerFamily/serial(deviceInfo:)``,
/// ``DiveComputerFamily/serial(advertisedIn:)``).
public struct DiveComputerIdentity: Hashable, Sendable {
  public let family: DiveComputerFamily
  /// libdivecomputer's descriptor vendor, `Shearwater`.
  public let vendor: String
  /// libdivecomputer's descriptor product, `Perdix 3`.
  public let product: String
  public let serial: String
  public let firmware: String?
  /// libdivecomputer's `dc_family_t` and model numbers at the pinned library: what the open
  /// used. Carried for the conformance, never written anywhere or kept.
  public let familyNumber: UInt32
  public let modelNumber: UInt32

  public init(
    family: DiveComputerFamily, vendor: String, product: String, serial: String,
    firmware: String?, familyNumber: UInt32, modelNumber: UInt32
  ) {
    self.family = family
    self.vendor = vendor
    self.product = product
    self.serial = serial
    self.firmware = firmware
    self.familyNumber = familyNumber
    self.modelNumber = modelNumber
  }

  /// *Shearwater Perdix 3*: what the screens call the computer.
  public var title: String { DiveComputerText.title(vendor: vendor, product: product) }
}
