import OpenDivingKit
import SwiftUI

/// A species photo whole, its names and its credit as plain visible text, read from the
/// catalog when the sheet opens: the credit parts are served on the species alone.
struct SpeciesPhotoCreditSheet: View {
  let speciesUUID: UUID
  let photoVersion: String
  /// The card the sheet was opened from: its names, and the photo it drew.
  let content: SpeciesCardContent
  @Environment(Session.self) private var session

  var body: some View {
    SheetContent(
      content: content,
      model: SpeciesPhotoCreditModel(
        session: session, speciesUUID: speciesUUID, photoVersion: photoVersion,
        photo: content.photo))
  }
}

private struct SheetContent: View {
  let content: SpeciesCardContent
  @State private var model: SpeciesPhotoCreditModel
  @Environment(\.dismiss) private var dismiss

  init(content: SpeciesCardContent, model: SpeciesPhotoCreditModel) {
    self.content = content
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          photo
          VStack(alignment: .leading, spacing: 2) {
            Text(content.commonName)
              .font(.headline)
            if content.scientificName != content.commonName {
              Text(content.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            }
          }
          credit
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .navigationTitle("Photo Credit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .task { await model.load() }
  }

  @ViewBuilder private var photo: some View {
    if let data = model.photo, let image = UIImage(data: data) {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
  }

  @ViewBuilder private var credit: some View {
    switch model.phase {
    case .loading:
      ProgressView()
    case .notFound:
      message("This species is no longer in the catalog.")
    case .failed:
      message("The photo's credit could not be loaded.")
      Button("Try again") { Task { await model.load() } }
        .buttonStyle(.bordered)
    case .loaded:
      if let credit = model.credit {
        Text(Self.line(credit))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }

  /// Each part a text run, never markup: the author is a Commons user's own text.
  private static func line(_ credit: PhotoCreditContent) -> AttributedString {
    credit.runs.reduce(into: AttributedString()) { line, run in
      var part = AttributedString(run.text)
      if let url = run.url {
        part.link = url
        part.underlineStyle = .single
      }
      line += part
    }
  }
}

extension SpeciesPhotoCreditSheet {
  static let previewUUID = UUID(uuidString: "01a20000-0000-7000-8000-0000000000c1")!

  /// A session whose server answers for ``previewUUID`` with every part of a credit.
  static var previewSession: Session {
    Session.stub(
      transport: StubTransport(routes: [
        "GET species/\(previewUUID.uuidString.lowercased())": .json(
          """
          {"uuid":"\(previewUUID.uuidString.lowercased())",
          "scientific_name":"Amphiprion bicinctus","common_name":"Twoband anemonefish",
          "rank":"Species","photo_sha256":"ab12","photo_author":"Jane Doe",
          "photo_license":"CC BY-SA 4.0",
          "photo_license_url":"https://creativecommons.org/licenses/by-sa/4.0",
          "photo_source_url":"https://commons.wikimedia.org/wiki/File:Amphiprion_bicinctus.jpg"}
          """)
      ]))
  }
}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      SpeciesPhotoCreditSheet(
        speciesUUID: SpeciesPhotoCreditSheet.previewUUID, photoVersion: "ab12",
        content: SpeciesCardContent(
          commonName: "Twoband anemonefish", scientificName: "Amphiprion bicinctus"))
    }
    .environment(SpeciesPhotoCreditSheet.previewSession)
}
