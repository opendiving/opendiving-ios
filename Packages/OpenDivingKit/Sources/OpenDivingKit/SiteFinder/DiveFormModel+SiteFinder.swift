import Foundation

// What the site finder reads from the dive form, and what a pick in it puts on the dive.
extension DiveFormModel {
  /// Where the finder opens: the pins of the sites on the dive, the edited dive's entry fix, its
  /// trip's parts and the day it starts.
  public var siteFinderFacts: SiteFinderOpening.DiveFormFacts {
    let known = lookups.diveSites + lookups.namedSites + Array(sitesFound.values)
    let visited = baseline?.diveSites ?? []
    let sites = values.diveSites.compactMap { ref -> MapPoint? in
      if let site = known.first(where: { $0.ref == ref }),
        let latitude = site.latitude, let longitude = site.longitude
      {
        return MapPoint(name: site.name, latitude: latitude, longitude: longitude)
      }
      if let site = visited.first(where: { $0.ref == ref }),
        let latitude = site.latitude, let longitude = site.longitude
      {
        return MapPoint(name: site.name, latitude: latitude, longitude: longitude)
      }
      return nil
    }
    var fix: DeviceLocation?
    if let latitude = baseline?.entryLatitude, let longitude = baseline?.entryLongitude {
      fix = DeviceLocation(latitude: latitude, longitude: longitude)
    }
    return SiteFinderOpening.DiveFormFacts(
      sites: sites, fix: fix,
      parts: lookups.trips.first { $0.ref == values.trip }?.parts ?? [],
      start: values.startTime?.calendarDate)
  }

  /// A site picked in the finder, after the others: a Commons record off the diver's list stays
  /// nameable once the form is gone, as one the picker found does.
  public func addFound(_ site: DiveSiteLookupItem) {
    take(site)
    addSite(site.ref)
  }
}
