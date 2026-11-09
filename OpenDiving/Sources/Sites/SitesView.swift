import OpenDivingKit
import SwiftUI

/// The *Sites* tab: the site finder over the diver's sites and the Commons, full screen under no
/// bar, each site opening its page, the `+` that adds one and a long press on the map that adds
/// one where it was pressed. Under *Your sites* it is the diver's list, the most recently dived
/// first, as cards.
struct SitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      SitesFinder(session: session)
        // Never shown: it is what a site's page offers to go back to.
        .navigationTitle("Sites")
        .toolbar(.hidden, for: .navigationBar)
    }
  }
}

extension SitesView {
  /// The tab's finder, which opens on the phone's location, a trip under way or the last dive.
  static func finder(_ session: Session) -> SiteFinderModel {
    SiteFinderModel(
      session: session, locator: CoreLocationProvider(), today: CalendarDate.today())
  }
}

private struct SitesFinder: View {
  @State private var model: SiteFinderModel
  @State private var map: MapStyleModel
  /// The site a row or a point opened.
  @State private var opened: UUID?
  /// Where a long press asked for a new site.
  @State private var adding: PinnedNewSite?
  @Environment(Session.self) private var session

  init(session: Session) {
    _model = State(initialValue: SitesView.finder(session))
    _map = State(initialValue: MapStyleModel(session: session))
  }

  var body: some View {
    SiteFinderView(
      model: model, map: map, units: session.units, pointAction: "Open site", showsCards: true,
      onSite: { site in opened = site.ref.serverUUID },
      onLongPress: { adding = PinnedNewSite(pin: $0) },
      leading: { proposalsButton },
      trailing: {
        NavigationLink {
          DiveSiteFormView(mode: .create)
        } label: {
          Image(Icon.plus)
        }
        .accessibilityLabel("Add dive site")
        .buttonStyle(MapRoundButtonStyle())
      }
    )
    .navigationDestination(item: $opened) { SiteDetailView(siteUUID: $0) }
    .navigationDestination(item: $adding) { DiveSiteFormView(mode: .create, pin: $0.pin) }
    // Nothing else on this tab asks the server what it is until a card with a pin draws its map.
    .task { await session.loadServerInfo() }
  }

  /// Only where the instance takes proposals, whose routes answer nowhere else.
  @ViewBuilder private var proposalsButton: some View {
    if session.isCommonsPrimary {
      NavigationLink {
        YourProposalsView()
      } label: {
        CommonsMark(side: 22, relativeTo: .body)
      }
      .accessibilityLabel(YourProposalsView.title)
      .buttonStyle(MapRoundButtonStyle())
    }
  }
}

/// A new site asked for at a point of the map, which the form opens pinned to.
private struct PinnedNewSite: Hashable, Identifiable {
  let id = UUID()
  let pin: DeviceLocation
}

#Preview {
  SitesView()
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
