import OpenDivingKit
import SwiftUI
import UniformTypeIdentifiers

/// A certification's page, the web's view dialog as a page: its level with the agency and expiry
/// badges, both sides large with a download for each stored one, the details underneath with the
/// course and the instructor linking to their pages, and Edit in the top bar.
struct CertificationDetailView: View {
  let certificationUUID: UUID

  @Environment(Session.self) private var session

  var body: some View {
    CertificationDetailContent(
      page: RecordPage(session: session, certification: certificationUUID),
      lookups: LookupsModel(session: session))
  }
}

extension CertificationDetailView {
  static let title = "Certification"
  static let notFound = "Certification not found."

  /// What a failed first read says: offline, that the card shows once it can be read.
  static func failure(_ error: APIError) -> String {
    error.isUnreachable ? OfflineText.certificationNotShown : error.message
  }
}

private struct CertificationDetailContent: View {
  @State var page: RecordPage<CertificationRead>
  @State var lookups: LookupsModel

  @Environment(Session.self) private var session
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      switch page.phase {
      case .loading:
        EmptyOrErrorView(status: .loading)
      case .notFound:
        EmptyOrErrorView(status: .notFound(message: CertificationDetailView.notFound))
      case .failed(let error):
        EmptyOrErrorView(status: .failed(message: CertificationDetailView.failure(error))) {
          Task { await page.refresh() }
        }
      case .loaded(let certification):
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            if let lastUpdated = page.lastUpdated {
              LastUpdatedLine(date: lastUpdated)
            }
            if page.hasPendingEdit {
              PendingEditLine()
            }
            CertificationPage(
              certificationUUID: certification.uuid,
              content: CertificationPageContent(
                certification, today: .today(), session: session, lookups: lookups))
          }
          .padding()
        }
        .bubbleRefreshable { await page.refresh() }
      }
    }
    .background(Color.pageBackground)
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if case .loaded(let certification) = page.phase {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            CertificationFormView(mode: .edit(certification)) { dismiss() }
          } label: {
            Label("Edit certification", systemImage: "pencil")
          }
        }
      }
    }
    .task {
      await page.load()
      await page.followRoute()
    }
  }

  private var title: String {
    if case .loaded(let certification) = page.phase {
      certification.name
    } else {
      CertificationDetailView.title
    }
  }
}

private struct CertificationPage: View {
  let certificationUUID: UUID
  let content: CertificationPageContent

  var body: some View {
    FlowLayout(spacing: 8, lineSpacing: 6) {
      Text(content.name)
        .font(.title2.weight(.semibold))
      if let agency = content.agency {
        BadgeView(agency, style: .outline)
      }
      if let expiry = content.expiry {
        BadgeView(expiry.label, style: expiry == .expired ? .destructive : .coral)
      }
    }
    ForEach(content.sides) { side in
      VStack(alignment: .leading, spacing: 8) {
        Text(side.title)
          .font(.subheadline.weight(.medium))
        CertificationSideView(
          certificationUUID: certificationUUID, file: side.file,
          label: "\(side.side.rawValue) of certification card")
        if let file = side.file {
          CertificationDownloadButton(certificationUUID: certificationUUID, file: file)
        }
      }
    }
    if !content.rows.isEmpty {
      VStack(alignment: .leading, spacing: 16) {
        ForEach(content.rows, id: \.label) { row in
          InfoRow(label: row.label) {
            switch row.link {
            case .course(let uuid):
              NavigationLink(row.value) { CourseDetailView(courseUUID: uuid) }
            case .person(let uuid):
              NavigationLink(row.value) { PersonDetailView(personUUID: uuid) }
            case nil:
              Text(row.value)
            }
          }
        }
      }
    }
    if let notes = content.notes {
      InfoRow(label: "Notes") {
        Text(notes)
      }
    }
  }
}

/// Saves one stored side to Files under the name it was uploaded as.
private struct CertificationDownloadButton: View {
  let certificationUUID: UUID
  let file: CertificationFileInfo

  @Environment(Session.self) private var session
  @State private var preparing = false
  @State private var bytes: Data?
  @State private var failure: String?

  var body: some View {
    Button {
      Task { await prepare() }
    } label: {
      if preparing {
        Label("Preparing...", systemImage: "hourglass")
      } else {
        Label("Download", systemImage: "arrow.down.to.line")
      }
    }
    .buttonStyle(.bordered)
    .disabled(preparing)
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
    preparing = true
    defer { preparing = false }
    do {
      bytes = try await CertificationCardImages.download(
        of: certificationUUID, file, session: session)
    } catch {
      failure = CertificationPageContent.downloadFailure(APIError(error))
    }
  }
}

#Preview {
  NavigationStack {
    CertificationDetailView(certificationUUID: UUID())
  }
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
