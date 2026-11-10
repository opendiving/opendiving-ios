import OpenDivingKit
import SwiftUI

/// Everything about one dive site, as the sites map's panel shows it under the site's name: its
/// chips, facts and figures with the ways to edit it and read its fields, what stands on it — a
/// proposal, a Commons match, an edit waiting to land — what it records about itself, its notes,
/// the species seen on its dives, and every dive there last.
struct SitePanelView: View {
  let siteUUID: UUID
  /// The site, each time it is read.
  let onRead: (DiveSiteRead) -> Void
  /// Another site for the panel: the Commons record this one matches, or the one it was replaced
  /// with.
  let onOpen: (UUID) -> Void
  let onDeleted: () -> Void
  @Environment(Session.self) private var session

  var body: some View {
    SitePanelContent(
      model: DiveSiteDetailModel(session: session, siteUUID: siteUUID), onRead: onRead,
      onOpen: onOpen, onDeleted: onDeleted
    )
    .id(siteUUID)
  }
}

private struct SitePanelContent: View {
  @Environment(Session.self) private var session
  @State private var model: DiveSiteDetailModel
  @State private var replacing: DiveSiteCommonsMatch?
  let onRead: (DiveSiteRead) -> Void
  let onOpen: (UUID) -> Void
  let onDeleted: () -> Void

  init(
    model: DiveSiteDetailModel, onRead: @escaping (DiveSiteRead) -> Void,
    onOpen: @escaping (UUID) -> Void, onDeleted: @escaping () -> Void
  ) {
    _model = State(initialValue: model)
    self.onRead = onRead
    self.onOpen = onOpen
    self.onDeleted = onDeleted
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
          SiteHead(site: site, units: session.units, onDeleted: onDeleted, onReplaced: onOpen)
          if let lastUpdated = model.lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          if let attribution = site.attribution {
            AttributionLine(credits: [attribution])
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          if model.hasPendingEdit {
            PendingEditLine()
          }
          if let notice = site.proposal.flatMap(DiveSiteProposalSummary.notice) {
            ProposalNotice(notice: notice, model: model)
          }
          if let match = site.commonsMatch {
            CommonsMatchNotice(
              match: match, replacement: model.replacement, open: { onOpen(match.uuid) }
            ) {
              replacing = match
            }
          }
          SiteInformationCard(info: DiveSiteSummary.info(site))
          if !site.notes.isEmpty {
            SectionCard(title: "Notes", icon: .fileText) {
              Text(site.notes)
                .foregroundStyle(.secondary)
            }
          }
          SiteSpecies(model: model)
          SiteDives(list: model.dives, units: session.units)
          PageEndTrigger(list: model.dives)
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

/// What the page's head said under the name, which the panel shows over it: the site's chips,
/// facts and figures, then the ways to edit it and to read its own fields.
private struct SiteHead: View {
  let site: DiveSiteRead
  let units: UnitSystem
  let onDeleted: () -> Void
  let onReplaced: (UUID) -> Void

  var body: some View {
    let content = DiveSiteSummary.hero(site, units: units)
    VStack(alignment: .leading, spacing: 12) {
      ChipsRow(chips: content.chips)
      FactsLine(facts: content.facts)
      FiguresRow(figures: content.figures)
      HStack(spacing: 8) {
        if !site.isUnsavedCommons {
          NavigationLink {
            DiveSiteFormView(mode: .edit(site), onDeleted: onDeleted, onReplaced: onReplaced)
          } label: {
            Label("Edit", systemImage: "pencil")
          }
          .buttonStyle(.bordered)
        }
        RecordInfoButton(
          title: "Dive Site Information",
          sections: DiveSiteSummary.recordInfo(site, units: units)
        )
        .buttonStyle(.bordered)
      }
      .tint(Color.brandTeal)
    }
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

  private static let title = "Dives at This Site"
  private static let icon = Icon.dive

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      SectionCard(title: Self.title, icon: Self.icon) {
        BubbleSpinner()
          .frame(maxWidth: .infinity)
      }
    case .failed(let error):
      SectionCard(title: Self.title, icon: Self.icon) {
        Text(
          error.isUnreachable
            ? OfflineText.divesNotShown : "This site's dives could not be loaded."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.bordered)
      }
    case .loaded where list.items.isEmpty:
      EmptyOrErrorView(
        status: .empty(
          icon: Self.icon, title: "No dives logged at this site yet", message: nil))
    case .loaded:
      SectionCard(title: Self.title, icon: Self.icon) {
        Text("All dives logged at this dive site")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        DiveCardLinks(items: list.items, units: units)
        LoadMoreFooter(list: list)
      }
    }
  }
}

/// What else the site is called, where exactly it is, the diver's tags and its entries in
/// other registries; no card for a site recording none of them.
private struct SiteInformationCard: View {
  let info: DiveSiteSummary.Info

  var body: some View {
    if !info.isEmpty {
      SectionCard(title: "Dive Site Information", icon: .diveSite) {
        VStack(alignment: .leading, spacing: 16) {
          if let alsoKnownAs = info.alsoKnownAs {
            InfoRow(label: "Also known as") {
              Text(alsoKnownAs)
            }
          }
          if let coordinates = info.coordinates {
            InfoRow(label: "Coordinates") {
              Text(coordinates)
                .monospacedDigit()
                .textSelection(.enabled)
            }
          }
          if !info.tags.isEmpty {
            InfoRow(label: "Tags") {
              FlowLayout(spacing: 6) {
                ForEach(Array(info.tags.enumerated()), id: \.offset) { _, tag in
                  BadgeView(tag, style: .outline)
                }
              }
            }
          }
          if !info.registries.isEmpty {
            InfoRow(label: "In other registries") {
              VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(info.registries.enumerated()), id: \.offset) { _, registry in
                  RegistryLine(registry: registry)
                }
              }
            }
          }
        }
      }
    }
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

/// The species seen on the site's dives, read whole; nothing while the site counts none.
private struct SiteSpecies: View {
  let model: DiveSiteDetailModel

  var body: some View {
    switch model.species {
    case .none:
      EmptyView()
    case .loading:
      card { message("Loading species...") }
    case .failed:
      card { message("The species could not be loaded.") }
    case .loaded(let entries):
      card {
        // Lazy, so each card asks for its photo as it scrolls into reach rather than every
        // one of the site's species at once.
        LazyVStack(spacing: 12) {
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
  }

  private func card(@ViewBuilder _ content: () -> some View) -> some View {
    SectionCard(title: "Species Seen Here", icon: .fish, content: content)
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      SitePanelView(siteUUID: UUID(), onRead: { _ in }, onOpen: { _ in }, onDeleted: {})
        .padding()
    }
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
