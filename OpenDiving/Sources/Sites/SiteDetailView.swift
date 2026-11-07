import OpenDivingKit
import SwiftUI

/// One dive site's page, pushed from the dive page and the sites list: its hero, every dive
/// there, what it records about itself, its notes and the species seen on its dives.
struct SiteDetailView: View {
  let siteUUID: UUID
  @Environment(Session.self) private var session
  /// The Commons record that replaced the site while its page was open.
  @State private var record: UUID?

  var body: some View {
    let shown = record ?? siteUUID
    SiteDetailContent(model: DiveSiteDetailModel(session: session, siteUUID: shown)) {
      record = $0
    }
    .id(shown)
  }
}

private struct SiteDetailContent: View {
  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var model: DiveSiteDetailModel
  @State private var replacing: DiveSiteCommonsMatch?
  let onReplaced: (UUID) -> Void

  init(model: DiveSiteDetailModel, onReplaced: @escaping (UUID) -> Void) {
    _model = State(initialValue: model)
    self.onReplaced = onReplaced
  }

  var body: some View {
    Group {
      switch model.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: "Dive site not found."))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: error.message)) {
          Task { await model.load() }
        }
      case .loaded(let site):
        ScrollView {
          LazyVStack(spacing: 16) {
            HeroView(content: DiveSiteSummary.hero(site, units: session.units))
            Group {
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
                CommonsMatchNotice(match: match, replacement: model.replacement) {
                  replacing = match
                }
              }
              SiteDives(list: model.dives, units: session.units)
              PageEndTrigger(list: model.dives)
              SiteInformationCard(info: DiveSiteSummary.info(site))
              if !site.notes.isEmpty {
                SectionCard(title: "Notes", icon: .fileText) {
                  Text(site.notes)
                    .foregroundStyle(.secondary)
                }
              }
              SiteSpecies(model: model)
            }
            .padding(.horizontal)
          }
          .padding(.bottom)
        }
        .heroUnderTopBar { await model.refresh() }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    .toolbar {
      if case .loaded(let site) = model.phase {
        ToolbarItemGroup(placement: .topBarTrailing) {
          RecordInfoButton(
            title: "Dive Site Information",
            sections: DiveSiteSummary.recordInfo(site, units: session.units))
          if !site.isUnsavedCommons {
            NavigationLink {
              DiveSiteFormView(
                mode: .edit(site), onDeleted: { dismiss() }, onReplaced: onReplaced)
            } label: {
              Label("Edit dive site", systemImage: "pencil")
            }
          }
        }
      }
    }
    .task { await model.load() }
    .proposalWithdrawalAlert(model.withdrawal)
    .replaceWithCommonsConfirmation(siteName: title, target: $replacing) { match in
      Task {
        if let record = await model.replace(with: match.uuid) { onReplaced(record.uuid) }
      }
    }
    .replaceWithCommonsAlert(model.replacement)
  }

  private var title: String {
    if case .loaded(let site) = model.phase { site.name } else { "Dive site" }
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
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }
}

/// The diver's own site shares a registry entry with a Commons record: which one, opening its
/// page, and the way to take it instead. On every instance, as the route is.
private struct CommonsMatchNotice: View {
  let match: DiveSiteCommonsMatch
  let replacement: CommonsSiteReplacement
  let replace: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NavigationLink {
        SiteDetailView(siteUUID: match.uuid)
      } label: {
        Text(DiveSiteProposalSummary.commonsMatch(match))
          .font(.subheadline)
          .multilineTextAlignment(.leading)
      }
      .accentRow()
      ReplaceWithCommonsButton(record: match.uuid, replacement: replacement, replace: replace)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        ProgressView()
          .frame(maxWidth: .infinity)
      }
    case .failed:
      SectionCard(title: Self.title, icon: Self.icon) {
        Text("This site's dives could not be loaded.")
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
    SiteDetailView(siteUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
