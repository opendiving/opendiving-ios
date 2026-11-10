import OpenDivingKit
import SwiftUI

/// Everything about one dive site, as the sites map's panel shows it under the site's mark, name
/// and location, in three tabs — *Info*, with what stands on it (a proposal, a Commons match, an edit waiting to land), every field it records and its
/// notes; *Marine life*, the species seen on its dives; and *My dives*, every dive there.
struct SitePanelView: View {
  let siteUUID: UUID
  /// The site, each time it is read.
  let onRead: (DiveSiteRead) -> Void
  /// Another site for the panel: the Commons record this one matches, or the one it was replaced
  /// with.
  let onOpen: (UUID) -> Void
  @Environment(Session.self) private var session

  var body: some View {
    SitePanelContent(
      model: DiveSiteDetailModel(session: session, siteUUID: siteUUID), onRead: onRead,
      onOpen: onOpen
    )
    .id(siteUUID)
  }
}

private struct SitePanelContent: View {
  @Environment(Session.self) private var session
  @State private var model: DiveSiteDetailModel
  @State private var replacing: DiveSiteCommonsMatch?
  @State private var section = SiteSection.info
  let onRead: (DiveSiteRead) -> Void
  let onOpen: (UUID) -> Void

  init(
    model: DiveSiteDetailModel, onRead: @escaping (DiveSiteRead) -> Void,
    onOpen: @escaping (UUID) -> Void
  ) {
    _model = State(initialValue: model)
    self.onRead = onRead
    self.onOpen = onOpen
  }

  var body: some View {
    Group {
      switch model.phase {
      case .loading:
        BubbleSpinner()
          .frame(maxWidth: .infinity)
          .padding(.top, 24)
      case .notFound:
        message("Dive site not found.")
      case .failed(let error):
        VStack(alignment: .leading, spacing: 8) {
          message(error.isUnreachable ? OfflineText.siteNotShown : error.message)
          Button("Try again") { Task { await model.load() } }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      case .loaded(let site):
        LazyVStack(spacing: 16) {
          SectionTabs(selection: $section) { section in
            switch section {
            case .info: section.title
            case .marineLife: DiveSiteSummary.counted(section.title, site.speciesCount)
            case .myDives: DiveSiteSummary.counted(section.title, site.diveCount)
            }
          }
          // Across the panel's width, as across the profile's page.
          .padding(.horizontal, -16)
          switch section {
          case .info: info(site)
          case .marineLife: SiteSpecies(model: model)
          case .myDives:
            SiteDives(list: model.dives, units: session.units)
            PageEndTrigger(list: model.dives)
          }
        }
      }
    }
    .onChange(of: loaded, initial: true) { _, site in
      if let site { onRead(site) }
    }
    .task {
      await model.load()
      await model.followRoute()
    }
    .proposalWithdrawalAlert(model.withdrawal)
    .replaceWithCommonsConfirmation(siteName: loaded?.name ?? "Dive site", target: $replacing) {
      match in
      Task {
        if let record = await model.replace(with: match.uuid) { onOpen(record.uuid) }
      }
    }
    .replaceWithCommonsAlert(model.replacement)
  }

  /// What stands on the site, every field it records with its credit under them, and its notes.
  @ViewBuilder private func info(_ site: DiveSiteRead) -> some View {
    if let lastUpdated = model.lastUpdated {
      LastUpdatedLine(date: lastUpdated)
    }
    if model.hasPendingEdit {
      PendingEditLine()
    }
    if let notice = site.proposal.flatMap(DiveSiteProposalSummary.notice) {
      ProposalNotice(notice: notice, model: model)
    }
    if let match = site.commonsMatch {
      CommonsMatchNotice(
        match: match, replacement: model.replacement, open: { onOpen(match.uuid) },
        replace: { replacing = match })
    }
    VStack(alignment: .leading, spacing: 6) {
      SiteInformationCard(info: DiveSiteSummary.info(site, units: session.units))
      if let attribution = site.attribution {
        AttributionLine(credits: [attribution])
          .padding(.horizontal, 16)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    if !site.notes.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        // Over the card, as a form's section header stands over its rows.
        FormSectionHeader(title: "Notes", icon: .fileText)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
          .accessibilityAddTraits(.isHeader)
        Text(site.notes)
          .padding(.horizontal, 16)
          .padding(.vertical, 11)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.cardFill, in: .formSection)
      }
    }
  }

  private var loaded: DiveSiteRead? {
    if case .loaded(let site) = model.phase { site } else { nil }
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Where the diver's proposal on the site stands: waiting, with the way to take it back, or
/// declined, with the reason until they propose again.
private struct ProposalNotice: View {
  let notice: DiveSiteProposalSummary.Notice
  let model: DiveSiteDetailModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text(notice.title)
          .fontWeight(.medium)
        if let message = notice.message {
          Text(message)
            .foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
      if let proposal = notice.withdrawable {
        ProposalWithdrawButton(
          proposal: proposal, withdrawal: model.withdrawal, withdraw: model.withdraw)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.cardFill, in: .formSection)
  }
}

/// The diver's own site shares a registry entry with a Commons record: which one, opening it in
/// the panel, and the way to take it instead. On every instance, as the route is.
private struct CommonsMatchNotice: View {
  let match: DiveSiteCommonsMatch
  let replacement: CommonsSiteReplacement
  let open: () -> Void
  let replace: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: open) {
        Text(DiveSiteProposalSummary.commonsMatch(match))
          .font(.subheadline)
          .multilineTextAlignment(.leading)
      }
      .accentRow()
      ReplaceWithCommonsButton(record: match.uuid, replacement: replacement, replace: replace)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.cardFill, in: .formSection)
  }
}

