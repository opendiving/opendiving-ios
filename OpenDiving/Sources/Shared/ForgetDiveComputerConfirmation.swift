import OpenDivingKit
import SwiftUI

/// The one confirmation *Forget this dive computer* asks for, wherever it is offered.
struct ForgetDiveComputerConfirmation: ViewModifier {
  @Binding var record: DiveComputerRecord?
  let perform: (DiveComputerRecord) -> Void

  func body(content: Content) -> some View {
    content.confirmationDialog(
      record.map(DiveComputerText.forgetTitle) ?? DiveComputerText.forget,
      isPresented: Binding(get: { record != nil }, set: { if !$0 { record = nil } }),
      titleVisibility: .visible, presenting: record
    ) { record in
      Button("Forget", role: .destructive) { perform(record) }
    } message: { _ in
      Text(DiveComputerText.forgetMessage)
    }
  }
}

extension View {
  /// Asks before forgetting `record`, while it is set.
  func forgetDiveComputerConfirmation(
    record: Binding<DiveComputerRecord?>, perform: @escaping (DiveComputerRecord) -> Void
  ) -> some View {
    modifier(ForgetDiveComputerConfirmation(record: record, perform: perform))
  }
}
