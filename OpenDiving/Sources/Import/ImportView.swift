import OpenDivingKit
import SwiftUI
import UniformTypeIdentifiers

/// The import screen, the web's Import page on the phone: the files waiting in the account's
/// inbox, what reading them found, and *Import*. Reached from the Dives tab's `+` and shown
/// when a file is shared to the app.
struct ImportView: View {
  /// Opened because a file was shared to the app, which delivers one at a time.
  var shared = false

  @Environment(InboxModel.self) private var inbox
  @State private var picking = false
  @State private var pickFailure: String?
  @State private var choices = ImportCheckInChoices()

  var body: some View {
    List {
      if let result = inbox.result {
        ImportResultSections(result: result, numbering: inbox.resultNumbering, units: inbox.units) {
          inbox.dismissResult()
        }
      } else {
        inboxSections
      }
    }
    .navigationTitle("Import")
    .navigationBarTitleDisplayMode(.inline)
    .fileImporter(
      isPresented: $picking, allowedContentTypes: [.item], allowsMultipleSelection: true
    ) { result in
      switch result {
      case .success(let urls): pick(urls)
      case .failure(let error): pickFailure = error.localizedDescription
      }
    }
    .alert(
      "The files could not be picked",
      isPresented: Binding(get: { pickFailure != nil }, set: { if !$0 { pickFailure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(pickFailure ?? "")
    }
    .onChange(of: inbox.importable?.token) { choices = ImportCheckInChoices() }
  }

  @ViewBuilder private var inboxSections: some View {
    Section {
      if shared {
        Text(ImportText.oneAtATime)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Button("Import files", systemImage: "doc.badge.plus") { picking = true }
        .disabled(inbox.phase != .idle)
    } footer: {
      if inbox.files.isEmpty {
        Text(
          "Bring dives in from your dive computer, another logbook or an OpenDiving archive. "
            + "You see what each file becomes before anything is written.")
      }
    }

    if !inbox.files.isEmpty {
      Section("Files") {
        ForEach(inbox.files) { file in
          ImportFileRow(file: file)
        }
      }
      Section {
        if let refusal = inbox.selectionRefusal {
          Text(refusal).foregroundStyle(.red)
        }
        if !inbox.isAccountLoaded {
          Text("The files are read once your account has loaded.")
            .foregroundStyle(.secondary)
        }
        if inbox.read?.stale == true {
          Text(ImportText.staleSentence).foregroundStyle(.secondary)
        } else if let refusal = inbox.read?.refusal {
          Text(refusal).foregroundStyle(.red)
        }
        if inbox.phase == .reading {
          HStack(spacing: 8) {
            ProgressView()
            Text("Reading the files...").foregroundStyle(.secondary)
          }
        }
        if let title = readTitle {
          Button(title) { inbox.readAgain() }
            .disabled(!inbox.canRead)
        }
        Button("Remove all", role: .destructive) { inbox.removeAll() }
          .disabled(inbox.phase != .idle)
      }
    }

    if let error = inbox.applyError {
      Section {
        Text(error).foregroundStyle(.red)
      }
    }

    if let preview = inbox.importable {
      ImportReviewSections(
        preview: preview, units: inbox.units, choices: $choices,
        isImporting: inbox.phase == .importing
      ) {
        inbox.apply(choices)
      }
    }
  }

  /// *Read the files* over an inbox no read covers, *Read the files again* over one whose
  /// read is stale or refused, and nothing over a preview standing or a read in flight.
  private var readTitle: String? {
    guard inbox.phase == .idle else { return nil }
    guard let read = inbox.read else { return "Read the files" }
    return read.stale || read.preview == nil ? "Read the files again" : nil
  }

  /// Each picked file is read under its security scope, released before the next, into a
  /// staging copy; the selection then lands in the inbox as one arrival.
  private func pick(_ urls: [URL]) {
    let staged = urls.compactMap(SharedFileStaging.stage)
    guard !staged.isEmpty else { return }
    if case .notKept(let reason) = inbox.receive(staged, moving: true) {
      pickFailure = reason
    }
  }
}

#Preview {
  let session = Session.stub(transport: StubTransport(routes: [:]))
  NavigationStack {
    ImportView(shared: true)
  }
  .environment(session)
  .environment(InboxModel(session: session))
}