/// Every dive at the site, newest first, a page at a time.
private struct SiteDives: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    case .failed(let error):
      VStack(alignment: .leading, spacing: 8) {
        Text(
          error.isUnreachable
            ? OfflineText.divesNotShown : "This site's dives could not be loaded."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    case .loaded where list.items.isEmpty:
      EmptyOrErrorView(
        status: .empty(icon: .dive, title: "No dives logged at this site yet", message: nil))
    case .loaded:
      DiveCardLinks(items: list.items, units: units)
      LoadMoreFooter(list: list)
    }
  }
}

/// Every field the site records but its name, location, tags and notes, a row each as the
/// record's info sheet listed them: the label, and its value across from it, or under it where
/// it is a list. No card for a site recording none.
private struct SiteInformationCard: View {
  let info: DiveSiteSummary.Info

  var body: some View {
    if !info.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        Group(subviews: rows) { rows in
          ForEach(rows.indices, id: \.self) { index in
            if index > 0 {
              Divider().padding(.leading, 16)
            }
            rows[index]
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.cardFill, in: .formSection)
    }
  }

  @ViewBuilder private var rows: some View {
    if let alsoKnownAs = info.alsoKnownAs {
      InfoLine(label: "Also known as") { Text(alsoKnownAs) }
    }
    if let coordinates = info.coordinates {
      CoordinatesLine(coordinates: coordinates)
    }
    if let depth = info.depth {
      InfoLine(label: "Depth") { Text(depth) }
    }
    if let waterType = info.waterType {
      InfoLine(label: "Water type") { Text(waterType) }
    }
    if let altitude = info.altitude {
      InfoLine(label: "Altitude") { Text(altitude) }
    }
    if let entryTypes = info.entryTypes {
      InfoLine(label: "Entry types") { Text(entryTypes) }
    }
    if !info.registries.isEmpty {
      InfoLine(label: "In other registries", isWide: true) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(info.registries.enumerated()), id: \.offset) { _, registry in
            RegistryLine(registry: registry)
          }
        }
      }
    }
  }
}

/// The coordinates' row, which copies them on a tap and says so for a moment in their place.
private struct CoordinatesLine: View {
  let coordinates: String
  @State private var copied = false
  /// Counts taps, so a second one keeps *Copied* up for its own while.
  @State private var copies = 0

  var body: some View {
    Button {
      UIPasteboard.general.string = coordinates
      withAnimation(.easeOut(duration: 0.15)) { copied = true }
      copies += 1
    } label: {
      InfoLine(label: "Coordinates") {
        Text(copied ? "Copied" : coordinates)
          .monospacedDigit()
          .contentTransition(.opacity)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityHint("Copies the coordinates")
    .sensoryFeedback(.success, trigger: copies)
    .task(id: copies) {
      guard copies > 0 else { return }
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.15)) { copied = false }
    }
  }
}

/// One row of the information card: its label, and the value across from it in the secondary
/// colour, or under it where `isWide`.
private struct InfoLine<Value: View>: View {
  let label: String
  var isWide = false
  @ViewBuilder let value: () -> Value

  var body: some View {
    Group {
      if isWide {
        VStack(alignment: .leading, spacing: 4) {
          Text(label)
          value().foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(label)
          Spacer(minLength: 0)
          value()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .accessibilityElement(children: .combine)
  }
}

/// A registry's name and the identifier, opening the registry's page where the format
/// names the registry.
private struct RegistryLine: View {
  let registry: DiveSiteSummary.Registry

  var body: some View {
    let text = registry.label + " " + registry.identifier
    if let link = registry.link, let url = URL(string: link) {
      Link(destination: url) {
        Label(text, systemImage: "arrow.up.right.square")
          .labelStyle(TrailingIconLabelStyle())
      }
      .accentRow()
    } else {
      Text(text)
    }
  }
}

private struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 4) {
      configuration.title
      configuration.icon
        .font(.caption)
        .accessibilityHidden(true)
    }
  }
}

/// The species seen on the site's dives, read whole.
private struct SiteSpecies: View {
  let model: DiveSiteDetailModel

  var body: some View {
    switch model.species {
    case .none:
      EmptyOrErrorView(
        status: .empty(
          icon: .fish, title: "No marine life recorded on your dives here yet", message: nil))
    case .loading:
      BubbleSpinner()
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    case .failed:
      Text("The species could not be loaded.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    case .loaded(let entries):
      // In the panel's lazy stack, so each card asks for its photo as it scrolls into reach
      // rather than every one of the site's species at once.
      ForEach(entries) { entry in
        CreditedSpeciesCard(
          speciesUUID: entry.uuid, photoVersion: entry.photoSha256,
          content: SpeciesCardContent.lifeList(entry, photo: model.photos[entry.uuid])
        )
        .onAppear { Task { await model.loadPhoto(entry) } }
      }
    }
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      SitePanelView(siteUUID: UUID(), onRead: { _ in }, onOpen: { _ in })
        .padding()
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
