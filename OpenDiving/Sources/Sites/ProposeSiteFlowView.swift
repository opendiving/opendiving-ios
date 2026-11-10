import OpenDivingKit
import SwiftUI

/// The diver's own site on its way to the Commons, as a sheet with its own stack: first whether it
/// is there already, then exactly what would be published, then the attestation. The site is sent
/// as it stands, and *Edit* goes through its form and starts again from the matches.
struct ProposeSiteFlowView: View {
  /// What the host owes the flow once it has gone; nil for a send or a cancel, which leave the
  /// host only to close.
  enum Ending: Hashable {
    /// The site is now this record.
    case replaced(retired: UUID, record: DiveSiteRead)
    /// *Edit*'s save did not land, and the site goes by this ref.
    case kept(RecordRef)
  }

  static let title = "Propose for OpenDiving Commons"

  @State var model: DiveSiteProposalFlow
  @Binding var ending: Ending?

  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var editing = false
  @State private var replacing: DiveSiteCommonsMatch?

  var body: some View {
    NavigationStack {
      Group {
        switch model.step {
        case .loading:
          EmptyOrErrorView(status: .loading)
        case .matches:
          MatchesStep(
            model: model, units: session.units, replace: { replacing = $0 },
            onEdit: { editing = true })
        case .review:
          ReviewStep(
            model: model, map: MapStyleModel(session: session), units: session.units,
            onEdit: { editing = true }, onSent: { dismiss() })
        }
      }
      .navigationTitle(Self.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if model.step == .review, model.canGoBack {
            Button("Back") { model.back() }
          } else {
            Button("Cancel") { dismiss() }
          }
        }
      }
      .navigationDestination(isPresented: $editing) {
        DiveSiteFormView(mode: .edit(model.site), onLanded: landed)
      }
    }
    .disabled(isBusy)
    .interactiveDismissDisabled(isBusy)
    .task { await model.load() }
    .replaceWithCommonsConfirmation(siteName: model.site.name, target: $replacing, replace: replace)
    .replaceWithCommonsAlert(model.replacement)
  }

  private var isBusy: Bool { model.isSending || model.replacement.replacing != nil }

  private func replace(_ match: DiveSiteCommonsMatch) {
    Task {
      guard let record = await model.replace(with: match.uuid) else { return }
      ending = .replaced(retired: model.site.uuid, record: record)
      dismiss()
    }
  }

  private func landed(_ landing: DiveSiteLanding) {
    switch landing {
    case .landed(let site) where site.isCommons || site.isWaitingForReview:
      dismiss()
    case .landed(let site):
      editing = false
      Task { await model.restart(with: site) }
    case .kept(let ref):
      ending = .kept(ref)
      dismiss()
    }
  }
}

/// Is it already in the Commons? Each record it may be, and what can be done about it.
private struct MatchesStep: View {
  let model: DiveSiteProposalFlow
  let units: UnitSystem
  let replace: (DiveSiteCommonsMatch) -> Void
  let onEdit: () -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        Text("Is it already in the Commons?")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        if let error = model.loadError {
          FieldMessage(error)
          Button("Try again") { Task { await model.load() } }
            .buttonStyle(.bordered)
        } else if model.matches.isEmpty {
          Text(DiveSiteCommonsMatchSummary.none)
            .font(.subheadline)
        }
        ForEach(model.matches) { match in
          MatchCard(
            row: DiveSiteCommonsMatchSummary.row(match, units: units),
            replacement: model.replacement, replace: replace)
        }
        if model.needsPin {
          Text(DiveSiteCommonsMatchSummary.needsPin)
            .font(.subheadline)
          Button("Edit", action: onEdit)
            .buttonStyle(.bordered)
        }
        if model.hasIdentityMatch {
          Text(DiveSiteCommonsMatchSummary.isACopy)
            .font(.subheadline)
        }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .pinnedToBottom {
      if model.canContinue {
        FormSaveBar(label: "Continue as a new site", error: nil) { model.continueAsNewSite() }
      }
    }
  }
}

/// A record the site may be, opening it on the map, with why and its credit.
private struct MatchCard: View {
  let row: DiveSiteCommonsMatchSummary.Row
  let replacement: CommonsSiteReplacement
  let replace: (DiveSiteCommonsMatch) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      NavigationLink {
        SiteMapView(siteUUID: row.target.uuid)
      } label: {
        Text(row.target.name)
          .font(.headline)
          .multilineTextAlignment(.leading)
      }
      .accentRow()
      Group {
        if let locality = row.locality { Text(locality) }
        Text(row.reason)
        if let siblings = row.siblings { Text(siblings) }
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
      if let credit = row.credit {
        AttributionLine(credits: [credit])
      }
      ReplaceWithCommonsButton(record: row.target.uuid, replacement: replacement) {
        replace(row.target)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
  }
}

/// What would be published, with the pin on a map that places nothing; what would not; and the
/// word and the tick. With no style the pin's figures are the row that says where it is.
private struct ReviewStep: View {
  @Bindable var model: DiveSiteProposalFlow
  @State var map: MapStyleModel
  let units: UnitSystem
  let onEdit: () -> Void
  let onSent: () -> Void

  var body: some View {
    let review = DiveSiteProposalReview(model.site, units: units)
    Form {
      Section {
        Text("Check what you are offering to everyone.")
          .foregroundStyle(.secondary)
      }
      if let pin = review.pin, let style = map.shown {
        Section {
          ZoomablePinMap(style: style, pin: pin, label: "Map of the dive site")
            .frame(height: 220)
            .listRowInsets(EdgeInsets())
        }
      }
      Section {
        VStack(alignment: .leading, spacing: 4) {
          LabeledContent("Identifier", value: review.identifier)
          Text(DiveSiteProposalReview.identifierHint)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        ForEach(review.rows, id: \.label) { row in
          LabeledContent(row.label, value: row.value ?? DiveSiteProposalReview.notRecorded)
        }
        LabeledContent("Licence", value: DiveSiteProposalReview.licence)
        Button("Edit", action: onEdit)
          .accentRow()
      } header: {
        Text("What Would Be Published")
      }
      Section {
        ForEach(DiveSiteProposalReview.notPublished, id: \.self) { Text($0) }
      } header: {
        Text("What Would Not")
      }
      CommonsAttestationSection(
        attestation: CommonsAttestations.newSite, ticked: $model.ticked, message: $model.message)
    }
    .background(TapEndsTyping())
    .pinnedToBottom {
      FormSaveBar(
        label: model.isSending ? "Sending..." : "Send proposal", error: model.sendError
      ) {
        Task {
          if await model.send() { onSent() }
        }
      }
      .disabled(!model.ticked || model.isSending)
    }
    .showsMapStyle(map)
  }
}

#Preview {
  @Previewable @State var ending: ProposeSiteFlowView.Ending?
  let json = """
    {"uuid":"01a0a521-28c5-7e34-a572-4d7324f5033b","name":"Tiger Reef","notes":"",
     "latitude":28.5722,"longitude":34.5372,"other_names":[],"external_ids":[],"entry_types":[],
     "tags":[],"dive_count":0,"species_count":0,"owner":"account","saved":true,
     "created_at":"2026-09-15T12:53:28.901059Z"}
    """
  let site = try! APICoding.decoder().decode(DiveSiteRead.self, from: Data(json.utf8))
  let session = Session.stub(transport: StubTransport(routes: [:]))
  ProposeSiteFlowView(model: DiveSiteProposalFlow(session: session, site: site), ending: $ending)
    .environment(session)
}
