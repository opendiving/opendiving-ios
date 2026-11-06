extension DiveCardContent {
  /// A row of `GET /dives` as its card, through the one mapping every list of dives shares.
  public static func dive(_ item: DiveListItem, units: UnitSystem) -> DiveCardContent {
    dive(
      number: item.diveNumber,
      siteNames: item.diveSites.map(\.name),
      isCourse: item.courseUuid != nil,
      rating: item.rating,
      waterType: item.waterType,
      diveType: item.type,
      tags: item.tags,
      start: item.startTime,
      locationName: item.diveSites.first?.location?.name,
      boatName: item.boatName,
      recordingCount: item.recordingCount,
      owedDeco: item.deco,
      submergedSeconds: item.submergedTime,
      maxDepth: item.maxDepth,
      waterTemperature: item.bottomTemperature,
      speciesCount: item.speciesCount,
      outline: item.depthOutline?.values ?? [],
      places: mapPlaces(
        sites: item.diveSites, entry: (item.entryLatitude, item.entryLongitude),
        exit: (item.exitLatitude, item.exitLongitude)),
      units: units)
  }
}
