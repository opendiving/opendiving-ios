import OpenDivingKit
import SwiftUI

/// A saved Commons record's edit form: what the record says, shown and not to be changed, its
/// credit, and the diver's own tags and notes, the only thing it saves.
struct CommonsSiteForm: View {
  let site: DiveSiteRead
  @State var model: RecordSheetModel<DiveSiteFormValues>
  let units: UnitSystem
  var onDeleted: () -> Void = {}

  var body: some View {
    ScrollViewReader { proxy in
      RecordSheetForm(
        title: "Edit Dive Site", isReopened: true, isPushed: true, failure: model.failure,
        saveError: model.saveError, deletion: deletion, save: { model.save() != nil }
      ) {
        Section {
          ForEach(DiveSiteSummary.sharedMembers(site, units: units), id: \.self) { member in
            LabeledContent(member.label, value: member.value)
          }
        } header: {
          BadgeView(DiveSiteSummary.commonsLabel, style: .outline)
            .textCase(nil)
        } footer: {
          if let attribution = site.attribution {
            AttributionLine(credits: [attribution])
          }
        }
        SiteNotesSection(model: model)
      }
      .followsAddedTags(
        count: model.values.tags.count, id: SiteNotesSection.tagsField, proxy: proxy)
    }
  }

  private var deletion: RecordDeletion? {
    guard model.canDelete else { return nil }
    return RecordDeletion(
      title: "Remove from your sites", message: RecordDeletionText.commonsSite,
      delete: model.delete, onDeleted: onDeleted)
  }
}

/// The diver's own words on a site, on either form.
struct SiteNotesSection: View {
  static let tagsField = "tags"

  let model: RecordSheetModel<DiveSiteFormValues>

  var body: some View {
    @Bindable var model = model
    Section {
      TagsField(
        tags: model.values.tags, error: model.message("tags"),
        onAdd: { model.values.addTag($0) },
        onRemove: { model.values.removeTag($0) }
      )
      .id(Self.tagsField)
      NotesField(
        placeholder: "Any notes about this dive site...", text: $model.values.notes,
        error: model.message("notes"))
    } header: {
      FormSectionHeader(group: .notes)
    }
  }
}
