import OpenDivingKit
import SwiftUI

/// One dive site's page, pushed from the dive page and the sites list: its hero, every dive
/// there, what it records about itself, its notes and the species seen on its dives.
struct SiteDetailView: View {
  let siteUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    SiteDetailContent(model: DiveSiteDetailModel(session: session, siteUUID: siteUUID))
  }
}

private struct SiteDetailContent: View {
  @Environment(Session.self) private var session
  @State private var model: DiveSiteDetailModel

  init(model: DiveSiteDetailModel) {
    _model = State(initialValue: model)
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
          VStack(spacing: 16) {
            HeroView(content: DiveSiteSummary.hero(site, units: session.units))
            VStack(spacing: 16) {
              SiteDives(list: model.dives, units: session.units)
              SiteInformationCard(info: DiveSiteSummary.info(site))
              if !site.notes.isEmpty {
                SectionCard(title: "Notes", systemImage: "doc.text") {
                  Text(site.notes)
                    .foregroundStyle(.secondary)
                }
              }
              SiteSpecies(model: model)
            }
            .padding([.horizontal, .bottom])
          }
        }
        .refreshable { await model.refresh() }
      }
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
  }

  private var title: String {
    if case .loaded(let site) = model.phase { site.name } else { "Dive site" }
  }
}

/// Every dive at the site, newest first, a page at a time.
private struct SiteDives: View {
  let list: PagedList<DiveListItem>
  let units: UnitSystem

  private static let title = "Dives at This Site"
  private static let symbol = "water.waves"

  var body: some View {
    switch list.phase {
    case .idle, .loading:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        ProgressView()
          .frame(maxWidth: .infinity)
      }
    case .failed:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        Text("This site's dives could not be loaded.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await list.load() } }
          .buttonStyle(.bordered)
      }
    case .loaded where list.items.isEmpty:
      EmptyOrErrorView(
        status: .empty(
          systemImage: Self.symbol, title: "No dives logged at this site yet", message: nil))
    case .loaded:
      SectionCard(title: Self.title, systemImage: Self.symbol) {
        Text("All dives logged at this dive site")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        DiveCardLinks(items: list.items, list: list, units: units)
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
      SectionCard(title: "Dive Site Information", systemImage: "mappin.and.ellipse") {
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
        ForEach(entries) { entry in
          SpeciesCardView(
            content: SpeciesCardContent.lifeList(entry, photo: model.photos[entry.uuid])
          )
          .onAppear { Task { await model.loadPhoto(entry) } }
        }
      }
    }
  }

  private func card(@ViewBuilder _ content: () -> some View) -> some View {
    SectionCard(title: "Species Seen Here", systemImage: "fish", content: content)
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
