import OpenDivingKit
import PDFKit
import SwiftUI
import UIKit

/// The card's own shape, `CERTIFICATION_CARD_ASPECT` on the web: every side is drawn at it.
private let cardAspect: CGFloat = 1013 / 638

/// The check-in sheet a dive centre reads at a counter, as the profile's *Cards* and the signed-out
/// sheet draw it, inside the host's scroll view: or, with none on the phone, why not.
struct CheckinSheetView: View {
  let model: CheckinSheetModel
  /// Its host's, so the decoded sides outlast the sheet leaving the screen.
  let pictures: PictureCache
  @State private var fullScreen: FullScreenCard?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if let content = model.content {
        sheet(content)
      } else if model.isRefreshing {
        EmptyOrErrorView(status: .loading)
      } else if let error = model.refreshError {
        EmptyOrErrorView(status: .failed(message: error)) {
          Task { await model.refresh() }
        }
      } else {
        EmptyOrErrorView(
          status: .empty(
            icon: .idCard, title: "No check-in sheet on this phone",
            message: model.isSignedIn
              ? nil : "Sign in once with a connection and the sheet is kept here."))
      }
    }
    .fullScreenCover(item: $fullScreen) { card in
      FullScreenCardView(card: card)
    }
  }

  private func sheet(_ content: CheckinSheetContent) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      status(content)
      header(content)
      SectionCard(title: "Diving") {
        rows(content.diving)
      }
      if !content.insurance.isEmpty {
        SectionCard(title: "Dive Insurance") {
          groups(content.insurance)
        }
      }
      if !content.emergencyContacts.isEmpty {
        SectionCard(title: "Emergency Contacts") {
          groups(content.emergencyContacts)
        }
      }
      if !content.cards.isEmpty {
        SectionCard(title: "Certifications") {
          VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(content.cards.enumerated()), id: \.element.id) { index, card in
              if index > 0 { Divider() }
              certification(card)
            }
          }
        }
      }
    }
  }

  /// When the sheet was read, why the last refresh failed, and the way to refresh signed out.
  private func status(_ content: CheckinSheetContent) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Text(content.lastUpdated)
        if model.isRefreshing {
          BubbleSpinner().controlSize(.small)
        }
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
      if let error = model.refreshError {
        Text(error)
          .font(.footnote)
          .foregroundStyle(Color.danger)
      }
      if !model.isSignedIn {
        Button("Sign in to refresh") { dismiss() }
          .font(.footnote)
          .accentRow()
      }
    }
  }

  private func header(_ content: CheckinSheetContent) -> some View {
    HStack(alignment: .top, spacing: 16) {
      if let portrait = content.portrait, let image = pictures.image(portrait, from: model) {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 84, height: 108)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .accessibilityLabel("Portrait of \(content.name)")
      }
      VStack(alignment: .leading, spacing: 8) {
        Text(content.name)
          .font(.title2.weight(.semibold))
          .accessibilityAddTraits(.isHeader)
        rows(content.about)
      }
    }
  }

  private func rows(_ figures: [Figure]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(figures, id: \.label) { figure in
        InfoRow(label: figure.label) {
          Text(figure.value ?? "")
            .textSelection(.enabled)
        }
      }
    }
  }

  private func groups(_ groups: [[Figure]]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(groups.enumerated()), id: \.offset) { index, figures in
        if index > 0 { Divider() }
        rows(figures)
      }
    }
  }

  private func certification(_ card: CheckinCardContent) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      FlowLayout(spacing: 8, lineSpacing: 6) {
        Text(card.name)
          .font(.headline)
        if let agency = card.agency {
          BadgeView(agency, style: .outline)
        }
        if let expiry = card.expiry {
          BadgeView(expiry.label, style: expiry == .expired ? .destructive : .coral)
        }
      }
      ForEach(card.sides) { side in
        VStack(alignment: .leading, spacing: 6) {
          Text(side.label)
            .font(.subheadline.weight(.medium))
          sideView(side, of: card)
        }
      }
      rows(card.rows)
      if let notes = card.notes {
        InfoRow(label: "Notes") {
          Text(notes)
        }
      }
    }
  }

  @ViewBuilder
  private func sideView(_ side: CheckinCardContent.Side, of card: CheckinCardContent)
    -> some View
  {
    if let file = side.file, let image = pictures.image(file, from: model) {
      Button {
        fullScreen = FullScreenCard(card: card, startingAt: side, pictures: pictures, model: model)
      } label: {
        // A card stored uncropped fills the frame and loses a sliver of its edge, as on the
        // web, rather than sitting in a letterbox.
        Color.clear
          .aspectRatio(cardAspect, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .overlay {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(side.label) of \(card.name)")
      .accessibilityHint("Shows the card full-screen")
    } else {
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [5]))
        .aspectRatio(cardAspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay {
          Text(side.file == nil ? side.missingText : "Couldn't show this image")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
  }
}

/// Pictures decoded once from the cached bytes: an image, or a PDF's first page drawn at the
/// card's aspect.
@MainActor
final class PictureCache {
  private var images: [CheckinSheetFile: UIImage] = [:]

  func image(_ file: CheckinSheetFile, from model: CheckinSheetModel) -> UIImage? {
    if let image = images[file] { return image }
    guard let data = model.data(for: file) else { return nil }
    let image = file.isPDF ? Self.firstPage(of: data) : UIImage(data: data)
    images[file] = image
    return image
  }

  private static func firstPage(of data: Data) -> UIImage? {
    guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
    let width: CGFloat = 2026
    return page.thumbnail(of: CGSize(width: width, height: width / cardAspect), for: .mediaBox)
  }
}

/// One card's stored sides, full-screen, the tapped one first in view.
private struct FullScreenCard: Identifiable {
  struct Page: Identifiable {
    let id: String
    let label: String
    let image: UIImage
  }

  let id = UUID()
  let title: String
  let pages: [Page]
  let start: String

  @MainActor
  init(
    card: CheckinCardContent, startingAt side: CheckinCardContent.Side, pictures: PictureCache,
    model: CheckinSheetModel
  ) {
    title = card.name
    pages = card.sides.compactMap { side in
      guard let file = side.file, let image = pictures.image(file, from: model) else {
        return nil
      }
      return Page(id: side.id, label: side.label, image: image)
    }
    start = side.id
  }
}

/// A card side filling the screen, rotating with the phone, front and back by swipe, with
/// the screen at full brightness while it is up.
private struct FullScreenCardView: View {
  let card: FullScreenCard
  @State private var selection: String
  @State private var brightness = CardBrightness(screen: WindowSceneBrightness())
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase

  init(card: FullScreenCard) {
    self.card = card
    _selection = State(initialValue: card.start)
  }

  var body: some View {
    NavigationStack {
      TabView(selection: $selection) {
        ForEach(card.pages) { page in
          Image(uiImage: page.image)
            .resizable()
            .scaledToFit()
            .padding()
            .accessibilityLabel("\(page.label) of \(card.title)")
            .tag(page.id)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: card.pages.count > 1 ? .always : .never))
      .background(Color.black)
      .navigationTitle(card.pages.first { $0.id == selection }?.label ?? card.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.black, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .onAppear { brightness.cardShown() }
    .onDisappear { brightness.cardDismissed() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        brightness.appBecameActive()
      } else {
        brightness.appResignedActive()
      }
    }
  }
}

#Preview {
  ScrollView {
    CheckinSheetView(
      model: CheckinSheetModel(
        session: Session.signedOutStub(transport: StubTransport(routes: [:]))),
      pictures: PictureCache()
    )
    .padding()
  }
}
