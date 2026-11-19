import OpenDivingKit
import SwiftUI

/// The import screen, the web's Import page on the phone: the import the server holds, from
/// whichever device uploaded it, above the files the phone keeps. Reached from *Dive Computers*
/// and *More*, and shown when a file is shared to the app.
struct ImportView: View {
  /// Opened because a file was shared to the app, which delivers one at a time.
  var shared = false

  @Environment(Session.self) private var session
  @Environment(InboxModel.self) private var inbox
  @State private var history: PagedList<LogbookImportSummary>?
  @State private var picking = false
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
    .importFilePicker(isPresented: $picking)
    .onChange(of: inbox.pending?.uuid) { choices = ImportCheckInChoices() }
    .task(id: inbox.isAccountLoaded) { inbox.readPending() }
    .task {
      guard history == nil else { return }
      let list = ImportHistorySection.list(session)
      history = list
      await list.load()
    }
  }

  @ViewBuilder private var inboxSections: some View {
    Section {
      if shared {
        Text(ImportText.oneAtATime)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Button {
        picking = true
      } label: {
        Label("Import files", icon: .upload)
      }
      .accentRow()
      .disabled(inbox.phase != .idle)
    } footer: {
      if inbox.files.isEmpty {
        Text(
          "Bring dives in from your dive computer, another logbook or an OpenDiving archive. "
            + "You see what each file becomes before anything is written.")
      }
    }

    if let error = inbox.applyError {
      Section {
        Text(error).foregroundStyle(Color.danger)
      }
    }

    if let pending = inbox.pending {
      ImportReviewSections(
        pending: pending, units: inbox.units, choices: $choices, phase: inbox.phase,
        onImport: { inbox.apply(choices) }, onDiscard: { inbox.discard() })
    }

    if !inbox.files.isEmpty {
      Section("Files") {
        ForEach(inbox.files) { file in
          ImportFileRow(file: file)
        }
      }
    }

    if !inbox.waiting.isEmpty {
      Section {
        if let refusal = inbox.selectionRefusal {
          Text(refusal).foregroundStyle(Color.danger)
        }
        if !inbox.isAccountLoaded {
          Text("The files can be uploaded once your account has loaded.")
            .foregroundStyle(.secondary)
        }
        if let hold = inbox.uploadHold {
          Text(hold).foregroundStyle(.secondary)
        }
        if let error = inbox.uploadError {
          Text(error).foregroundStyle(Color.danger)
        }
        if inbox.phase == .uploading {
          HStack(spacing: 8) {
            BubbleSpinner()
            Text("Uploading the files...").foregroundStyle(.secondary)
          }
        } else {
          Button("Upload") { inbox.upload() }
            .accentRow()
            .disabled(!inbox.canUpload)
        }
        Button("Remove all", role: .destructive) { inbox.removeAll() }
          .dangerRow()
          .disabled(inbox.phase != .idle)
      }
    }

    if inbox.pending == nil, let history {
      ImportHistorySection(list: history)
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
