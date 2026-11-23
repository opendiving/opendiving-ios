import OpenDivingKit
import SwiftUI
import UniformTypeIdentifiers

/// A certification opened from a list, as a pane: the sides it has a file for, each as wide as
/// the pane and unlabelled, then its details in one card as the dive's information pane draws
/// them, the course and the instructor opening their pages. Its title is the agency and the
/// certification. Close at the top left; Edit at the top right opens the form inside the pane.
struct CertificationSheet: View {
  let certificationUUID: UUID

  @Environment(Session.self) private var session

  var body: some View {
    CertificationSheetContent(
      page: RecordPage(session: session, certification: certificationUUID),
      lookups: LookupsModel(session: session))
  }
}

extension CertificationSheet {
  static let title = "Certification"
  static let notFound = "Certification not found."

  /// What a failed first read says: offline, that the card shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.certificationNotShown : error.message
  }
}

extension View {
  /// Opens the certification `opened` names in its pane.
  func certificationSheet(_ opened: Binding<CertificationRead?>) -> some View {
    sheet(item: opened) { CertificationSheet(certificationUUID: $0.uuid) }
  }
}

private struct CertificationSheetContent: View {
  @State var page: RecordPage<CertificationRead>
  @State var lookups: LookupsModel

  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss
  @State private var editing = false

  /// The agency and the certification once it is read; until then, what the pane is.
  private var title: String {
    guard case .loaded(let certification) = page.phase else { return CertificationSheet.title }
    return CertificationPageContent.title(certification)
  }

  var body: some View {
    NavigationStack {
      Group {
        switch page.phase {
        case .loading:
          EmptyOrErrorView(status: .loading)
        case .notFound:
          EmptyOrErrorView(status: .notFound(message: CertificationSheet.notFound))
        case .failed(let error):
          EmptyOrErrorView(status: .failed(message: CertificationSheet.failure(error))) {
            Task { await page.refresh() }
          }
        case .loaded(let certification):
          CertificationSheetList(
            certificationUUID: certification.uuid,
            content: CertificationPageContent(
              certification, today: .today(), session: session, lookups: lookups),
            lastUpdated: page.lastUpdated, hasPendingEdit: page.hasPendingEdit
          )
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
        if page.phase.isLoaded {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Edit certification", systemImage: "pencil") { editing = true }
          }
        }
      }
      .navigationDestination(isPresented: $editing) {
        if case .loaded(let certification) = page.phase {
          CertificationFormView(mode: .edit(certification)) { dismiss() }
        }
      }
    }
    // A swipe down would drop the edit unsaved.
    .interactiveDismissDisabled(editing)
    .task {
      await page.load()
      await page.followRoute()
    }
  }
}

private struct CertificationSheetList: View {
  let certificationUUID: UUID
  let content: CertificationPageContent
  let lastUpdated: Date?
  let hasPendingEdit: Bool

  var body: some View {
    List {
      if lastUpdated != nil || hasPendingEdit {
        Section {
          if let lastUpdated {
            LastUpdatedLine(date: lastUpdated)
          }
          if hasPendingEdit {
            PendingEditLine()
          }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
      }
      ForEach(content.sides) { side in
        Section {
          CertificationSideView(
            certificationUUID: certificationUUID, file: side.file,
            label: "\(side.title) of certification card"
          )
          .certificationDownload(certificationUUID: certificationUUID, file: side.file)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }
      }
      if !content.rows.isEmpty {
        Section {
          ForEach(content.rows, id: \.label) { row in
            CertificationInfoRow(row: row)
          }
        }
      }
      if let notes = content.notes {
        Section("Notes") {
          Text(notes)
        }
      }
    }
    // The bar ends 10 points below its buttons, so this puts the card the list's section spacing
    // below them: the gap above it matches the one under it.
    .contentMargins(.top, 25, for: .scrollContent)
  }
}

/// One detail as the dive's information pane draws it, opening the course's or the instructor's
/// page where it names one.
private struct CertificationInfoRow: View {
  let row: CertificationPageContent.Row

  var body: some View {
    switch row.link {
    case .course(let uuid):
      NavigationLink {
        CourseDetailView(courseUUID: uuid)
      } label: {
        LabeledContent(row.label, value: row.value)
      }
    case .person(let uuid):
      NavigationLink {
        PersonDetailView(personUUID: uuid)
      } label: {
        LabeledContent(row.label, value: row.value)
      }
    case nil:
      if let badge = row.badge {
        LabeledContent(row.label) {
          HStack(spacing: 8) {
            BadgeView(badge.label, style: badge == .expired ? .destructive : .coral)
            Text(row.value)
          }
        }
      } else {
        LabeledContent(row.label, value: row.value)
      }
    }
  }
}

extension View {
  /// A long press on a side saves it to Files under the name it was uploaded as — for a PDF,
  /// which the pane does not draw, the only way to open it.
  fileprivate func certificationDownload(certificationUUID: UUID, file: CertificationFileInfo)
    -> some View
  {
    modifier(CertificationDownload(certificationUUID: certificationUUID, file: file))
  }
}

private struct CertificationDownload: ViewModifier {
  let certificationUUID: UUID
  let file: CertificationFileInfo

  @Environment(Session.self) private var session
  @State private var bytes: Data?
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
      .contextMenu {
        Button("Download", systemImage: "arrow.down.to.line") {
          Task { await prepare() }
        }
      }
      .fileExporter(
        isPresented: Binding(get: { bytes != nil }, set: { if !$0 { bytes = nil } }),
        item: bytes ?? Data(), contentTypes: [UTType(mimeType: file.contentType) ?? .data],
        defaultFilename: file.originalFilename
      ) { _ in
        bytes = nil
      }
      .alert(
        "Error", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(failure ?? "")
      }
  }

  private func prepare() async {
    do {
      bytes = try await CertificationCardImages.download(
        of: certificationUUID, file, session: session)
    } catch {
      failure = CertificationPageContent.downloadFailure(APIError(error))
    }
  }
}

#Preview {
  CertificationSheet(certificationUUID: UUID())
    .environment(Session.stub(transport: StubTransport(routes: [:])))
}
