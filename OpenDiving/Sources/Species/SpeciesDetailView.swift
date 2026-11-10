import OpenDivingKit
import SwiftUI

/// A species' page, by its uuid: its photo across the hero and the photo's credit under it, the
/// dives with it and its taxonomy. Every species card opens it, which is what credits their
/// photos.
struct SpeciesDetailView: View {
  let speciesUUID: UUID
  @Environment(Session.self) private var session

  var body: some View {
    SpeciesDetailContent(model: SpeciesDetailModel(session: session, speciesUUID: speciesUUID))
  }
}

extension SpeciesDetailView {
  static let notFound = "Species not found."

  /// What a page that could not be read says: offline, that it shows once it can be.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.speciesNotShown : error.message
  }
}

private struct SpeciesDetailContent: View {
  @Environment(Session.self) private var session
  @State private var model: SpeciesDetailModel

  init(model: SpeciesDetailModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    Group {
      switch model.page.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: SpeciesDetailView.notFound))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: SpeciesDetailView.failure(error))) {
          Task { await model.load() }
        }
      case .loaded(let page):
        let content = SpeciesPageContent(page)
        ScrollView {
          LazyVStack(spacing: 16) {
            HeroView(
              content: content.hero, backdrop: .photo(model.photo, placeholder: .fish))
            Group {
              if let lastUpdated = model.page.lastUpdated {
                LastUpdatedLine(date: lastUpdated)
              }
              // The credit first, under the photo it belongs to, and visible without a tap.
              if let credit = content.photoCredit {
                CreditText(credit: credit)
                  .padding(12)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.cardFill, in: .formSection)
              }
              RecordDivesSection(
                list: model.dives, content: content.dives, units: session.units,
                logDive: .create)
              TaxonomyCard(content: content)
            }
            .padding(.horizontal)
          }
          .padding(.bottom)
        }
        .heroUnderTopBar { await model.refresh() }
        .task(id: page.species.photoSha256) { await model.loadPhoto() }
      }
    }
    .background(Color.pageBackground)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    // The title names the page in the back button's history; the head says it on screen.
    .toolbar(removing: .title)
    .task {
      await model.load()
      await model.followRoute()
    }
  }

  private var title: String {
    if case .loaded(let page) = model.page.phase {
      SpeciesNames.displayName(
        scientificName: page.species.scientificName, commonName: page.species.commonName)
    } else {
      "Species"
    }
  }
}

/// The catalog's ranks and authority, the species' AphiaID opening WoRMS' page, and the credit
/// WoRMS' licence asks for where its classification is shown.
private struct TaxonomyCard: View {
  let content: SpeciesPageContent

  var body: some View {
    SectionCard(title: "Taxonomy", icon: .listTree) {
      VStack(alignment: .leading, spacing: 16) {
        ForEach(content.taxonomy, id: \.self) { row in
          InfoRow(label: row.label) { Text(row.value) }
        }
        InfoRow(label: "WoRMS AphiaID") {
          if let url = content.aphiaURL {
            Link(destination: url) {
              Text(content.aphiaID).underline()
            }
            .tint(Color.primary)
          } else {
            Text(content.aphiaID)
          }
        }
        CreditText(credit: SpeciesPageContent.taxonomyCredit)
      }
    }
  }
}

#Preview {
  NavigationStack {
    SpeciesDetailView(speciesUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
