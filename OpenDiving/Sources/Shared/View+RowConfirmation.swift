import OpenDivingKit
import SwiftUI

extension View {
  /// Asks to confirm an action on `item` while `confirming` holds it, attached to the control on
  /// `item`'s own row: where iOS draws the dialog as a popover, its arrow points at that row
  /// rather than at the list. The actions are handed `item` itself, never a read of
  /// `confirming`, which the dialog clears as it closes, before a button's action runs.
  func rowConfirmation<Item: Identifiable, Actions: View, Message: View>(
    _ title: String, for item: Item, confirming: Binding<Item?>,
    @ViewBuilder actions: @escaping (Item) -> Actions,
    @ViewBuilder message: @escaping (Item) -> Message
  ) -> some View {
    confirmationDialog(
      title,
      isPresented: Binding(
        get: { confirming.wrappedValue?.id == item.id },
        set: { shown in
          if !shown, confirming.wrappedValue?.id == item.id { confirming.wrappedValue = nil }
        }),
      titleVisibility: .visible, presenting: item, actions: actions, message: message)
  }
}

#Preview {
  @Previewable @State var confirming: TagRead?
  let tag = TagRead(uuid: UUID(), name: "wreck", diveCount: 3, siteCount: 1)
  List {
    HStack {
      Text(tag.name)
      Spacer()
      Button("Delete", systemImage: "trash", role: .destructive) { confirming = tag }
        .labelStyle(.iconOnly)
        .rowConfirmation(TagsModel.deleteTitle, for: tag, confirming: $confirming) { tag in
          Button("Delete", role: .destructive) { confirming = nil }
        } message: { tag in
          Text(TagsModel.deleteMessage(tag))
        }
    }
  }
}
