import Foundation

extension DiveFormValues {
  /// A new dive's values carried from the last dive, by the web's rule per field: what belongs
  /// to the place, the boat, the kit and the company carries — the course, trip and dive centre,
  /// the entry and the boat's name, the people, the dive type, the water and its altitude, the
  /// gear still in use, the weight, and the tanks with their pressures blanked and the source's
  /// gas numbers dropped. The day's readings and the diver's word on that one dive do not: the
  /// sites, the conditions, the sightings, the rating, the tags and the notes start empty.
  ///
  /// A field `visibility` does not show starts empty too, as it does on the web. Which dive is
  /// the last, if any, is the caller's to find.
  public static func carried(
    from last: DiveReadWithMixtures, number: Int?, visibility: DiveFormVisibility,
    now: Date = Date(), timeZone: TimeZone = .current
  ) -> DiveFormValues {
    var values = newDive(number: number, now: now, timeZone: timeZone)
    values.course = last.courseUuid.map(RecordRef.server)
    values.trip = last.tripUuid.map(RecordRef.server)
    values.contact = last.contactUuid.map(RecordRef.server)
    values.entryType = last.entryType
    values.boatName = last.boatName ?? ""
    values.people = last.people
    values.type = last.type
    values.waterType = last.waterType
    values.altitude = last.altitude
    values.gearItems = last.gearItems.filter { !$0.isArchived }.map(\.ref)
    values.weight = last.weight
    values.tanks = last.mixtures.map(carriedTank)
    return visibility.applied(to: values)
  }

  /// The same tank on the next dive: the same vessel where it can still be linked — not
  /// archived, and still a cylinder — taking its capacity; the mix, the limit, the role and the
  /// usage as they were; no pressures and no gas number, which named a cylinder in the last
  /// dive's file.
  private static func carriedTank(_ mixture: DiveMixtureRead) -> TankValues {
    let item = mixture.gearItem
    let vessel = item.flatMap { item in
      item.isArchived || (item.type != nil && item.type != "cylinder") ? nil : item
    }
    return TankValues(
      volume: vessel?.volume ?? mixture.volume, oxygen: mixture.oxygen, helium: mixture.helium,
      po2Limit: mixture.po2Limit, role: mixture.role, usage: mixture.usage,
      cylinder: vessel?.ref, vessel: vessel)
  }
}
