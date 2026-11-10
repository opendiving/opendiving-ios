import OpenDivingKit
import SwiftUI

/// The dive form's site picker: the site finder, opened where the dive is, a tapped site going on
/// the dive and the sheet closing, as a picker's row does. The web's *Add dive site…* keeps its
/// sheet and its proposal flow, and a long press on the map opens that sheet pinned there.
struct SiteFinderSheet: View {
  let form: DiveFormModel

  @State private var model: SiteFinderModel
  @State private var map: MapStyleModel
  @State private var adding: AddingSite?
  @Environment(\.dismiss) private var dismiss
  @Environment(Session.self) private var session

  init(form: DiveFormModel, session: Session) {
    self.form = form
    _model = State(initialValue: SiteFinderModel(form: form, locator: CoreLocationProvider()))
    _map = State(initialValue: MapStyleModel(session: session))
  }

  var body: some View {
    NavigationStack {
      SiteFinderView(
        model: model, map: map, units: session.units,
        onSite: { site in
          form.addFound(site)
          dismiss()
        },
        onLongPress: { adding = AddingSite(pin: $0) },
        offlineRows: { form.rows(.diveSites, matching: $0) },
        onOfflineRow: { row in
          form.remember(row)
          form.addSite(row.ref)
          dismiss()
        },
        // The dive form names a touched point under its sheet and opens no site in the panel.
        site: { _ in EmptyView() },
        bar: {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              dismiss()
            } label: {
              Image(Icon.x)
            }
            .accessibilityLabel("Cancel")
            .mapBarButton()
          }
          ToolbarItem(placement: .primaryAction) {
            Button {
              adding = AddingSite(pin: nil)
            } label: {
              Label(FormPicker.diveSites.addLabel, systemImage: "plus")
            }
            .mapBarButton()
          }
        }
      )
      .sheet(item: $adding) { site in
        FormPicker.diveSites.addSheet(
          pin: site.pin,
          onCommonsSite: { found in
            adding = nil
            form.addFound(found)
            dismiss()
          },
          siteHandBack: SiteProposalHandBack(
            onPlaced: { form.addSite($0) },
            onReplaced: { form.swapSite($0, for: $1) }),
          onCreated: { ref in
            adding = nil
            form.addSite(ref)
            dismiss()
          })
      }
    }
  }
}

/// A new site asked for, from the + or at a point the map was pressed.
private struct AddingSite: Identifiable {
  let id = UUID()
  let pin: DeviceLocation?
}

#Preview {
  SiteFinderSheet(
    form: DiveFormModel(session: DivePreviewData.session, mode: .create),
    session: DivePreviewData.session
  )
  .environment(DivePreviewData.session)
}
