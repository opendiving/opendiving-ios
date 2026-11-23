import OpenDivingKit
import SwiftUI

/// *Add dives* on a course: the diver's dives not on it, newest first, and *+* logging a new one
/// on it.
struct CourseAddDivesView: View {
  let course: CourseRead
  @Environment(Session.self) private var session
  @Environment(OutboxModel.self) private var outbox

  var body: some View {
    CourseAttachView(
      words: .init(
        title: "Add dives", one: "dive", many: "dives", newLabel: "Log a dive",
        empty: "No other dives to add", emptyIcon: .dive, offline: OfflineText.divesNotShown),
      list: .allDives(session),
      offered: { CourseAttach.offered($0, course: course.uuid) },
      row: { CourseAttach.row($0, units: session.units) },
      attach: { CourseAttach.attach(dives: $0, to: course.uuid, in: outbox) },
      newForm: { DiveFormView(mode: .course(course.uuid)) }
    )
  }
}

#Preview {
  NavigationStack {
    CourseAddDivesView(course: DivePreviewData.course)
  }
  .environment(DivePreviewData.session)
  .environment(OutboxModel(session: DivePreviewData.session))
}
