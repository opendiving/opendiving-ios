import Foundation
import Testing

@testable import OpenDivingKit

/// How a site is marked, and how the finder's map gathers the diver's sites and the Commons'.
struct DiveSiteMarkTests {
  @Test func aSiteIsCommonsProposedOrPrivate() {
    #expect(
      DiveSiteMark(owner: DiveSiteOwner.commons, proposalStatus: DiveSiteProposalStatus.waiting)
        == .commons)
    #expect(
      DiveSiteMark(owner: DiveSiteOwner.account, proposalStatus: DiveSiteProposalStatus.waiting)
        == .proposed)
    #expect(
      DiveSiteMark(owner: DiveSiteOwner.account, proposalStatus: DiveSiteProposalStatus.declined)
        == .private)
    #expect(DiveSiteMark(owner: DiveSiteOwner.account, proposalStatus: nil) == .private)
    #expect(DiveSiteMark.allCases.max() == .commons)
    #expect(DiveSiteMark.proposed > .private)
  }

  @Test func theMapsMarksAreOneListWithTheDiversCopyOfASavedRecord() {
    let saved = UUID()
    let commons = CommonsDiveSitePoints(
      version: "1", sources: [:],
      points: [
        CommonsDiveSitePoint(longitude: 1, latitude: 2, uuid: saved, name: "Bells", source: "osm"),
        CommonsDiveSitePoint(longitude: 3, latitude: 4, uuid: UUID(), name: "Arch", source: "osm"),
      ])
    let own = UUID()
    let yours = [
      DiveSitePoint(
        longitude: 1, latitude: 2, uuid: saved, name: "Bells", owner: DiveSiteOwner.commons),
      DiveSitePoint(
        longitude: 5, latitude: 6, uuid: own, name: "Home reef", owner: DiveSiteOwner.account,
        proposal: DiveSiteProposalStatus.waiting),
    ]
    let marks = SiteFinderMapMark.marks(commons: commons, yours: yours)
    #expect(marks.map(\.mark) == [.commons, .proposed, .commons])
    #expect(marks.filter { $0.uuid == saved }.count == 1)
    #expect(SiteFinderMapMark.marks(commons: nil, yours: yours).map(\.uuid) == [saved, own])
  }
}
