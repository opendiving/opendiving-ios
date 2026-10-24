import Foundation
import OpenDivingKit
import Testing

/// The number, the start, the dive time and the volume presets. Golden rows from
/// `src/lib/date-time.test.ts`, `src/components/ui/utc-offset-select.tsx` and
/// `src/components/dives/volume-combobox.tsx` at `opendiving-web` `d5b2d545`.
struct DiveFormInputsTests {
  @Test(arguments: [
    (Int?.none, 0, Int?.none), (nil, 3, nil), (214, 0, 215), (214, 2, 217), (0, 0, 1),
  ])
  func theOfflineNumber(_ highest: Int?, _ queued: Int, _ suggested: Int?) {
    #expect(
      DiveNumberRule.offlineSuggestion(highestKnown: highest, queuedCreates: queued) == suggested)
  }

  @Test func theTakenNotice() throws {
    let free = try KitFixture.decode(DiveNumberSuggestion.self, "dive-number-suggestion")
    #expect(DiveNumberRule.takenNotice(free) == nil)
    let taken = try APICoding.decoder().decode(
      DiveNumberSuggestion.self, from: Data(#"{"dive_number": 12, "is_taken": true}"#.utf8))
    #expect(
      DiveNumberRule.takenNotice(taken)
        == "Another dive is already numbered #12. That's expected while back-filling a log - you can tidy the numbering from the dive list once everything is in."
    )
  }

  /// date-time.test.ts:397-424.
  @Test func theDiveTime() {
    #expect(DiveDuration.formText(seconds: 45 * 60 + 30) == "45:30")
    #expect(DiveDuration.formText(seconds: 65) == "1:05")
    #expect(DiveDuration.formText(seconds: 0) == "0:00")
    #expect(DiveDuration.seconds(fromForm: "45:30") == 2730)
    #expect(DiveDuration.seconds(fromForm: "45") == 2700)
    #expect(DiveDuration.seconds(fromForm: "0") == 0)
    #expect(DiveDuration.seconds(fromForm: DiveDuration.formText(seconds: 125)) == 125)
    for refused in ["", "10:60", "1030", "45:", ":30", "4:5", "abc", "-5", "٤٥"] {
      #expect(DiveDuration.seconds(fromForm: refused) == nil, "\(refused)")
    }
  }

  /// date-time.test.ts:173-189 and utc-offset-select.tsx:11-22.
  @Test func theOffsets() {
    #expect(DiveStart.offsets.count == 105)
    #expect(DiveStart.offsets.first == -720)
    #expect(DiveStart.offsets.last == 840)
    #expect(DiveStart.offsetLabel(120) == "UTC+02:00")
    #expect(DiveStart.offsetLabel(-300) == "UTC-05:00")
    #expect(DiveStart.offsetLabel(0) == "UTC+00:00")
    #expect(DiveStart.offsetLabel(345) == "UTC+05:45")
    #expect(DiveStart.offsetLabel(nil) == "Not recorded")
  }

  /// *Not recorded* only while the dive being edited has no offset.
  @Test func notRecordedIsOfferedOnlyForADiveWithoutOne() throws {
    #expect(DiveStart.offsetChoices().first == -720)
    let known = try KitFixture.decode(DiveReadWithMixtures.self, "dive-edit")
    #expect(!DiveStart.offsetChoices(editing: known).contains(nil))
    let detail = try KitFixture.text("dive-edit").replacingOccurrences(
      of: #""start_time": "2026-10-20T09:15:00+03:00""#,
      with: #""start_time": "2026-10-20T09:15:00""#)
    let unknown = try APICoding.decoder().decode(DiveReadWithMixtures.self, from: Data(detail.utf8))
    #expect(DiveStart.offsetChoices(editing: unknown).first == .some(nil))
  }

  /// A new dive starts now on the phone's clock, to the second, with the zone's offset.
  static let clocks: [(seconds: Int, offset: Int, wire: String)] = [
    (0, 0, "1970-01-01T00:00:00Z"),
    (1_792_400_000, 10_800, "2026-10-19T11:53:20+03:00"),
    (1_792_400_000, -34_200, "2026-10-18T23:23:20-09:30"),
    (1_792_400_000, 20_700, "2026-10-19T14:38:20+05:45"),
    (951_782_400, 0, "2000-02-29T00:00:00Z"),
  ]

  @Test(arguments: clocks)
  func now(_ seconds: Int, _ offset: Int, _ wire: String) {
    let start = DiveStart.now(
      Date(timeIntervalSince1970: Double(seconds) + 0.7), in: TimeZone(secondsFromGMT: offset)!)
    #expect(start.wireValue == wire)
  }

  /// volume-combobox.tsx:83-156 and `volumeGroupsFor`: every group to every diver, the
  /// reader's family first, twin sets last.
  @Test func theVolumePresets() {
    #expect(
      VolumePresets.groups(for: .metric).map(\.title) == [
        "Metric singles", "US aluminium", "US steel", "Twin sets",
      ])
    #expect(
      VolumePresets.groups(for: .imperial, recent: [11.1, 12]).map(\.title) == [
        "Recently used", "US aluminium", "US steel", "Metric singles", "Twin sets",
      ])
    let al80 = VolumePresets.groups[2].presets[4]
    #expect(al80.label(.metric) == "11.1 L (AL80)")
    #expect(al80.label(.imperial) == "AL80 (11.1 L)")
    #expect(VolumePresets.groups[0].presets[3].label(.imperial) == "10 L")
    #expect(VolumePresets.groups.map(\.presets.count) == [8, 4, 6, 9])
    #expect(VolumePresets.isTwinSet(22.2))
    #expect(!VolumePresets.isTwinSet(11.1))
    #expect(VolumePresets.groups(for: .metric, recent: [12]).first?.presets.first?.label == "12 L")
  }

  @Test func addTankIsElevenLitresOfAir() {
    #expect(TankValues.added == TankValues(volume: 11.1, oxygen: 21, helium: 0))
  }
}
