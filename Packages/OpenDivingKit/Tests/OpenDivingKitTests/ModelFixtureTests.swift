import Foundation
import OpenDivingKit
import Testing

/// Every model decodes its fixture and survives an encode-and-decode unchanged.
struct ModelFixtureTests {
  @Test func user() throws {
    let user = try KitFixture.roundTrip(UserRead.self, "user")
    #expect(user.units == .metric)
    #expect(user.portraitCrop == PictureCropFixture.portrait)
    #expect(user.diveFormHiddenFields.contains("mixture.helium"))
  }

  @Test func anUnknownUnitSystemReadsAsMetric() throws {
    let user = try KitFixture.roundTrip(UserRead.self, "user-unknown-units")
    #expect(user.units == .metric)
    #expect(user.portraitSha256 == nil)
  }

  @Test func imperialIsRead() throws {
    var json = try KitFixture.text("user")
    json = json.replacingOccurrences(of: #""units": "metric""#, with: #""units": "imperial""#)
    #expect(try APICoding.decoder().decode(UserRead.self, from: Data(json.utf8)).units == .imperial)
  }

  @Test func checkinDetails() throws {
    let details = try KitFixture.roundTrip(CheckinDetailsRead.self, "checkin-details")
    #expect(details.dateOfBirth == CalendarDate(year: 1988, month: 4, day: 12))
    #expect(
      details.insurancePolicies.first?.expiresOn == CalendarDate(year: 2027, month: 6, day: 30))
    #expect(details.emergencyContacts.count == 2)
  }

  @Test func diveStats() throws {
    let stats = try KitFixture.roundTrip(UserDiveStatsRead.self, "dive-stats")
    #expect(stats.lastDiveOn == CalendarDate(year: 2026, month: 10, day: 2))
    #expect(stats.createdAt.utcOffsetMinutes == 0)
  }

