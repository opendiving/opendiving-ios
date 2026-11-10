import Foundation
import Testing

@testable import OpenDivingKit

/// The web's `lib/gear-service.test.ts` at its pin, row for row, less the bell's qualifier and
/// the form's presets.
struct GearServiceTests {
  private struct Due: GearServiceDue {
    var nextDueOn: CalendarDate?
    var nextDueAtDiveCount: Int?
    var nextDueAtDiveTime: Int?
    var isActive = true
  }

  private let today = day("2026-08-10")
  private static let hour = 3600

  private static func day(_ text: String) -> CalendarDate { CalendarDate(iso8601: text)! }

  private func schedule(
    on: String? = nil, dives: Int? = nil, time: Int? = nil, active: Bool = true
  ) -> Due {
    Due(
      nextDueOn: on.map(Self.day), nextDueAtDiveCount: dives, nextDueAtDiveTime: time,
      isActive: active)
  }

  private func status(_ schedule: Due, _ diveCount: Int = 0, _ diveTime: Int = 0)
    -> GearServiceStatus
  {
    GearServiceStatus(schedule, diveCount: diveCount, diveTime: diveTime, today: today)
  }

  private func due(_ schedule: Due, _ diveCount: Int = 0, _ diveTime: Int = 0) -> String {
    GearServiceText.due(schedule, diveCount: diveCount, diveTime: diveTime, today: today)
  }

  private func next(_ schedules: [Due], _ diveCount: Int, _ diveTime: Int)
    -> GearServiceText.NextService?
  {
    GearServiceText.nextService(schedules, diveCount: diveCount, diveTime: diveTime, today: today)
  }

  private func worst(_ schedules: [Due]) -> GearServiceStatus? {
    GearServiceStatus.worst(schedules, diveCount: 0, diveTime: 0, today: today)
  }

  // MARK: - serviceStatus

  @Test func statusByTheDateArm() {
    #expect(status(schedule()) == .ok)
    #expect(status(schedule(on: "2027-08-10")) == .ok)
    #expect(status(schedule(on: "2026-08-20")) == .dueSoon)
    #expect(status(schedule(on: "2026-08-10")) == .overdue)
    #expect(status(schedule(on: "2026-08-09")) == .overdue)
    // 30 days out is due soon; 31 is not.
    #expect(status(schedule(on: "2026-09-09")) == .dueSoon)
    #expect(GearServiceStatus.dueSoonDays == 30)
    #expect(status(schedule(on: "2026-09-10")) == .ok)
  }

  @Test func statusByTheDiveArm() {
    let s = schedule(dives: 140)
    #expect(status(s, 40) == .ok)
    #expect(status(s, 140 - GearServiceStatus.dueSoonDives) == .dueSoon)
    #expect(status(s, 140 - GearServiceStatus.dueSoonDives - 1) == .ok)
    #expect(status(s, 140) == .overdue)
    #expect(status(s, 207) == .overdue)
  }

  @Test func statusByTheHoursArmInSecondsOfDiveTime() {
    let hour = Self.hour
    let s = schedule(time: 50 * hour)
    #expect(status(s, 0, 30 * hour) == .ok)
    #expect(status(s, 0, (50 - GearServiceStatus.dueSoonHours) * hour) == .dueSoon)
    #expect(status(s, 0, (50 - GearServiceStatus.dueSoonHours) * hour - 1) == .ok)
    #expect(status(s, 0, 50 * hour) == .overdue)
    #expect(status(s, 0, 50 * hour + 1) == .overdue)
  }

  @Test func theMostUrgentArmWins() {
    let hour = Self.hour
    let all = schedule(on: "2027-08-10", dives: 140, time: 50 * hour)
    #expect(status(all, 40, 51 * hour) == .overdue)
    #expect(status(all, 40, 45 * hour) == .dueSoon)
    #expect(status(all, 40, 10 * hour) == .ok)
    let both = schedule(on: "2027-08-10", dives: 140)
    #expect(status(both, 150) == .overdue)
    #expect(status(both, 135) == .dueSoon)
    #expect(status(both, 40) == .ok)
  }

  @Test func aPausedScheduleIsOK() {
    #expect(status(schedule(on: "2020-01-01", active: false)) == .ok)
  }

  // MARK: - worstServiceStatus

  @Test func theWorstStatusIsNilWithNothingActive() {
    #expect(worst([]) == nil)
    #expect(worst([schedule(on: "2020-01-01", active: false)]) == nil)
  }

  @Test func theWorstStatusPicksOverdueOverDueSoonOverOK() {
    let ok = schedule(on: "2028-01-01")
    let soon = schedule(on: "2026-08-20")
    let late = schedule(on: "2020-01-01")
    #expect(worst([ok]) == .ok)
    #expect(worst([ok, soon]) == .dueSoon)
    #expect(worst([ok, soon, late]) == .overdue)
    #expect(worst([late, soon, ok]) == .overdue)
  }

  @Test func everyStatusHasItsLabel() {
    #expect(GearServiceStatus.ok.label == "In service")
    #expect(GearServiceStatus.dueSoon.label == "Due soon")
    #expect(GearServiceStatus.overdue.label == "Overdue")
  }

  // MARK: - nextService

  @Test func theNextServiceIsTheEarliestActiveDateOverdueIncluded() {
    let schedules = [
      schedule(on: "2027-01-01"), schedule(on: "2026-01-01"),
      schedule(on: "2025-01-01", active: false), schedule(dives: 50),
    ]
    #expect(next(schedules, 10, 0) == .date(Self.day("2026-01-01")))
  }

