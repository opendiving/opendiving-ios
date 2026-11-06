import Testing

@testable import OpenDivingKit

struct MapAttributionTests {
  @Test func sourcesAreSetApartByTheCopyrightMarkAndTheirLinksKept() {
    #expect(
      MapAttribution.display(
        "[OpenFreeMap](https://openfreemap.org/) © [OpenMapTiles](https://openmaptiles.org/) / "
          + "[OpenStreetMap](https://www.openstreetmap.org/copyright)")
        == "[OpenFreeMap](https://openfreemap.org/) © [OpenMapTiles](https://openmaptiles.org/) © "
        + "[OpenStreetMap](https://www.openstreetmap.org/copyright)")
  }

  @Test func aCreditWithOneSourceIsLeftAlone() {
    let credit = "[OpenFreeMap](https://openfreemap.org/)"
    #expect(MapAttribution.display(credit) == credit)
  }
}
