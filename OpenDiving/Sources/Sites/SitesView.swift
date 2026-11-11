import OpenDivingKit
import SwiftUI

/// What the app opens on signed in: the site finder over the diver's sites and the Commons, full
/// screen under a top bar with no background, each site opening in the panel, the weather at the
/// open site or else, zoomed in, at the site nearest the middle, the diver's picture that opens
/// their profile, and a long press on the map that adds a site where it was pressed. Under *Your
/// sites* it is the diver's list, the most recently dived first.
struct SitesView: View {
  @Environment(Session.self) private var session

  var body: some View {
    NavigationStack {
      SitesFinder(session: session, site: nil)
    }
  }
}

/// The sites map pushed opened on one site, its panel showing it: where a dive's page, the
/// diver's proposals and a proposal's Commons matches open a site.
struct SiteMapView: View {
  let siteUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    SitesFinder(session: session, site: siteUUID)
  }
}

extension SitesView {
  /// The finder, which opens on `site`, else the phone's location, a trip under way or the last
  /// dive.
  static func finder(_ session: Session, site: UUID?) -> SiteFinderModel {
    SiteFinderModel(
      session: session, locator: CoreLocationProvider(), today: CalendarDate.today(), site: site)
  }
}

private struct SitesFinder: View {
  @State private var model: SiteFinderModel
  @State private var map: MapStyleModel
  @State private var weather: MapWeatherModel
  @State private var avatar: AvatarModel
  /// The map is pushed opened on a site rather than being the app's root, so it has no way to the
  /// profile or the proposals of its own.
  private let isPushed: Bool
  /// Where a long press asked for a new site.
  @State private var adding: PinnedNewSite?
  /// How far the weather bar is grown into its card.
  @State private var weatherMorph = MapWeatherMorph()
  /// Where the weather bar is drawn, for its card to grow from.
  @State private var weatherBarFrame = CGRect.zero
  @Environment(Session.self) private var session

  init(session: Session, site: UUID?) {
    isPushed = site != nil
    _model = State(initialValue: SitesView.finder(session, site: site))
    _map = State(initialValue: MapStyleModel(session: session))
    _weather = State(initialValue: MapWeatherModel(session: session))
    _avatar = State(initialValue: AvatarModel(session: session))
  }

  var body: some View {
    SiteFinderView(
      model: model, map: map, units: session.units,
      onLongPress: { adding = PinnedNewSite(pin: $0) },
      site: { site in
        SitePanelView(
          siteUUID: site.uuid, onRead: { model.read($0) }, onOpen: { model.open(uuid: $0) })
      },
      siteAction: { opened in
        if let site = opened.site, !site.isUnsavedCommons {
          NavigationLink {
            DiveSiteFormView(
              mode: .edit(site), onDeleted: { model.closeSite() },
              onReplaced: { model.open(uuid: $0) })
          } label: {
            Image(systemName: "pencil")
              .panelRoundButton()
          }
          .accessibilityLabel("Edit dive site")
          .buttonStyle(.plain)
        }
      },
      bar: {
        if session.isCommonsPrimary && !isPushed {
          ToolbarItem(placement: .topBarLeading) { proposalsButton }
        }
        // Always there, even empty: it stands in for the title, which names the back button on
        // what the map opens and is never shown over it.
        ToolbarItem(placement: .principal) {
          if let content = weatherContent {
            MapWeatherBar(
              content: content, onTap: weatherMorph.open, onPull: weatherMorph.pull,
              onPullEnded: weatherMorph.pullEnded
            )
            .onGeometryChange(for: CGRect.self) {
              $0.frame(in: .global)
            } action: {
              weatherBarFrame = $0
            }
            // The card's copy of it stands in its place while the card is open.
            .opacity(weatherMorph.coversBar ? 0 : 1)
          } else if weather.isUnreachable {
            MapWeatherOfflineBar()
          } else {
            Color.clear.frame(width: 1, height: 1)
          }
        }
        if !isPushed {
          ProfileToolbarItem(avatar: avatar)
        }
      }
    )
    // Never shown: it is what a page pushed from the map offers to go back to.
    .navigationTitle("Sites")
    .navigationDestination(item: $adding) { DiveSiteFormView(mode: .create, pin: $0.pin) }
    .fullScreenCover(isPresented: $weatherMorph.isPresented) {
      if let content = weatherContent {
        MapWeatherExplainer(
          content: content, title: weatherTitle, barFrame: weatherBarFrame, morph: weatherMorph
        )
        .presentationBackground(.clear)
      }
    }
    // A failed ask or a lost session takes the weather away with the card open: with nothing left
    // to draw, nor to close it from, the presentation ends rather than stay over the app.
    .onChange(of: weatherContent == nil) { _, isGone in
      if isGone { weatherMorph.dismiss() }
    }
    .task(id: weatherAsk) { [weatherShown] in await weather.show(weatherShown) }
    .task { await weather.followRoute() }
    .task(id: session.user?.avatarSha256) { if !isPushed { await avatar.load() } }
    .task { if !isPushed { await avatar.followRoute() } }
    // Nothing else here asks the server what it is until a card with a pin draws its map.
    .task { await session.followServerInfo() }
  }

  /// What the bar and its card draw; nil with no weather to show.
  private var weatherContent: MapWeatherContent? {
    weather.current.flatMap { MapWeatherContent($0, units: session.units) }
  }

  /// The site the bar's weather is for: the one the finder picks, and none with no map.
  private var weatherShown: SiteFinderModel.WeatherSite? {
    map.hasMap ? model.weatherSite : nil
  }

  /// What a new look at the weather waits on: another site, or its pin moving to another cell. Not
  /// its title, which an opened site's read fills while its weather is still being asked for.
  private var weatherAsk: WeatherAsk? {
    weatherShown.map { WeatherAsk(site: $0.uuid, cell: MapWeatherModel.cell($0.pin)) }
  }

  /// The card's title: the shown answer's site, as the finder titles it now if it is still the one
  /// picked, which an opened site's read may since have named.
  private var weatherTitle: String? {
    guard let shown = weather.site else { return nil }
    guard let picked = model.weatherSite, picked.uuid == shown.uuid else { return shown.title }
    return picked.title ?? shown.title
  }

  /// Only where the instance takes proposals, whose routes answer nowhere else.
  private var proposalsButton: some View {
    NavigationLink {
      YourProposalsView()
    } label: {
      // The mark's bubbles cross as the spinner's do while the map's sites are looked up.
      CommonsLoadingMark(isLoading: model.isSearching)
    }
    .accessibilityLabel(YourProposalsView.title)
    .mapBarButton()
  }
}

private struct WeatherAsk: Hashable {
  let site: UUID
  let cell: MapWeatherModel.Cell
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

#Preview("Opened on a site") {
  NavigationStack {
    SiteMapView(siteUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
