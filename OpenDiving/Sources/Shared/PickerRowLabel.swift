import OpenDivingKit
import SwiftUI

/// A picker row: the record's name, what tells it apart, the mark of one not yet on the server
/// or of a Commons record, and where it is listed the credit that record owes.
struct PickerRowLabel: View {
  let row: FormPickerRow
  var isSelected = false
  var showsCredit = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(row.title).foregroundStyle(Color.primary)
          if row.isPending { PendingMark() }
          if row.isCommons {
            BadgeView(DiveSiteSummary.commonsLabel, style: .outline) { CommonsMark() }
          }
        }
        if let subtitle = row.subtitle {
          Text(subtitle).font(.subheadline).foregroundStyle(Color.secondary)
        }
        if showsCredit, let attribution = row.attribution {
          AttributionLine(credits: [attribution])
        }
      }
      Spacer()
      if isSelected {
        Image(systemName: "checkmark").foregroundStyle(Color.accentText)
      }
    }
  }
}

#Preview {
  Form {
    PickerRowLabel(row: FormPickerRow(ref: .local(UUID()), title: "Blue Hole", subtitle: "Dahab"))
  }
}
