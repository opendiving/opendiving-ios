import OpenDivingKit
import SwiftUI

/// One of the diver's sites as a trip's card, on a species' page: a map of its pin over its name,
/// facts and figures, then a proposal waiting on it, and a Commons record's mark and credit.
struct YourDiveSiteCard: View {
  let content: YourDiveSiteCardContent

  var body: some View {
    RecordCardView(content: content.card, icon: .tabDiveSite) {
      if content.isWaitingForReview || content.isCommons {
        HStack(spacing: 8) {
          if content.isWaitingForReview {
            BadgeView(DiveSiteProposalSummary.waitingForReview, style: .outline)
          }
          if content.isCommons {
            DiveSiteMarkBadge(mark: .commons)
            if let credit = content.credit {
              AttributionLine(credits: [credit])
            }
          }
        }
      }
    }
    .contentShape(Rectangle())
  }
}

#Preview {
  let row =
    #"{"kind":"site","uuid":"01a14b2e-0c3d-7a10-9f00-4a2b3c4d5e6f","owner":"account","saved":true,"#
    + #""attribution":null,"name":"Canyon","other_names":[],"latitude":28.5687,"#
    + #""longitude":34.5372,"location":{"name":"Dahab, South Sinai, Egypt","#
    + #""latitude":28.4963633,"longitude":34.5145652,"#
    + #""bbox_south":null,"bbox_north":null,"bbox_west":null,"bbox_east":null},"external_ids":[],"#
    + #""water_type":"salt","altitude":0,"entry_types":["shore"],"distance_m":null,"match":null,"#
    + #""depth_from":12,"depth_to":52,"dives":{"dive_count":3,"last_dived_on":"2026-09-14","#
    + #""max_dive_depth":31.4,"species_count":7,"average_rating":4.5},"proposal":null}"#
  let decoded = try! APICoding.decoder().decode(DiveSiteSearchRow.self, from: Data(row.utf8))
  YourDiveSiteCard(content: YourDiveSiteCardContent(decoded, units: .metric)!)
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
