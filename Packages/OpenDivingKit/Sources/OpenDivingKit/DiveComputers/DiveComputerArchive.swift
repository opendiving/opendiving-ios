import Foundation

/// The names and identities a download archive is built from.
enum DiveComputerArchive {
  /// The api's own producer key, "stable by contract" there; the recording's extensions sit
  /// under it.
  static let producerKey = "opendiving"
  static let documentName = "logbook.divejson"
  static let filesFolder = "files/"

  /// The namespace every dive and stored-file uuid the writer derives is in. Fixed: a dive
  /// downloaded twice carries the same uuid, which the import reads as a dive the account
  /// already holds.
  static let namespace = UUID(uuidString: "27d3f9c0-84dc-45e8-b2ea-c8171381fb80")!

  /// The dive's uuid: its computer's family and serial and its fingerprint.
  static func diveUUID(_ identity: DiveComputerIdentity, fingerprint: Data) -> UUID {
    UUID.version5(namespace: namespace, name: "dive/" + key(identity, fingerprint))
  }

  /// The uuid of the dive's stored original.
  static func fileUUID(_ identity: DiveComputerIdentity, fingerprint: Data) -> UUID {
    UUID.version5(namespace: namespace, name: "file/" + key(identity, fingerprint))
  }

  private static func key(_ identity: DiveComputerIdentity, _ fingerprint: Data) -> String {
    identity.family.rawValue + "/" + identity.serial.uppercased() + "/" + Hex.lowercase(fingerprint)
  }

  /// `shearwater-perdix-3`: the vendor and product as one lowercase slug.
  static func slug(vendor: String, product: String) -> String {
    var out = ""
    for scalar in (vendor + " " + product).lowercased().unicodeScalars {
      if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
        out.unicodeScalars.append(scalar)
      } else if !out.isEmpty, !out.hasSuffix("-") {
        out += "-"
      }
    }
    while out.hasSuffix("-") { out.removeLast() }
    return out.isEmpty ? "dive-computer" : out
  }

  /// A serial as a filename keeps it: letters, digits and dashes.
  static func fileSerial(_ serial: String) -> String {
    String(
      serial.unicodeScalars.map {
        ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0)
          ? Character($0) : "-"
      })
  }

  /// `2026-10-25T0914`: a wall clock to the minute, as names carry it.
  static func minute(_ clock: LocalDateTime) -> String {
    clock.date.iso8601 + "T" + CalendarDate.pad(clock.hour, 2) + CalendarDate.pad(clock.minute, 2)
  }

  /// `instant`'s wall clock in `zone`.
  static func clock(_ instant: Date, in zone: TimeZone) -> LocalDateTime {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: instant)
    // Every component is present for a Gregorian calendar asked for it.
    return LocalDateTime(
      date: CalendarDate(year: parts.year!, month: parts.month!, day: parts.day!)!,
      hour: parts.hour!, minute: parts.minute!, second: parts.second!)!
  }

  /// `+02:00`.
  static func offset(_ seconds: Int) -> String {
    let sign = seconds < 0 ? "-" : "+"
    let minutes = abs(seconds) / 60
    return sign + CalendarDate.pad(minutes / 60, 2) + ":" + CalendarDate.pad(minutes % 60, 2)
  }

  /// An instant as an RFC 3339 date-time in `zone`'s offset at that instant, to the second.
  static func dateTime(_ instant: Date, in zone: TimeZone) -> String {
    let whole = Date(timeIntervalSince1970: instant.timeIntervalSince1970.rounded(.down))
    return clock(whole, in: zone).iso8601 + offset(zone.secondsFromGMT(for: whole))
  }

  /// A dive's start as the document spells it, with the clock its names carry: the wall clock
  /// with its offset where the parser reported a zone, without one where it did not, and an
  /// instant in `zone`'s offset at that instant.
  static func start(_ start: ComputerDive.Start, zone: TimeZone?) throws -> (
    text: String, clock: LocalDateTime
  ) {
    switch start {
    case .wallClock(let clock, let offset):
      return (clock.iso8601 + (offset.map(Self.offset) ?? ""), clock)
    case .instant(let instant):
      guard let zone else { throw DiveComputerArchiveError.noZone }
      let whole = Date(timeIntervalSince1970: instant.timeIntervalSince1970.rounded(.down))
      return (dateTime(whole, in: zone), clock(whole, in: zone))
    }
  }
}

/// Why an archive was not written.
public enum DiveComputerArchiveError: Error, Hashable, Sendable {
  /// A dive's start is an instant and no zone was given to write it in.
  case noZone
  /// A waiting archive to unite with is not one this build wrote.
  case unreadableArchive
}