  @Test func peoplePage() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<PersonRead>.self, "people-page")
    #expect(page.data.map(\.name) == ["Ana Diaz", "Ben Okafor", "Chloe Martin"])
    #expect(page.data.first?.username == "ana")
  }

  @Test func capturedDiveList() throws {
    let page = try KitFixture.roundTrip(PaginatedListResponse<DiveListItem>.self, "dives-page")
    let row = try #require(page.data.first)
    #expect(page.hasMore)
    #expect(row.diveNumber == 532)
    #expect(row.depthOutline?.values.count == 12)
    #expect(row.recordingCount == 1)
  }

  @Test func theFourStartTimeSpellings() throws {
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<DiveListItem>.self, "dives-start-times")
    let clock = { (hour: Int, minute: Int, second: Int, nanosecond: Int) in
      LocalDateTime(
        date: CalendarDate(year: 2021, month: 4, day: 4)!, hour: hour, minute: minute,
        second: second, nanosecond: nanosecond)!
    }
    #expect(
      page.data.map(\.startTime) == [
        .instant(clock(10, 4, 0, 500_000_000), utcOffsetMinutes: 120),
        .instant(clock(8, 4, 0, 0), utcOffsetMinutes: 0),
        .wallClock(clock(11, 49, 0, 0)),
        .day(CalendarDate(year: 2002, month: 6, day: 18)!),
      ])
    #expect(page.data[3].depthOutline == nil)
  }

  @Test func capturedDiveDetail() throws {
    let dive = try KitFixture.roundTrip(DiveReadWithMixtures.self, "dive-detail")
    #expect(dive.mixtures.first?.oxygen == 31)
    #expect(dive.recordings.first?.profile?.channels.contains("surface_gradient_factor") == true)
    #expect(dive.gasUse == nil)
  }

  @Test func aDiveWithTwoRecordingsAndTwoCylinders() throws {
    let dive = try KitFixture.roundTrip(DiveReadWithMixtures.self, "dive-two-recordings")
    #expect(dive.recordings.map(\.ordinal) == [0, 1])
    #expect(dive.recordings[1].startedAt?.utcOffsetMinutes == nil)
    #expect(dive.recordings[1].decoModel?.conservatism == -1)
    #expect(dive.recordings[1].profile?.channels.count == 10)
    #expect(dive.mixtures.map(\.gasNumber) == [1, 2])
    #expect(dive.mixtures[0].gearItem?.brand == "Faber")
    #expect(dive.mixtures[1].helium == nil)
    #expect(dive.gasUse?.tanks.first?.secondsOnGas == 2355)
    #expect(dive.people.first?.role == "buddy")
    #expect(dive.diveSites.first?.location?.name == "Dahab, South Sinai, Egypt")
  }

  @Test func vocabularyValuesThisVersionHasNeverSeenKeepTheirWireString() throws {
    let dive = try KitFixture.roundTrip(DiveReadWithMixtures.self, "dive-two-recordings")
    #expect(dive.waterType == "lake")
    #expect(dive.sightings[1].abundance == "teeming")
    #expect(dive.recordings[1].salinity == "en13319")
  }

  @Test func capturedProfile() throws {
    let profile = try KitFixture.roundTrip(RecordingProfileRead.self, "profile")
    #expect(profile.provenance == "file")
    #expect(profile.events.first?.type == "gas_switch")
    #expect(profile.ppo2 == nil)
  }

  @Test func aProfileWithEveryChannel() throws {
    let profile = try KitFixture.roundTrip(RecordingProfileRead.self, "profile-all-channels")
    let series = [
      profile.depth, profile.ceiling, profile.temperature, profile.ndl, profile.tts,
      profile.ppo2, profile.cns, profile.gradientFactor, profile.surfaceGradientFactor,
    ]
    #expect(series.allSatisfy { $0?.times.count == 4 })
    #expect(profile.pressures.map(\.gasNumber) == [1, 2])
    #expect(profile.temperature?.values.first == 2719)
    #expect(profile.diveEndTime == 28000)
  }

  @Test func anUnclassifiedEventAndAnUnknownOne() throws {
    let events = try KitFixture.roundTrip(RecordingProfileRead.self, "profile-all-channels").events
    #expect(events[1].type == nil)
    #expect(events[1].label == "Ceiling Broken")
    #expect(events[2].type == "vendor_new_alarm")
  }

  @Test func neighbors() throws {
    let neighbors = try KitFixture.roundTrip(DiveNeighbors.self, "dive-neighbors")
    #expect(neighbors.previous?.diveNumber == 531)
    #expect(neighbors.next == nil)
  }

  @Test func trip() throws {
    let trip = try KitFixture.roundTrip(TripRead.self, "trip")
    #expect(trip.parts.first?.startDate == CalendarDate(year: 2026, month: 9, day: 6))
    #expect(trip.parts.first?.endDate == nil)
    #expect(trip.parts.first?.location?.name == "Dahab, Egypt")
  }

  @Test func diveSite() throws {
    let site = try KitFixture.roundTrip(DiveSiteRead.self, "dive-site")
    #expect(site.lastDivedOn == CalendarDate(year: 2026, month: 4, day: 17))
    #expect(site.latitude == nil)
  }

  @Test func course() throws {
    let course = try KitFixture.roundTrip(CourseRead.self, "course")
    #expect(course.people.first?.role == "instructor")
    #expect(course.endDate == CalendarDate(year: 2025, month: 9, day: 25))
  }

  @Test func contact() throws {
    let contact = try KitFixture.roundTrip(ContactRead.self, "contact")
    #expect(contact.address?.country == "Thailand")
    #expect(contact.roles == ["dive_center", "school", "shop"])
  }

  @Test func aCertificationWithOneSideMissing() throws {
    let card = try KitFixture.roundTrip(CertificationRead.self, "certification-front-only")
    #expect(card.file(side: "front")?.contentType == "image/webp")
    #expect(card.file(side: "back") == nil)
    #expect(card.expiresOn == nil)
  }

  @Test func speciesLifeList() throws {
    let page = try KitFixture.roundTrip(
      PaginatedListResponse<SpeciesLifeListEntry>.self, "species-life-list")
    #expect(page.data[0].firstSeen.utcOffsetMinutes == nil)
    #expect(page.data[1].lastSeen == .day(CalendarDate(year: 2002, month: 6, day: 18)!))
  }

  @Test func instanceConfigAndHealth() throws {
    #expect(try KitFixture.roundTrip(InstanceConfigRead.self, "config").mapTiles == true)
    #expect(try KitFixture.roundTrip(HealthRead.self, "health").status == "healthy")
  }

  @Test func theThreeSignInOutcomes() throws {
    #expect(
      try KitFixture.roundTrip(AuthOutcome.self, "auth-outcome-authenticated").accessToken
        == "access-1")
    #expect(
      try KitFixture.roundTrip(AuthOutcome.self, "auth-outcome-onboarding").onboardingToken
        == "onb")
    let pending = try KitFixture.roundTrip(AuthOutcome.self, "auth-outcome-deletion-pending")
    #expect(pending.purgeAfter?.instant == Date(timeIntervalSince1970: 1_795_255_200))
  }
}

private enum PictureCropFixture {
  static let portrait = try? APICoding.decoder().decode(
    PictureCrop.self, from: Data(#"{"x":0,"y":47,"width":1080,"height":1389}"#.utf8))
}
