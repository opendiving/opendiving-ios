import OpenDivingKit
import SwiftUI

/// The diver's own page, opened from the sites map by their picture: their name over the places
/// their trips went, with the logbook's figures, as the web's Home has it; the way back to the
/// map, the dive-computer button, the `+` that logs a dive, imports files or adds a trip or a
/// site, and the settings in the top bar; and under the head their dives, their trips, their
/// check-in sheet or, for now empty, *More*, one at a time.
struct ProfileView: View {
  let avatar: AvatarModel
  @Environment(Session.self) private var session

  var body: some View {
    ProfileContent(session: session, avatar: avatar)
  }
}

/// Where the top bar's buttons lead.
private enum ProfileRoute: Hashable {
  case logDive, importFiles, addTrip, addSite, diveComputer, settings
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
        // Three figures to a row on a phone's width, the six in two rows.
        HeroView(
          content: model.hero(today: .today()), detailsOnGlass: true, figureMinWidth: 100
        ) {
          UserAvatarView(initials: avatar.initials, picture: avatar.data, side: 52)
            .background(Color(.tertiarySystemFill), in: Circle())
            // In the name's colour, ringing the picture off the glass in either appearance.
            .overlay { Circle().strokeBorder(Color.primary, lineWidth: 1) }
        }
        ProfileSectionTabs(selection: $section)
        Group {
          switch section {
          case .dives: ProfileDives(list: dives, units: session.units)
          case .trips: ProfileTrips(list: trips, units: session.units)
          case .cards: CheckinSheetView(model: checkin, pictures: pictures)
          case .more: EmptyView()
          }
        }
        .padding(.horizontal)
      }
      .padding(.bottom)
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
        Menu("Add", systemImage: "plus") {
          Button {
            route = .logDive
          } label: {
            Label(menuItem: "Log a dive", icon: .dive)
          }
          Button {
            route = .importFiles
          } label: {
            Label(menuItem: "Import files", icon: .upload)
          }
          Button {
            route = .addTrip
          } label: {
            Label(menuItem: "Add trip", icon: .luggage)
          }
          Button {
            route = .addSite
          } label: {
            Label(menuItem: "Add dive site", icon: .diveSite)
          }
        }
        Button("Settings", systemImage: "gearshape") { route = .settings }
      }
    }
    .navigationDestination(item: $route) { route in
      switch route {
      case .logDive: DiveFormView(mode: .create)
      case .importFiles: ImportView()
      case .addTrip: TripFormView(mode: .create)
      case .addSite: DiveSiteFormView(mode: .create)
      case .diveComputer: DiveComputerView()
      case .settings: SettingsView()
      }
    }
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
    DiveComputerDownloads {
      DiveComputerModel(
        session: session, inbox: InboxModel(session: session),
        link: LibDCDiveComputerLink(manager: nil, defaults: .standard),
        generator: DiveComputerView.generator)
    })
}
