import OpenDivingKit
import SwiftUI

/// One section of the form, its fields in the web's order, each where the account shows it:
/// a measured number with its unit toggle, a menu with *Not recorded* first, the pickers.
struct DiveFormSection: View {
  let group: DiveFormGroup
  let model: DiveFormModel

  var body: some View {
    switch group {
    case .importFiles: EmptyView()
    case .training: training
    case .location: location
    case .people: PeopleField(model: model)
    case .diveInfo: diveInfo
    case .environment: environment
    case .tanks: TanksSection(model: model)
    case .gear: gear
    case .marineLife: SpeciesField(model: model)
    case .notes: notes
    }
  }

  private var values: DiveFormValues { model.values }

  private func message(_ field: DiveFormField) -> String? { model.message(field.rawValue) }

  @ViewBuilder private var training: some View {
    if model.shows(.course) {
      RecordPickerField(
        model: model, title: DiveFormField.course.label, picker: .course, value: values.course,
        onChange: model.setCourse)
    }
  }

  @ViewBuilder private var location: some View {
    if model.shows(.trip) {
      RecordPickerField(
        model: model, title: DiveFormField.trip.label, picker: .trip, value: values.trip,
        onChange: model.setTrip)
    }
    if model.shows(.contact) {
      RecordPickerField(
        model: model, title: DiveFormField.contact.label, picker: .contact,
        value: values.contact, onChange: model.setContact)
    }
    if model.shows(.diveSites) {
      DiveSitesField(model: model)
    }
    if model.shows(.entryType) {
      VocabularyPicker(
        title: DiveFormField.entryType.label, values: FormVocabulary.entryTypes,
        label: VocabularyLabels.entryType, selection: values.entryType,
        error: message(.entryType)
      ) { entry in model.change { $0.entryType = entry } }
    }
    if model.shows(.boatName) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(DiveFormField.boatName.label)
        TextField(
          "e.g. Legend",
          text: Binding(
            get: { values.boatName }, set: { name in model.change { $0.boatName = name } })
        )
        if let error = message(.boatName) { FieldMessage(error) }
      }
    }
  }

  @ViewBuilder private var diveInfo: some View {
    let required = model.marksRequired ? " *" : ""
    if model.shows(.type) {
      VocabularyPicker(
        title: DiveFormField.type.label, values: Self.offeredDiveTypes,
        label: VocabularyLabels.diveType, selection: values.type, error: message(.type)
      ) { type in model.change { $0.type = type } }
    }
    DiveStartField(
      title: "Start time" + required, start: values.startTime, offsets: model.offsetChoices,
      error: model.message("start_time")
    ) { start in model.change { $0.startTime = start } }
    DiveNumberField(
      title: "Dive number" + required, number: values.diveNumber,
      notice: model.numberNotice, error: model.message("dive_number")
    ) { number in model.change { $0.diveNumber = number } }
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel("Dive time" + required)
      TextField(
        DiveDuration.placeholder,
        text: Binding(
          get: { values.submergedTime }, set: { text in model.change { $0.submergedTime = text } })
      )
      .keyboardType(.numbersAndPunctuation)
      if let error = model.message("submerged_time") { FieldMessage(error) }
    }
    if model.shows(.maxDepth) {
      MeasuredField(
        model: model, title: DiveFormField.maxDepth.label, measure: .depth, example: 30.52,
        min: 0, value: values.maxDepth, error: message(.maxDepth)
      ) { depth in model.change { $0.maxDepth = depth } }
    }
    if model.shows(.avgDepth) {
      MeasuredField(
        model: model, title: DiveFormField.avgDepth.label, measure: .depth, example: 18.24,
        min: 0, value: values.avgDepth, error: message(.avgDepth)
      ) { depth in model.change { $0.avgDepth = depth } }
    }
  }

  @ViewBuilder private var environment: some View {
    if model.shows(.bottomTemperature) {
      MeasuredField(
        model: model, title: DiveFormField.bottomTemperature.label, measure: .temperature,
        example: 22.5, min: -50, max: 50, value: values.bottomTemperature,
        error: message(.bottomTemperature)
      ) { celsius in model.change { $0.bottomTemperature = celsius } }
    }
    if model.shows(.visibility) {
      MeasuredField(
        model: model, title: DiveFormField.visibility.label, measure: .visibility, example: 15,
        min: 0, value: values.visibility.map(Double.init), error: message(.visibility)
      ) { meters in model.change { $0.visibility = meters.map { Int($0) } } }
    }
    if model.shows(.waterType) {
      VocabularyPicker(
        title: DiveFormField.waterType.label, values: FormVocabulary.waterTypes,
        label: VocabularyLabels.waterType, selection: values.waterType,
        error: message(.waterType)
      ) { water in model.change { $0.waterType = water } }
    }
    if model.shows(.altitude) {
      MeasuredField(
        model: model, title: DiveFormField.altitude.label, measure: .altitude, example: 372,
        min: -450, max: 6500, value: values.altitude.map(Double.init), error: message(.altitude)
      ) { meters in model.change { $0.altitude = meters.map { Int($0) } } }
    }
    if model.shows(.waves) {
      VocabularyPicker(
        title: DiveFormField.waves.label, values: FormVocabulary.waves,
        label: VocabularyLabels.waves, selection: values.waves, error: message(.waves)
      ) { waves in model.change { $0.waves = waves } }
    }
    if model.shows(.current) {
      VocabularyPicker(
        title: DiveFormField.current.label, values: FormVocabulary.currents,
        label: VocabularyLabels.current, selection: values.current, error: message(.current)
      ) { current in model.change { $0.current = current } }
    }
    if model.shows(.weather) {
      VocabularyPicker(
        title: DiveFormField.weather.label, values: FormVocabulary.weather,
        label: VocabularyLabels.weather, selection: values.weather, error: message(.weather)
      ) { weather in model.change { $0.weather = weather } }
    }
    if model.shows(.airTemperature) {
      MeasuredField(
        model: model, title: DiveFormField.airTemperature.label, measure: .temperature,
        example: 28, min: -60, max: 60, value: values.airTemperature,
        error: message(.airTemperature)
      ) { celsius in model.change { $0.airTemperature = celsius } }
    }
  }

  @ViewBuilder private var gear: some View {
    if model.shows(.gearItems) {
      GearField(model: model)
    }
    if model.shows(.weight) {
      MeasuredField(
        model: model, title: DiveFormField.weight.label, measure: .weight, example: 6, min: 0,
        value: values.weight, error: message(.weight)
      ) { kg in model.change { $0.weight = kg } }
    }
  }

  @ViewBuilder private var notes: some View {
    if model.shows(.rating) {
      RatingField(rating: values.rating, error: message(.rating)) { rating in
        model.change { $0.rating = rating }
      }
    }
    if model.shows(.tags) {
      TagsField(
        tags: values.tags, error: message(.tags), onAdd: model.addTag, onRemove: model.removeTag)
    }
    if model.shows(.notes) {
      VStack(alignment: .leading, spacing: 6) {
        FieldLabel(DiveFormField.notes.label)
        TextField(
          "Enter any additional notes about your dive...",
          text: Binding(get: { values.notes }, set: { text in model.change { $0.notes = text } }),
          axis: .vertical
        )
        .lineLimit(4...12)
        if let error = message(.notes) { FieldMessage(error) }
      }
    }
  }

  /// Freediving and snorkelling stay in the vocabulary a stored dive can hold, and the form does
  /// not offer them, as the web's does not.
  static let offeredDiveTypes = FormVocabulary.diveTypes.filter {
    $0 != "freedive" && $0 != "snorkel"
  }
}

/// The dive number, a suggestion the diver may change, with the web's note while it holds a
/// number another dive carries.
private struct DiveNumberField: View {
  let title: String
  let number: Int?
  let notice: String?
  let error: String?
  let onChange: (Int?) -> Void

  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      FieldLabel(title)
      TextField("", text: $text)
        .keyboardType(.numberPad)
        .focused($focused)
        .onChange(of: text) { _, typed in
          guard focused else { return }
          onChange(Int(typed.trimmingCharacters(in: .whitespaces)))
        }
      if let notice { FieldMessage(notice, isNote: true) }
      if let error { FieldMessage(error) }
    }
    .onAppear { text = number.map(String.init) ?? "" }
    .onChange(of: number) { _, now in if !focused { text = now.map(String.init) ?? "" } }
  }
}

#Preview {
  Form {
    DiveFormSection(
      group: .diveInfo, model: DiveFormModel(session: DivePreviewData.session, mode: .create))
  }
}
