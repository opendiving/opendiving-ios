import OpenDivingKit
import SwiftUI

/// The profile's QR button's pane: the diver's connect link as a QR code to show, its reset and
/// removal under it and the share in the top bar, or the way to make one while there is none; and
/// under it a scanner and a paste for somebody else's link. A given link the app acts on closes
/// the pane, its screen opening as it closes, and one it does not act on is answered here: a
/// connect link on the flagship with the switch there, which closes the pane first.
struct ConnectLinkSheet: View {
  @Environment(Session.self) private var session

  var body: some View {
    ConnectLinkPane(session: session)
  }
}

private struct ConnectLinkPane: View {
  @Environment(Session.self) private var session
  /// The root's; absent only where a test or a preview hosts the pane alone.
  @Environment(ScreenPresenter.self) private var presenter: ScreenPresenter?
  @Environment(SignInFlow.self) private var signIn: SignInFlow?
  @State private var model: ConnectLinkModel
  @State private var isScanning = false
  @State private var scannerUnavailable: ConnectLinkModel.ScannerUnavailable?
  @State private var answer: GivenLinkAnswer?
  /// The screen a given link opens, once the pane has closed.
  @State private var handedOver: AppLink.Screen?
  /// The switch to the flagship a given link's answer was taken up on, once the pane has closed:
  /// the switch starts the signed-in screens over, the pane's among them.
  @State private var switching: FlagshipOffer?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  init(session: Session) {
    _model = State(initialValue: ConnectLinkModel(session: session))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          content
          Divider()
          others
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
      .navigationTitle(ConnectLinkModel.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
        if let address = model.linkAddress {
          ToolbarItem(placement: .topBarTrailing) {
            ShareLink(
              item: address, subject: Text(model.shareTitle),
              preview: SharePreview(model.shareTitle)
            ) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
          }
        }
      }
    }
    .onDisappear {
      if let handedOver { presenter?.open(handedOver) }
      if let switching, let signIn {
        Task {
          if let screen = await signIn.switchToFlagship(switching) { presenter?.open(screen) }
        }
      }
    }
    .task { await model.load() }
    .task { await model.followRoute() }
    // Whether the instance admits only those invited, which the pane's note depends on.
    .task { await session.loadServerInfo() }
  }

  @ViewBuilder private var content: some View {
    // Read again each time the pane opens; a read that fails leaves the phone's copy dated.
    if let lastUpdated = model.lastUpdated {
      LastUpdatedLine(date: lastUpdated)
    }
    if !model.isLinkRead {
      if let failure = model.linkLoadFailure {
        Text(ConnectLinkModel.linkLoadFailed + " " + failure)
          .foregroundStyle(.secondary)
        Button("Try again") { Task { await model.load() } }
          .needsServer()
          .accentRow()
      } else {
        HStack {
          BubbleSpinner()
          Text(ConnectLinkModel.loading)
        }
        .foregroundStyle(.secondary)
      }
    } else if let address = model.linkAddress {
      ConnectQRCode(address: address.absoluteString, label: ConnectLinkModel.qrLabel)
      note(ConnectLinkModel.linkLive)
      if let instance = model.instanceNote {
        note(instance)
      }
      // Each as wide as its label at least, where an `HStack` would halve the row and break the
      // longer one; over each other where both do not fit.
      ViewThatFits(in: .horizontal) {
        EqualPaddingRow(spacing: 12) { changeButtons }
        VStack(spacing: 12) { changeButtons }
      }
      .controlSize(.large)
      failure
    } else {
      Text(ConnectLinkModel.linkNone)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let instance = model.instanceNote {
        note(instance)
      }
      Button {
        Task { await model.createLink() }
      } label: {
        Label(ConnectLinkModel.linkCreate, systemImage: "link")
          .frame(maxWidth: .infinity)
      }
      .brandProminentButton()
      .controlSize(.large)
      .disabled(model.isChangingLink)
      .needsServer()
      failure
    }
  }

  /// The scanner and the paste, and the answer to what they were given.
  @ViewBuilder private var others: some View {
    Text(ConnectLinkModel.othersTitle)
      .font(.headline)
    note(ConnectLinkModel.othersNote)
    if isScanning {
      QRCodeScanner { give($0) }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel(ConnectLinkModel.scannerLabel)
      Button(ConnectLinkModel.stopScanning) { isScanning = false }
        .accentRow()
    } else {
      // The Paste button keeps its own width, so beside it the scanner's label would break.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) { scanAndPaste }
        VStack(spacing: 12) { scanAndPaste }
      }
      .controlSize(.large)
    }
    if let scannerUnavailable {
      note(scannerUnavailable.reason)
    }
    if let answer {
      Text(answer.sentence)
        .multilineTextAlignment(.center)
      if case .flagship(let offer) = answer, signIn != nil {
        Button(FlagshipOffer.switchButton) {
          switching = offer
          dismiss()
        }
        .accentRow()
      }
      if let url = answer.browser {
        Button(GivenLinkAnswer.openInBrowser) { openURL(url) }
          .accentRow()
      }
    }
  }

  @ViewBuilder private var scanAndPaste: some View {
    Button {
      Task { await startScanning() }
    } label: {
      Label(ConnectLinkModel.scanButton, systemImage: "qrcode.viewfinder")
        .frame(maxWidth: .infinity)
    }
    .brandBorderedButton()
    // The system's control, which reads the pasteboard without asking.
    PasteButton(payloadType: String.self) { strings in
      give(strings.first ?? "")
    }
    .tint(Color.accentText)
  }

  private func startScanning() async {
    answer = nil
    scannerUnavailable = await QRCodeScanner.unavailable()
    isScanning = scannerUnavailable == nil
  }

  private func give(_ text: String) {
    isScanning = false
    guard let url = AppLink.url(given: text) else {
      answer = .notALink
      return
    }
    switch AppLinkRouter.action(for: url, from: .given, state: session.state) {
    case .open(let screen):
      answer = nil
      handedOver = screen
      dismiss()
    case .answer(let given):
      answer = given
    case .browser(let url):
      openURL(url)
    case .signIn(let token):
      dismiss()
      Task { await signIn?.redeemLink(token) }
    case .hold:
      // Only a link from outside is held.
      answer = .signInFirst
    case .offerFlagship(let offer):
      // Only a link from outside is asked about in an alert.
      answer = .flagship(offer)
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
  }

  @ViewBuilder private var failure: some View {
    if model.isChangingLink {
      BubbleSpinner()
    } else if let failure = model.linkFailure {
      FieldMessage(failure)
    }
  }

  @ViewBuilder private var changeButtons: some View {
    changeButton(.reset)
    changeButton(.remove)
  }

  private func changeButton(_ change: ConnectLinkModel.LinkChange) -> some View {
    let isRemoval = change == .remove
    return Button(role: isRemoval ? .destructive : nil) {
      model.askToConfirm(change)
    } label: {
      Label(
        isRemoval ? ConnectLinkModel.removeButton : ConnectLinkModel.resetButton,
        systemImage: isRemoval ? "trash" : "arrow.counterclockwise"
      )
      .frame(maxWidth: .infinity)
    }
    .brandBorderedButton(isRemoval ? .danger : .accentText)
    .disabled(model.isChangingLink)
    .needsServer()
    .confirmsConnectLinkChange(change, model: model)
  }
}

#Preview {
  Color.clear
    .sheet(isPresented: .constant(true)) { ConnectLinkSheet() }
    .environment(ScreenPresenter())
    .environment(
      Session.stub(
        transport: StubTransport(routes: [
          "GET user/connect-link": .json(
            #"{"token":"9f86d081884c7d659a2feaa0c55ad015","#
              + #""created_at":"2026-11-01T10:00:00Z"}"#)
        ])))
}
