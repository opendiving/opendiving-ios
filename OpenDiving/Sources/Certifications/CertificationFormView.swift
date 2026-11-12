import OpenDivingKit
import SwiftUI

/// The certification form as a screen of its own: a new card, one for `course` filled from it once,
/// a card's edit, a queued edit or card image the server refused, or with `failedItem` a queued
/// create the server refused. Its details and its card images save as one: the card is queued,
/// then each side's change after it.
struct CertificationFormView: View {
  let mode: RecordFormMode<CertificationRead>
  /// With `.create`: the course the card is for, which fills it once.
  var course: CourseRead?
  /// With `.create`: the refused create to reopen, by its outbox item's id.
  var failedItem: UUID?
  /// The certification was deleted from the form, which leaves its page nothing to show.
  var onDeleted: () -> Void = {}

  @Environment(Session.self) private var session

  var body: some View {
    switch mode {
    case .create:
      form(
        RecordSheetModel(
          outbox: OutboxModel(session: session), values: createValues, failedItem: failedItem),
        certification: nil)
    case .edit(let certification):
      form(edit(certification, failedItem: nil), certification: certification)
    case .failed(let item, let uuid):
      RecordFormLoader {
        try await session.requireClient().certification(uuid)
      } content: { certification in
        // A refused card image reopens on the card, its side holding the bytes it waited with;
        // only a refused edit of the card itself is the form's own write to reopen.
        if let outboxItem = OutboxModel(session: session).item(item),
          let reopened = CertificationCardEdits.reopening(outboxItem, session: session)
        {
          form(edit(certification, failedItem: nil), certification: certification, card: reopened)
        } else {
          form(edit(certification, failedItem: item), certification: certification)
        }
      }
    }
  }

  private var createValues: CertificationFormValues {
    guard let course else { return CertificationFormValues() }
    return CertificationFormValues(for: CertificationCourseFill(course), ref: .server(course.uuid))
  }

  private func edit(_ certification: CertificationRead, failedItem: UUID?)
    -> RecordSheetModel<CertificationFormValues>
  {
    RecordSheetModel(
      outbox: OutboxModel(session: session), editing: .server(certification.uuid),
      read: CertificationFormValues(editing: certification), failedItem: failedItem)
  }

  private func form(
    _ model: RecordSheetModel<CertificationFormValues>, certification: CertificationRead?,
    card: CertificationCardEdits.CardReopening? = nil
  ) -> some View {
    CertificationSheetForm(
      model: model, lookups: LookupsModel(session: session), outbox: OutboxModel(session: session),
      edits: CertificationCardEdits(reopening: card), certification: certification,
      reopenedCard: card, onDeleted: onDeleted)
  }
}

extension CertificationFormView {
  static let courseHint = "The training this card came out of, if you logged it."
  static let courseFillHint =
    " Picking one fills in the certification, dive center and instructor below, and the agency"
    + " if the course names one."
}

private struct CertificationSheetForm: View {
  @State var model: RecordSheetModel<CertificationFormValues>
  @State var lookups: LookupsModel
  @State var outbox: OutboxModel
  @State var edits: CertificationCardEdits
  let certification: CertificationRead?
  let reopenedCard: CertificationCardEdits.CardReopening?
  let onDeleted: () -> Void

  @Environment(\.dismiss) private var dismiss
  /// The sides the phone could not keep after the card itself was queued.
  @State private var notKept: [CertificationSide] = []

  var body: some View {
    RecordSheetForm(
      title: model.isEditing ? "Edit Certification" : "New Certification",
      isReopened: model.isReopened, createLabel: "Create certification", isPushed: true,
      failure: model.failure ?? reopenedCard?.failure, saveError: model.saveError,
      deletion: deletion, save: save
    ) {
      Section {
        RecordPicker(
          label: "Course", placeholder: "Select a course...", searchPrompt: "Search courses...",
          addLabel: "Add course...", rows: lookups.courses, selection: course
        ) { made in
          NewCourseSheet(onCreated: made)
        }
      } footer: {
        Text(
          CertificationFormView.courseHint
            + (model.isEditing ? "" : CertificationFormView.courseFillHint))
      }
      TrainingFields(
        agencyRequired: true, agency: agency, agencyOther: $model.values.agencyOther,
        start: .init(label: "Certified on", field: "certified_on", date: certifiedOn),
        end: .init(label: "Expires on", field: "expires_on", date: $model.values.expiresOn),
        contact: $model.values.contact, instructor: $model.values.instructor,
        instructorNumber: $model.values.instructorNumber, lookups: lookups,
        message: { model.message($0) }
      ) {
        TextBox(
          label: "Certification *", placeholder: "e.g. Advanced Open Water Diver",
          text: $model.values.name, message: model.message("name"))
      } besideAgency: {
        TextBox(
          label: "Certification number", placeholder: "As printed on the card",
          text: $model.values.certificationNumber, message: model.message("certification_number"))
      }
      Section {
        ForEach(CertificationCardSlot.slots(certification, edits: edits), id: \.side) { slot in
          CertificationCardSlotView(
            certificationUUID: certification?.uuid, slot: slot,
            onPick: { edits[slot.side] = .replace($0) },
            onRemove: { edits[slot.side] = .remove },
            onUndo: { edits[slot.side] = nil })
        }
      } header: {
        Text("Card images")
      } footer: {
        Text(CertificationCardEdits.hint)
      }
      Section {
        NotesField(
          placeholder: "Specialties covered, restrictions, anything worth remembering...",
          text: $model.values.notes, error: model.message("notes"))
      }
    }
    .alert(
      notKept.first.map(CertificationCardEdits.notKept) ?? "",
      isPresented: Binding(get: { !notKept.isEmpty }, set: { if !$0 { notKept = [] } })
    ) {
      Button("OK", role: .cancel) { dismiss() }
    } message: {
      Text("Try picking the image again.")
    }
  }

  /// Picking a course on a new card fills it from the picker's row. An edit relinks the card and
  /// changes nothing else.
  private var course: Binding<RecordRef?> {
    Binding(
      get: { model.values.course },
      set: { ref in
        model.values.course = ref
        guard let ref, !model.isEditing,
          let fill = CertificationCourseFill.picked(ref, outbox: outbox, rows: lookups.courses)
        else { return }
        model.values.fill(from: fill)
      })
  }

  /// A card always names an agency, so the shared fields' optional is never cleared.
  private var agency: Binding<String?> {
    Binding(
      get: { model.values.agency },
      set: { model.values.agency = $0 ?? CertificationFormValues.defaultAgency })
  }

  /// Moving the certified date past the expiry empties the expiry.
  private var certifiedOn: Binding<CalendarDate?> {
    Binding(get: { model.values.certifiedOn }, set: { model.values.pickCertifiedOn($0) })
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Delete certification", message: RecordDeletionText.certification,
      delete: model.delete, onDeleted: onDeleted)
  }

  private func save() -> Bool {
    guard let ref = model.save() else { return false }
    notKept = edits.queue(of: ref, outbox: outbox, reopened: reopenedCard)
    return notKept.isEmpty
  }
}

#Preview {
  NavigationStack {
    CertificationFormView(mode: .create)
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