  @Test func theNextServiceIsOverdueOnceACountRunsOut() {
    #expect(
      next([schedule(on: "2027-01-01", dives: 100), schedule(on: "2026-09-01")], 120, 0) == .overdue
    )
    #expect(next([schedule(time: 6300), schedule(on: "2026-09-01")], 1, 7200) == .overdue)
  }

  @Test func theNextServiceCountsTheFewestHoursRoundedUp() {
    let hour = Self.hour
    #expect(next([schedule(time: 6300)], 1, 2700) == .hours(remaining: 1))
    #expect(
      next([schedule(time: 100 * hour), schedule(time: 20 * hour)], 0, 8 * hour)
        == .hours(remaining: 12))
  }

  @Test func theNextServicePrefersDivesToHoursAndCountsTheFewest() {
    #expect(
      next([schedule(time: 2 * Self.hour), schedule(dives: 30)], 20, 0) == .dives(remaining: 10))
    #expect(next([schedule(dives: 50), schedule(dives: 30)], 20, 0) == .dives(remaining: 10))
  }

  @Test func thereIsNoNextServiceWithoutAnActiveDuePoint() {
    #expect(next([], 0, 0) == nil)
    #expect(next([schedule(), schedule(on: "2026-01-01", active: false)], 0, 0) == nil)
  }

  // MARK: - formatServiceDue

  @Test func theDueLineCountsByDate() {
    #expect(due(schedule(on: "2026-08-20")) == "Due in 10 days")
    #expect(due(schedule(on: "2026-08-11")) == "Due in 1 day")
    #expect(due(schedule(on: "2026-08-10")) == "Overdue (due today)")
    #expect(due(schedule(on: "2026-08-09")) == "Overdue by 1 day")
    #expect(due(schedule(on: "2026-07-11")) == "Overdue by 30 days")
  }

  @Test func theDueLineCountsByDives() {
    let s = schedule(dives: 140)
    #expect(due(s, 135) == "Due in 5 dives")
    #expect(due(s, 139) == "Due in 1 dive")
    #expect(due(s, 143) == "Overdue by 3 dives")
    #expect(due(schedule(on: "2027-03-01", dives: 140), 143) == "Overdue by 3 dives")
    #expect(due(schedule(on: "2026-08-20", dives: 140), 40) == "Due in 10 days")
  }

  @Test func theDueLineCountsHoursOfDivingRoundedUp() {
    let hour = Self.hour
    let s = schedule(time: 50 * hour)
    #expect(due(s, 0, 38 * hour) == "Due in 12 hours of diving")
    #expect(due(s, 0, 50 * hour - 40 * 60) == "Due in 1 hour of diving")
    #expect(due(s, 0, 53 * hour) == "Overdue by 3 hours of diving")
  }

  @Test func theDueLineNamesTheDiveArmBeforeTheHoursArm() {
    let hour = Self.hour
    let s = schedule(dives: 140, time: 50 * hour)
    #expect(due(s, 143, 53 * hour) == "Overdue by 3 dives")
    #expect(due(s, 135, 40 * hour) == "Due in 5 dives")
    #expect(due(s, 135, 53 * hour) == "Overdue by 3 hours of diving")
  }

  @Test func theDueLineWithNoThreshold() {
    #expect(due(schedule()) == "No due date")
  }

  @Test(
    arguments: [
      (on: "2026-08-10", dives: nil, time: nil),
      (on: "2026-08-09", dives: nil, time: nil),
      (on: nil, dives: 140, time: nil),
      (on: nil, dives: nil, time: 50 * 3600),
    ] as [(on: String?, dives: Int?, time: Int?)])
  func theBadgeAndTheLineAgreeOnOverdue(_ row: (on: String?, dives: Int?, time: Int?)) {
    let s = schedule(on: row.on, dives: row.dives, time: row.time)
    let (count, time) = (row.dives ?? 0, row.time ?? 0)
    #expect(status(s, count, time) == .overdue)
    #expect(due(s, count, time).hasPrefix("Overdue"))
  }

  @Test func nothingInTheFutureIsOverdue() {
    let s = schedule(on: "2026-08-11")
    #expect(status(s) != .overdue)
    #expect(!due(s).contains("Overdue"))
  }

  @Test func hoursOfDivingRoundUp() {
    #expect(GearServiceText.hoursOfDiving(1) == 1)
    #expect(GearServiceText.hoursOfDiving(Self.hour) == 1)
    #expect(GearServiceText.hoursOfDiving(Self.hour + 1) == 2)
    #expect(GearServiceText.countOf(1, .hour) == "1 hour of diving")
    #expect(GearServiceText.countOf(50, .hour) == "50 hours of diving")
    #expect(GearServiceText.countOf(1, .dive) == "1 dive")
  }

  @Test func aGearItemsOwnScheduleIsRead() throws {
    let page = try KitFixture.decode(PaginatedListResponse<GearItemRead>.self, "gear-items-page")
    let regulator = page.data[0]
    #expect(
      GearServiceStatus.worst(
        regulator.service, diveCount: regulator.diveCount, diveTime: regulator.diveTime,
        today: today) == .dueSoon)
    #expect(
      GearServiceText.due(
        regulator.service[0], diveCount: regulator.diveCount, diveTime: regulator.diveTime,
        today: today) == "Due in 22 days")
    let paused = page.data[1]
    #expect(
      GearServiceStatus.worst(paused.service, diveCount: 0, diveTime: 0, today: today) == nil)
  }
}
