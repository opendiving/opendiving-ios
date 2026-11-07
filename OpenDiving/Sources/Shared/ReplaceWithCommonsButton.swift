import OpenDivingKit
import SwiftUI

/// *Replace with Commons site*, wherever a record is offered in a site's place.
struct ReplaceWithCommonsButton: View {
  let record: UUID
  let replacement: CommonsSiteReplacement
  let replace: () -> Void

  var body: some View {
    Button(action: replace) {
      if replacement.replacing == record {
        ProgressView()
      } else {
        Text(DiveSiteProposalSummary.replaceTitle)
      }
    }
    .buttonStyle(.bordered)
    .disabled(replacement.replacing != nil)
  }
}

extension View {
  /// Replacing deletes the diver's own site, so it is stated before it is done.
  func replaceWithCommonsConfirmation(
    siteName: String, target: Binding<DiveSiteCommonsMatch?>,
    replace: @escaping (DiveSiteCommonsMatch) -> Void
  ) -> some View {
    confirmationDialog(
      DiveSiteProposalSummary.replaceTitle,
      isPresented: Binding(
        get: { target.wrappedValue != nil }, set: { if !$0 { target.wrappedValue = nil } }),
      titleVisibility: .visible, presenting: target.wrappedValue
    ) { match in
      Button(DiveSiteProposalSummary.replaceTitle, role: .destructive) { replace(match) }
    } message: { match in
      Text(DiveSiteProposalSummary.replaceMessage(site: siteName, record: match.name))
    }
  }

  /// The sentence of a replace that failed.
  func replaceWithCommonsAlert(_ replacement: CommonsSiteReplacement) -> some View {
    alert(
      "The site could not be replaced",
      isPresented: Binding(
        get: { replacement.failure != nil }, set: { if !$0 { replacement.failure = nil } })
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(replacement.failure ?? "")
    }
  }
}

#Preview {
  ReplaceWithCommonsButton(
    record: UUID(),
    replacement: DiveSiteDetailModel(
      session: Session.stub(transport: StubTransport(routes: [:])), siteUUID: UUID()
    ).replacement
  ) {}
}
