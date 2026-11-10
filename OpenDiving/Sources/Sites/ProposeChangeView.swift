import OpenDivingKit
import SwiftUI

/// A change to a Commons record, pushed from its edit form: its shared members for correcting,
/// then the word and the tick. The place is plain text as the body spells it, a registry entry can
/// only be taken off, and the pin is typed: no map here, so this is no new place the phone draws
/// one.
struct ProposeChangeView: View {
  static let title = "Propose a Change"

  @State var model: DiveSiteChangeModel

  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var invalid: Set<String> = []

  var body: some View {
    ChangeFields(
      model: model, units: RecordEntryUnits(session: session), invalid: $invalid
    )
    .pinnedToBottom {
      FormSaveBar(
        label: model.isSending ? "Sending..." : "Send proposal", error: model.sendError
      ) {
        guard invalid.isEmpty else { return }
        Task {
          if await model.send() { dismiss() }
        }
      }
      .disabled(!model.ticked || model.isSending)
    }
    .navigationTitle(Self.title)
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(model.isSending)
  }
}

private struct ChangeFields: View {
  @Bindable var model: DiveSiteChangeModel
  @State var units: RecordEntryUnits
  @Binding var invalid: Set<String>

  var body: some View {
    Form {
      Section {
        Text(DiveSiteProposalSummary.changeExplained)
          .foregroundStyle(.secondary)
      }
      Section {
        TextBox(label: "Name *", text: $model.values.name, message: model.message("name"))
      }
      OtherNamesField(names: $model.values.otherNames)
      Section {
        TextBox(
          label: "Location", text: $model.locationName, message: model.message("location"))
        CoordinateFields(
          latitude: $model.values.latitude, longitude: $model.values.longitude,
          latitudeMessage: model.message("latitude"),
          longitudeMessage: model.message("longitude"), hint: CoordinateHint.diveSite)
      } header: {
        FormSectionHeader(group: .location)
      }
      SiteRegistriesSection(entries: $model.values.externalIds)
      SiteDepthSection(
        values: $model.values, units: units, invalid: $invalid,
        message: { model.message($0) })
      SiteEntryTypesSection(values: $model.values)
      CommonsAttestationSection(
        attestation: CommonsAttestations.change, ticked: $model.ticked, message: $model.message)
    }
    .background(TapEndsTyping())
  }
}

#Preview {
  let json = """
    {"uuid":"01a0a521-28c5-7e34-a572-4d7324f5033b","name":"Quarry","notes":"",
     "latitude":28.5722,"longitude":34.5372,"other_names":[],"external_ids":[],
     "entry_types":["shore"],"tags":[],"dive_count":0,"species_count":0,
     "owner":"opendivingcommons","saved":true,"created_at":"2026-09-15T12:53:28.901059Z"}
    """
  let site = try! APICoding.decoder().decode(DiveSiteRead.self, from: Data(json.utf8))
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    ProposeChangeView(model: DiveSiteChangeModel(session: session, site: site))
  }
  .environment(session)
}
