import OpenDivingKit
import SwiftUI

/// The Info button in a detail page's toolbar, opening the record's own fields.
struct RecordInfoButton: View {
  let title: String
  let sections: [RecordInfoSection]

  @State private var showsSheet = false

  var body: some View {
    Button {
      showsSheet = true
    } label: {
      Label("Info", systemImage: "info.circle")
    }
    .sheet(isPresented: $showsSheet) {
      RecordInfoSheet(title: title, sections: sections)
    }
  }
}

#Preview {
  RecordInfoButton(
    title: "Dive Information",
    sections: [RecordInfoSection(facts: [RecordInfoFact(label: "Dive number", value: "42")])])
}
