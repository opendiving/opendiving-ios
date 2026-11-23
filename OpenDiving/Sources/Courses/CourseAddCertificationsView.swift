import OpenDivingKit
import SwiftUI

/// *Add certifications* on a course: the diver's cards not on it, newest first, and *+* adding a
/// new one on it.
struct CourseAddCertificationsView: View {
  let course: CourseRead
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox

  var body: some View {
    CourseAttachView(
      words: .init(
        title: "Add certifications", one: "certification", many: "certifications",
        newLabel: "New certification", empty: "No other certifications to add",
        emptyIcon: .badgeCheck, offline: OfflineText.certificationsNotShown),
      list: .certifications(session),
      offered: { CourseAttach.offered($0, course: course.uuid) },
      row: CourseAttach.row,
      attach: { CourseAttach.attach(certifications: $0, to: course.uuid, in: outbox) },
      newForm: { CertificationFormView(mode: .create, course: course) }
    )
  }
}

#Preview {
  NavigationStack {
    CourseAddCertificationsView(course: DivePreviewData.course)
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
