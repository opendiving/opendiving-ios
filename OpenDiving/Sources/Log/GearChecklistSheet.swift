import OpenDivingKit
import SwiftUI

/// A gear set at the water's edge: each item a row to tick, archived ones marked, *Tick all*.
/// The ticked items are the dive's gear from the first tick, so *Use these* only closes it.
struct GearChecklistSheet: View {
  let model: DiveFormModel

  var body: some View {
    NavigationStack {
      if let checklist = model.checklist {
        List(checklist.items, id: \.ref) { item in
          Button {
            model.toggleChecklistItem(item.ref)
          } label: {
            HStack {
              Image(systemName: checklist.isTicked(item.ref) ? "checkmark.square.fill" : "square")
                .foregroundStyle(checklist.isTicked(item.ref) ? Color.accentColor : .secondary)
                .font(.title3)
              Text(DiveDetailText.gearItemLabel(name: item.name, brand: item.brand))
                .foregroundStyle(.primary)
              Spacer()
              if item.isArchived { BadgeView("Archived", style: .outline) }
            }
          }
          .accessibilityAddTraits(checklist.isTicked(item.ref) ? .isSelected : [])
        }
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Tick all") { model.tickAll() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Use these") { model.closeChecklist() }
          }
        }
      }
    }
  }
}

#Preview {
  GearChecklistSheet(model: DiveFormModel(session: DivePreviewData.session, mode: .create))
}
