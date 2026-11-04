import Foundation

/// What the phone knows of one dive computer whichever server it is signed in to: who it is, where
/// the phone last saw it, and what its logbook's entries are.
struct PairedComputer: Codable, Hashable, Sendable {
  var family: DiveComputerFamily
  var vendor: String
  var product: String
  var serial: String
  var firmware: String?
  var hardware: String?
  var peripheral: UUID?
  /// Optional so that a file written before it existed still decodes.
  var nauticSports: [NauticEntrySport]?

  init(_ record: DiveComputerRecord) {
    family = record.family
    vendor = record.vendor
    product = record.product
    serial = record.serial
    firmware = record.firmware
    hardware = record.hardware
    peripheral = record.peripheral
    nauticSports = record.nauticSports
  }
}
