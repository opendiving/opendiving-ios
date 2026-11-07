import OpenDivingKit
import SwiftUI

/// One of the dive form's record pickers: the phone's rows first, then the server's matches when
/// it can be asked, and the web's *Add…*.
struct RecordPickerSheet: View {
  let model: DiveFormModel
  let picker: FormPicker
  /// The tank a cylinder is picked for.
  var tank: Int?
  var current: RecordRef?
  var onSubmitText: ((String) -> Bool)?
  let onPick: (RecordRef?) -> Void

  var body: some View {
    PickerSheet(
      title: picker.sheetPrompt, searchPrompt: picker.searchPrompt,
      rows: { model.rows(picker, matching: $0, tank: tank) },
      search: { await model.searchServer(picker, matching: $0, tank: tank) },
      emptySentence: { model.emptySentence(picker, matching: $0, tank: tank) },
      current: current, onSubmitText: onSubmitText, onChoose: { model.remember($0) },
      addLabel: picker.addLabel,
      addSheet: { onCreated in
        picker.addSheet(
          onCommonsSite: { site in
            model.take(site)
            onCreated(site.ref)
          },
          siteHandBack: SiteProposalHandBack(
            onPlaced: { model.addSite($0) },
            onReplaced: { model.swapSite($0, for: $1) }),
          onCreated: onCreated)
      }, onPick: onPick)
  }
}

#Preview {
  RecordPickerSheet(
    model: DiveFormModel(session: DivePreviewData.session, mode: .create), picker: .trip
  ) { _ in }
}
