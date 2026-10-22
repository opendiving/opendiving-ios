import OpenDivingKit
import Testing

/// Transcribed from `src/lib/external-ids.test.ts`, `src/lib/species.test.ts`,
/// `src/lib/trip-locations.test.ts`, `src/lib/trip-parts.test.ts` and
/// `src/lib/trip-dive-sections.test.ts` at `opendiving-web` `ec014ff9`.
struct NamesTests {
  // MARK: External ids — `external-ids.test.ts:98-152`

  @Test func registryLinks() {
    #expect(
      ExternalIdRegistry.link(registry: "openstreetmap", identifier: "way/42")
        == "https://www.openstreetmap.org/way/42")
    #expect(
      ExternalIdRegistry.link(registry: "wikidata", identifier: "Q193213")
        == "https://www.wikidata.org/wiki/Q193213")
    #expect(
      ExternalIdRegistry.link(registry: "worms", identifier: "127160")
        == "https://www.marinespecies.org/aphia.php?p=taxdetails&id=127160")
    #expect(ExternalIdRegistry.link(registry: "wrecksite", identifier: "10021") == nil)
    #expect(ExternalIdRegistry.link(registry: "constructor", identifier: "1") == nil)
    #expect(ExternalIdRegistry.link(registry: "openstreetmap", identifier: "255316037") == nil)
    #expect(ExternalIdRegistry.link(registry: "wikidata", identifier: "Q0") == nil)
    #expect(
      ExternalIdRegistry.link(
        registry: "worms", identifier: "urn:lsid:marinespecies.org:taxname:127160") == nil)
    #expect(ExternalIdRegistry.link(registry: "worms", identifier: "0127160") == nil)
  }

  @Test func registryLabels() {
    #expect(ExternalIdRegistry.label("openstreetmap") == "OpenStreetMap")
    #expect(ExternalIdRegistry.label("wikidata") == "Wikidata")
    #expect(ExternalIdRegistry.label("worms") == "WoRMS")
    #expect(ExternalIdRegistry.label("wrecksite") == "wrecksite")
    #expect(ExternalIdRegistry.label("constructor") == "constructor")
  }

  // MARK: Species — `species.test.ts:10-118`

  @Test func speciesNames() {
    #expect(
      SpeciesNames.displayName(
        scientificName: "Amphiprion ocellaris", commonName: "Ocellaris clownfish")
        == "Ocellaris clownfish")
    #expect(
      SpeciesNames.displayName(scientificName: "Chromodoris annae", commonName: nil)
        == "Chromodoris annae")
    #expect(SpeciesNames.rankLabel("Family") == "Family")
    #expect(SpeciesNames.rankLabel("unknown") == nil)
    #expect(SpeciesNames.rankLabel("Unknown") == nil)
    #expect(SpeciesNames.rankLabel("") == nil)
    #expect(SpeciesNames.rankLabel("   ") == nil)
    #expect(
      SpeciesNames.scientificNameWithRank("Amphiprion ocellaris", rank: "Species")
        == "Amphiprion ocellaris")
    #expect(
      SpeciesNames.scientificNameWithRank("Muraenidae", rank: "Family") == "Muraenidae (Family)")
    #expect(
      SpeciesNames.scientificNameWithRank("Amphiprion ocellaris", rank: "species")
        == "Amphiprion ocellaris")
    for rank in ["  ", "", "unknown"] {
      #expect(
        SpeciesNames.scientificNameWithRank("Amphiprion ocellaris", rank: rank)
          == "Amphiprion ocellaris")
    }
  }

  // MARK: Trips

  /// `trip-locations.test.ts`.
  @Test func tripLocationNames() {
    #expect(
      TripText.locationNames(["Moalboal", "Bohol", "Malapascua"]) == "Moalboal; Bohol; Malapascua")
    #expect(
      TripText.locationNames(["Dahab, Egypt", "Sharm El Sheikh, Egypt"])
        == "Dahab, Egypt; Sharm El Sheikh, Egypt")
    #expect(
      TripText.locationNames(["Moalboal", "Bohol", "Malapascua", "Siquijor"], max: 2)
        == "Moalboal; Bohol +2")
    #expect(TripText.locationNames(["Moalboal", "Bohol"], max: 2) == "Moalboal; Bohol")
    #expect(TripText.locationNames([]) == nil)
    #expect(TripText.locationNames(["Moalboal", "   ", "Bohol"]) == "Moalboal; Bohol")
    #expect(TripText.locationNames([""]) == nil)
    #expect(TripText.locationNames(["  Bohol  "]) == "Bohol")
    #expect(TripText.locationNames(["Moalboal", " ", "Bohol"], max: 1) == "Moalboal +1")
    // `trip-parts.test.ts:85-96`: a part with no place contributes nothing.
    #expect(TripText.locationsLabel(["Dahab", nil, "Sharm"]) == "Dahab +1")
    #expect(TripText.locationsLabel([nil]) == nil)
  }

  private func day(_ wire: String) -> CalendarDate {
    CalendarDate(iso8601: wire)!
  }

  /// `trip-parts.test.ts:64-81`, `:113-129`.
  @Test func tripSpanAndPartDates() {
    #expect(
      TripText.span([
        (day("2026-04-18"), day("2026-04-22")), (day("2026-04-22"), day("2026-04-25")),
      ])
        == "Apr 18 - Apr 25, 2026")
    #expect(TripText.span([(nil, nil)]) == nil)
    #expect(TripText.span([]) == nil)
    #expect(TripText.span([(day("2026-04-18"), nil)]) == "Apr 18, 2026")
    #expect(
      TripText.span([(day("2026-04-18"), nil), (nil, day("2026-04-25"))]) == "Apr 18 - Apr 25, 2026"
    )
    #expect(TripText.partDates(start: day("2026-09-01"), end: nil) == "From Sep 1, 2026")
    #expect(TripText.partDates(start: nil, end: day("2021-04-06")) == "Until Apr 6, 2021")
    #expect(
      TripText.partDates(start: day("2026-04-03"), end: day("2026-04-08")) == "Apr 3 - Apr 8, 2026")
    #expect(TripText.partDates(start: nil, end: nil) == nil)
  }

  /// `trip-dive-sections.test.ts`, `tripPartForDay`.
  @Test func partForDay() {
    let openEnded =
      [(day("2021-03-20"), nil), (nil, day("2021-04-06"))]
      as [(start: CalendarDate?, end: CalendarDate?)]
    #expect(TripText.partForDay(openEnded, day: day("2021-03-25")) == 0)
    #expect(TripText.partForDay(openEnded, day: day("2021-04-02")) == 1)
    #expect(TripText.partForDay(openEnded, day: day("2021-03-19")) == 1)
    #expect(TripText.partForDay(openEnded, day: day("2021-04-07")) == 0)

    let sideTrip =
      [(day("2026-09-01"), nil), (day("2026-09-10"), day("2026-09-12"))]
      as [(start: CalendarDate?, end: CalendarDate?)]
    #expect(TripText.partForDay(sideTrip, day: day("2026-09-11")) == 1)
    #expect(TripText.partForDay(sideTrip, day: day("2026-09-13")) == 0)

    let touching =
      [(day("2026-04-03"), day("2026-04-08")), (day("2026-04-08"), day("2026-04-12"))]
      as [(start: CalendarDate?, end: CalendarDate?)]
    #expect(TripText.partForDay(touching, day: day("2026-04-08")) == 0)

    #expect(TripText.partForDay([(nil, nil)], day: day("2026-04-08")) == nil)
  }
}
