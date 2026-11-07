import Foundation
import OpenDivingKit
import Testing

/// What the propose flow and the site form are given to print, and the words sent back.
struct DiveSiteCommonsProposalTextTests {
  private func site(_ changes: [String: Any] = [:]) throws -> DiveSiteRead {
    var object =
      try JSONSerialization.jsonObject(with: Data(KitFixture.text("dive-site").utf8))
      as! [String: Any]
    object.merge(changes) { _, new in new }
    return try APICoding.decoder().decode(
      DiveSiteRead.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func proposal(_ status: String) -> [String: Any] {
    [
      "uuid": "01a15c10-7d3e-7b21-9a44-5e6f7a8b9c0d", "kind": "new_site", "status": status,
      "created_at": "2026-10-30T08:15:02.114522Z",
    ]
  }

  /// `ATTESTATIONS` in `src/app/schemas/dive_site_proposal.py` at `opendiving-api` `b1150b7`.
  @Test func theAttestationsAreTheApisWordForWord() {
    #expect(
      CommonsAttestations.newSite
        == "I am adding this dive site from my own diving. It is not copied from another "
        + "database, app or publication. I dedicate it to the public domain under CC0 1.0.")
    #expect(
      CommonsAttestations.change
        == "I am proposing this change from my own diving. It is not copied from another "
        + "database, app or publication. I dedicate it to the public domain under CC0 1.0.")
  }

  @Test func theChoiceIsOfferedOnlyWhereTheServerTakesProposals() throws {
    #expect(DiveSiteProposalSummary.choice(nil, isPrimary: false) == nil)
    #expect(DiveSiteProposalSummary.choice(try site(), isPrimary: false) == nil)
    #expect(DiveSiteProposalSummary.choice(nil, isPrimary: true) == .open)
    #expect(DiveSiteProposalSummary.choice(try site(), isPrimary: true) == .open)
  }

  @Test func theChoiceLocksWhileAProposalWaitsAndReadsPrivateAfterADecline() throws {
    let waiting = try site(["proposal": proposal("waiting")])
    #expect(DiveSiteProposalSummary.choice(waiting, isPrimary: true) == .locked)
    let declined = try site(["proposal": proposal("declined")])
    #expect(DiveSiteProposalSummary.choice(declined, isPrimary: true) == .open)
  }

  @Test func aCommonsRecordHasNoChoice() throws {
    let record = try site(["owner": DiveSiteOwner.commons])
    #expect(DiveSiteProposalSummary.choice(record, isPrimary: true) == nil)
  }

  @Test func aMatchSaysItsRuleAndItsDistanceInTheDiversUnits() throws {
    let matches = try KitFixture.decode(
      [DiveSiteCommonsMatchRead].self, "dive-site-commons-matches")
    let near = DiveSiteCommonsMatchSummary.row(matches[0], units: .metric)
    #expect(near.reason == "Within 20 m, whatever the name · 12 m away")
    #expect(near.locality == "Dahab")
    #expect(near.credit?.contains("OpenStreetMap") == true)
    #expect(near.siblings == nil)
    #expect(near.target.name == "Blue Hole")
    #expect(
      DiveSiteCommonsMatchSummary.row(matches[0], units: .imperial).reason
        == "Within 20 m, whatever the name · 41 ft away")

    let far = DiveSiteCommonsMatchSummary.row(matches[1], units: .metric)
    #expect(far.reason == "Shares a registry entry")
    #expect(far.locality == nil)
    #expect(far.siblings?.contains("West or East") == true)
  }

  @Test func everyRuleHasItsLabelAndALaterOneReadsAsSent() {
    #expect(
      DiveSiteCommonsMatchSummary.ruleLabel("similar_name_within_200_m")
        == "A similar name within 200 m")
    #expect(
      DiveSiteCommonsMatchSummary.ruleLabel("same_name_within_5_km")
        == "The same name within 5 km")
    #expect(DiveSiteCommonsMatchSummary.ruleLabel("new_rule") == "new_rule")
  }

  @Test func theReviewShowsThePinAsItWouldBeStored() throws {
    let review = DiveSiteProposalReview(
      try site(["latitude": 28.57221234567, "longitude": -34.5]), units: .metric)
    let pin = review.rows.first { $0.label == "Pin" }
    #expect(pin?.value == "28.572212, -34.5")
    #expect(review.pin?.latitude == 28.572212)
    #expect(review.pin?.longitude == -34.5)
    #expect(review.identifier == "01a0a521-28c5-7e34-a572-4d7324f5033b")
  }

  @Test func theReviewLeavesAnEmptyMemberForNotRecorded() throws {
    let review = DiveSiteProposalReview(try site(), units: .metric)
    #expect(
      review.rows.map(\.label) == [
        "Name", "Other names", "Pin", "Location", "Depth from", "Depth to", "Water type",
        "Altitude", "Entry types", "Registries",
      ])
    let empty = review.rows.filter { $0.value == nil }.map(\.label)
    #expect(empty.contains("Pin"))
    #expect(empty.contains("Registries"))
    #expect(review.rows.first { $0.label == "Location" }?.value == "Dahab, Egypt")
    #expect(review.pin == nil)
  }

  @Test func theReviewPrintsDepthsInTheDiversUnitsAndRegistriesByName() throws {
    let review = DiveSiteProposalReview(
      try site([
        "depth_from": 10,
        "external_ids": [["registry": "openstreetmap", "identifier": "node/1"]],
      ]), units: .imperial)
    #expect(review.rows.first { $0.label == "Depth from" }?.value?.hasSuffix("ft") == true)
    #expect(review.rows.first { $0.label == "Registries" }?.value?.hasSuffix("node/1") == true)
  }

  @Test func aReplaceSaysWhatBecomesOfTheSiteAndADraft() {
    let message = DiveSiteProposalSummary.replaceMessage(site: "Canyon", record: "The Canyon")
    #expect(message.contains("Your dives at Canyon will name The Canyon instead"))
    #expect(message.contains("a dive draft naming it names The Canyon"))
  }
}
