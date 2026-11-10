extension PlainCardContent {
  /// A gear item's card on More's *Gear*: its name with Rented, Archived and its worst service
  /// status, its type, brand and vessel facts, and what it has been dived. An item no rule
  /// watches carries no status badge: nothing tracked is not everything fine.
  public static func gearItem(_ item: GearItemRead, units: UnitSystem, today: CalendarDate)
    -> PlainCardContent
  {
    var badges: [Badge] = []
    if item.rented { badges.append(Badge("Rented", style: .outline)) }
    if item.isArchived { badges.append(Badge("Archived", style: .outline)) }
    if let status = GearServiceStatus.worst(
      item.service, diveCount: item.diveCount, diveTime: item.diveTime, today: today)
    {
      badges.append(status.badge)
    }
    let facts =
      [VocabularyLabels.gearType(item.type), item.brand].compactMap { $0 }
      .filter { !$0.isEmpty } + VesselFacts.parts(item, units: units)
    return PlainCardContent(
      title: item.name, badges: badges, facts: facts.map { Fact(text: $0) },
      figures: [
        Figure(label: "Dives", value: String(item.diveCount)),
        Figure(label: "Dive time", value: DateText.hoursMinutes(seconds: item.diveTime)),
      ])
  }

  /// A gear set's card: the items it loads into a dive, *Empty* where it has none, and the
  /// ballast it brings.
  public static func gearSet(_ set: GearSetRead, units: UnitSystem) -> PlainCardContent {
    PlainCardContent(
      title: set.name,
      facts: set.gearItems.map {
        Fact(text: DiveDetailText.gearItemLabel(name: $0.name, brand: $0.brand))
      },
      emptyLine: set.gearItems.isEmpty ? "Empty" : nil,
      figures: [
        Figure(label: "Items", value: String(set.gearItems.count)),
        Figure(label: "Weight", value: set.weight.map { UnitFormat.weight($0, units) }),
      ])
  }
}
