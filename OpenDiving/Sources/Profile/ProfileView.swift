import OpenDivingKit
import SwiftUI

/// The diver's own page, opened from the sites map by their picture: their name over the places
/// their trips went, with the logbook's figures, as the web's Home has it; the way back to the
/// map, the dive-computer button, the QR code that opens the diver's connect link, and the
/// settings in the top bar; their picture, which opens *Account*; under the head their dives,
/// their trips, their check-in sheet or *More*, the menu of the rest, one at a time; and over
/// the dives and the trips, the button that adds one.
struct ProfileView: View {
  let avatar: AvatarModel
  @Environment(Session.self) private var session

  var body: some View {
    ProfileContent(session: session, avatar: avatar)
  }
}

/// Where the top bar's buttons and the add button lead.
private enum ProfileRoute: Hashable {
  case diveComputer, settings, account, logDive, addTrip
}

private struct ProfileContent: View {
  let avatar: AvatarModel
  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var model: ProfileModel
  @State private var dives: PagedList<DiveListItem>
  @State private var trips: PagedList<TripRead>
  @State private var checkin: CheckinSheetModel
  @State private var pictures = PictureCache()
  @State private var section = ProfileSection.dives
  @State private var route: ProfileRoute?
  @State private var isShowingConnectLink = false
  @State private var tabsStuck = false
  @State private var scroll = ScrollPosition(edge: .top)
  @State private var tabsTop: CGFloat = 0
  @State private var reselect = TabsReselect.head

  init(session: Session, avatar: AvatarModel) {
    self.avatar = avatar
    _model = State(initialValue: ProfileModel(session: session))
    _dives = State(initialValue: ProfileDives.list(session))
    _trips = State(initialValue: ProfileTrips.list(session))
    _checkin = State(initialValue: CheckinSheetModel(session: session))
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Closer than the sections below: the head's own padding already parts them.
        VStack(spacing: 8) {
          // Three figures to a row on a phone's width, the six in two rows.
          HeroView(
            content: model.hero(today: .today()), detailsOnGlass: true, figureMinWidth: 100
          ) {
            Button {
              route = .account
            } label: {
              UserAvatarView(initials: avatar.initials, picture: avatar.data, side: 52)
                .background(Color(.tertiarySystemFill), in: Circle())
                // In the name's colour, ringing the picture off the glass in either appearance.
                .overlay { Circle().strokeBorder(Color.primary, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
          }
          ScrollingSectionTabs(
            selection: $section, isStuck: $tabsStuck, top: $tabsTop, onReselect: scrollOnReselect)
        }
        Group {
          switch section {
          case .dives: ProfileDives(list: dives, units: session.units)
          case .trips: ProfileTrips(list: trips, units: session.units)
          case .cards: CheckinSheetView(model: checkin, pictures: pictures)
          case .more: MoreMenu()
          }
        }
        .padding(.horizontal)
        // Room for the add button, so the last card scrolls clear of it.
        .padding(
          .bottom,
          adding == nil ? 0 : FloatingAddButton.side + FloatingAddButton.bottomInset
        )
        .hiddenUnderTopBar()
      }
      .coordinateSpace(.pageContent)
      .padding(.bottom)
    }
    .scrollPosition($scroll)
    .tabsReselect($reselect, tabsTop: tabsTop)
    .overlay(alignment: .top) {
      StuckSectionTabs(selection: $section, isStuck: tabsStuck, onReselect: scrollOnReselect)
    }
    .floatingAddButton(
      adding?.title ?? "", icon: adding?.icon ?? .plus, fill: adding?.fill ?? .clear,
      isShown: adding != nil
    ) {
      route = adding?.route
    }
    .background(Color.pageBackground)
    .heroUnderTopBar { [model, dives, trips, checkin, section] in
      async let head: Void = model.refresh()
      switch section {
      case .dives: await dives.refresh()
      case .trips: await trips.refresh()
      case .cards: await checkin.refresh()
      case .more: break
      }
      await head
    }
    .navigationTitle(session.user?.name ?? "Profile")
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    // The way back is to the map, which a map says better than a chevron.
    .navigationBarBackButtonHidden()
    .swipesBackWithoutBackButton()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Map", systemImage: "map") { dismiss() }
      }
      ToolbarIslandGap(placement: .topBarLeading)
      DiveComputerToolbarItem { route = .diveComputer }
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button(ConnectLinkModel.showButton, systemImage: "qrcode") { isShowingConnectLink = true }
        Button("Settings", systemImage: "gearshape") { route = .settings }
      }
    }
    .navigationDestination(item: $route) { route in
      switch route {
      case .diveComputer: DiveComputerView()
      case .settings: SettingsView()
      case .account: AccountScreen()
      case .logDive: DiveFormView(mode: .create)
      case .addTrip: TripFormView(mode: .create)
      }
    }
    .sheet(isPresented: $isShowingConnectLink) { ConnectLinkSheet() }
    .task {
      await model.refresh()
      await model.followRoute()
    }
    .task(id: session.user?.avatarSha256) { await avatar.load() }
    // Each section reads when it is shown, and again on return while it shows only the phone's
    // copy: a switch or a push cancels the read. The check-in sheet refreshes on every visit.
    .task(id: section) {
      switch section {
      case .dives: await dives.rereadIfStale()
      case .trips: await trips.rereadIfStale()
      case .cards:
        checkin.load()
        await checkin.refresh()
        await checkin.followRoute()
      case .more: break
      }
    }
  }

  /// The add button the section shows: coral for a dive, teal for a trip.
  private var adding: (title: String, icon: Icon, fill: Color, route: ProfileRoute)? {
    switch section {
    case .dives: ("Log a dive", .divePlus, .brandCoral, .logDive)
    case .trips: ("Add trip", .luggagePlus, .brandTeal, .addTrip)
    case .cards, .more: nil
    }
  }

  private func scrollOnReselect() {
    withAnimation { scroll.scroll(to: reselect) }
  }
}

#Preview {
  let session = DivePreviewData.session
  NavigationStack {
    ProfileView(avatar: AvatarModel(session: session))
  }
  .environment(session)
  .environment(SignInFlow(session: session))
  .environment(InboxModel(session: session))
  .environment(OutboxModel(session: session))
  .environment(
    DiveComputerDownloads(
      engine: DiveComputerEngine(
        session: session,
        makeLink: { LibDCDiveComputerLink(manager: nil, defaults: .standard) },
        generator: DiveComputerView.generator)))
}
