import OpenDivingKit
import SwiftUI

/// The certification form as a screen of its own: a new card, one for `course` filled from it once,
/// a card's edit, a queued edit or card image the server refused, or with `failedItem` a queued
/// create the server refused.
struct CertificationFormView: View {
  let mode: RecordFormMode<CertificationRead>
  /// With `.create`: the course the card is for, which fills it once.
  var course: CourseRead?
  /// With `.create`: the refused create to reopen, by its outbox item's id.
  var failedItem: UUID?
  /// The certification was deleted from the form, which leaves its page nothing to show.
  var onDeleted: () -> Void = {}

  var body: some View {
    ManagedOnTheWebView(
      title: "Certification", icon: .badgeCheck, message: "Certifications are managed on the web.")
  }
}

#Preview {
  NavigationStack {
    CertificationFormView(mode: .create)
  }
}
