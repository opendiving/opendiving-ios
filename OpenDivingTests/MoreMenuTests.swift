import OpenDivingKit
import SwiftUI
import Testing
import UIKit

@testable import OpenDiving

/// The profile's *More*: its rows in the web's order and groups, and every screen they and the
/// record pages open, each hosted by the initializer its callers use.
@MainActor
struct MoreMenuTests {
  @Test func theRowsFollowTheWebsNavigationRuledOffAsItIs() {
    #expect(
      MoreRow.sections(isCommonsPrimary: true) == [
        [.diveSites, .marineLife],
        [.gear, .certifications, .courses, .people, .contacts],
        [.imports, .proposals],
      ])
    #expect(
      MoreRow.sections(isCommonsPrimary: true).flatMap { $0 }.map(\.title) == [
        "Dive Sites", "Marine Life", "Gear", "Certifications", "Courses", "People", "Contacts",
        "Import", "Your Proposals",
      ])
  }

  @Test func theProposalsAreOfferedOnlyWhereTheInstanceTakesThem() {
    #expect(!MoreRow.sections(isCommonsPrimary: false).flatMap { $0 }.contains(.proposals))
    #expect(MoreRow.sections(isCommonsPrimary: false).last == [.imports])
  }

  @Test func everyRowButTheProposalsDrawsOneOfTheAppsSymbols() {
    #expect(MoreRow.allCases.filter { $0.icon == nil } == [.proposals])
  }

  private func host(_ view: some View) -> UIView? {
    let session = Session.stub(transport: StubTransport(routes: [:]))
    let host = UIHostingController(
      rootView: NavigationStack { view }.environment(session)
        .environment(OutboxModel(session: session)).environment(InboxModel(session: session)))
    host.loadViewIfNeeded()
    host.view.layoutIfNeeded()
    return host.viewIfLoaded
  }

  @Test func theMenuHosts() {
    #expect(host(ScrollView { MoreMenu(isCommonsPrimary: true) }) != nil)
  }

  @Test func theListsHost() {
    #expect(host(GearListView()) != nil)
    #expect(host(CertificationListView()) != nil)
    #expect(host(CourseListView()) != nil)
    #expect(host(PeopleListView()) != nil)
    #expect(host(ContactListView()) != nil)
    #expect(host(MarineLifeListView()) != nil)
    #expect(host(YourDiveSitesView()) != nil)
  }

  @Test func thePagesHostWithAUUID() {
    #expect(host(GearItemDetailView(gearItemUUID: UUID())) != nil)
    #expect(host(CertificationDetailView(certificationUUID: UUID())) != nil)
    #expect(host(CourseDetailView(courseUUID: UUID())) != nil)
    #expect(host(PersonDetailView(personUUID: UUID())) != nil)
    #expect(host(SpeciesDetailView(speciesUUID: UUID())) != nil)
  }

  @Test func theFormsHostOnEveryOpening() {
    let item = UUID()
    let record = UUID()
    #expect(host(GearItemFormView(mode: .failed(item: item, record: record))) != nil)
    #expect(host(GearSetFormView(mode: .create)) != nil)
    #expect(host(CourseFormView(mode: .failed(item: item, record: record))) != nil)
    #expect(host(PersonFormView(mode: .failed(item: item, record: record))) != nil)
    #expect(host(ContactFormView(mode: .failed(item: item, record: record))) != nil)
    #expect(host(CertificationFormView(mode: .create, failedItem: item)) != nil)
    #expect(
      host(ServiceScheduleFormView(gearItem: .server(record), mode: .create, failedItem: item))
        != nil)
    #expect(
      host(ServiceRecordFormView(gearItem: .local(record), mode: .edit(UUID()), schedule: nil))
        != nil)
  }
}
