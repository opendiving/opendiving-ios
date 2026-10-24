import OpenDivingKit
import SwiftUI

/// The check-in details and the portrait an archive carries, each the import's unless the
/// diver keeps their own. A detail is taken as the import proposes it; changing one before
/// importing is the web's.
struct ImportCheckInSection: View {
  let details: [ImportCheckInDetail]
  let portrait: ImportPortraitOffer?
  @Binding var choices: ImportCheckInChoices

  var body: some View {
    if !details.isEmpty || portrait != nil {
      Section {
        if let portrait { portraitRow(portrait) }
        ForEach(details, id: \.key) { detail in detailRow(detail) }
      } header: {
        Text("Check-in Details")
      } footer: {
        Text(
          "The import carries what a dive shop asks for at check-in. What is chosen here is "
            + "saved to your account when you import, unless you keep yours.")
      }
    }
  }

  private func detailRow(_ detail: ImportCheckInDetail) -> some View {
    let mine = ImportText.checkInSummary(detail, proposed: false)
    let kept = choices.kept.contains(detail.key)
    return VStack(alignment: .leading, spacing: 4) {
      Text(ImportText.checkInLabel(detail)).font(.subheadline.weight(.medium))
      Text("Yours now: \(mine ?? "not set")").font(.footnote).foregroundStyle(.secondary)
      if kept {
        Text(
          mine == nil
            ? "Left unset; nothing from the import is saved."
            : "Keeping yours; nothing from the import is saved."
        )
        .font(.footnote)
      } else {
        Text("The import's: \(ImportText.checkInSummary(detail, proposed: true) ?? "not set")")
          .font(.footnote)
      }
      Button(kept ? "Use the import's" : mine == nil ? "Leave unset" : "Keep mine") {
        if kept { choices.kept.remove(detail.key) } else { choices.kept.insert(detail.key) }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  private func portraitRow(_ offer: ImportPortraitOffer) -> some View {
    let mine = offer.accountSha256 != nil
    let kept = choices.portraitKept
    return VStack(alignment: .leading, spacing: 6) {
      Text("Portrait").font(.subheadline.weight(.medium))
      if let image = Self.image(offer.proposed) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 64, height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel("Portrait from the import")
      }
      Text(
        kept
          ? mine
            ? "Keeping yours; nothing from the import is saved."
            : "Left unset; nothing from the import is saved."
          : mine
            ? "The import's replaces yours when you import."
            : "The import's is saved when you import."
      )
      .font(.footnote)
      Button(kept ? "Use the import's" : mine ? "Keep mine" : "Leave unset") {
        choices.portraitKept.toggle()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
  }

  /// The archive's portrait, sent as a `data:` URL.
  private static func image(_ dataURL: String) -> UIImage? {
    guard let comma = dataURL.firstIndex(of: ","),
      let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
    else { return nil }
    return UIImage(data: data)
  }
}

#Preview {
  @Previewable @State var choices = ImportCheckInChoices()
  List {
    ImportCheckInSection(
      details: ImportPreviewData.preview.checkInDetails, portrait: nil, choices: $choices)
  }
}
