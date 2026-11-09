import OpenDivingKit
import SwiftUI

/// The *Sites* tab: the site finder over the diver's sites and the Commons, full screen under a
/// top bar with no background, each site opening its page, the weather at the map's centre, the
/// `+` that adds one and a long press on the map that adds one where it was pressed. Under *Your
/// sites* it is the diver's list, the most recently dived first, as cards.
struct SitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      SitesFinder(session: session)
        // Never shown: it is what a site's page offers to go back to.
        .navigationTitle("Sites")
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
  @State private var weather: MapWeatherModel
  /// The site a row or a point opened.
  @State private var opened: UUID?
  /// Where a long press asked for a new site.
  @State private var adding: PinnedNewSite?
  @Environment(Session.self) private var session

  init(session: Session) {
    _model = State(initialValue: SitesView.finder(session))
    _map = State(initialValue: MapStyleModel(session: session))
    _weather = State(initialValue: MapWeatherModel(session: session))
  }

  var body: some View {
    SiteFinderView(
      model: model, map: map, units: session.units, pointAction: "Open site", showsCards: true,
      onSite: { site in opened = site.ref.serverUUID },
      onLongPress: { adding = PinnedNewSite(pin: $0) },
      bar: {
        if session.isCommonsPrimary {
          ToolbarItem(placement: .topBarLeading) { proposalsButton }
        }
        // Always there, even empty: it stands in for the title, which names the back button on
        // what the tab opens and is never shown over the map.
        ToolbarItem(placement: .principal) {
          if let current = weather.current,
            let content = MapWeatherContent(current, units: session.units)
          {
            MapWeatherBar(content: content)
          } else {
            Color.clear.frame(width: 1, height: 1)
          }
        }
        ToolbarItem(placement: .primaryAction) {
          NavigationLink {
            DiveSiteFormView(mode: .create)
          } label: {
            Label("Add dive site", systemImage: "plus")
          }
          .mapBarButton()
        }
      }
    )
    .navigationDestination(item: $opened) { SiteDetailView(siteUUID: $0) }
    .navigationDestination(item: $adding) { DiveSiteFormView(mode: .create, pin: $0.pin) }
    .task(id: weatherCell) { [weatherCell] in await weather.show(weatherCell) }
    // Nothing else on this tab asks the server what it is until a card with a pin draws its map.
    .task { await session.loadServerInfo() }
  }

  /// Where the bar's weather is for: the map's centre, and nowhere with no map.
  private var weatherCell: MapWeatherModel.Cell? {
    map.hasMap ? MapWeatherModel.cell(model.camera) : nil
  }

  /// Only where the instance takes proposals, whose routes answer nowhere else.
  private var proposalsButton: some View {
    NavigationLink {
      YourProposalsView()
    } label: {
      CommonsMark(side: 22, relativeTo: .body)
    }
    .accessibilityLabel(YourProposalsView.title)
    .mapBarButton()
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
