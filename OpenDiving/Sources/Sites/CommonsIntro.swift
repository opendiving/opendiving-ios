import OpenDivingKit
import SwiftUI

/// What OpenDiving Commons is and how a site is proposed to it: *Your Proposals* to a diver who
/// has proposed nothing yet, and behind its *i* once they have.
struct CommonsIntro: View {
  static let lead =
    "OpenDiving Commons is the open map of dive sites that every diver here shares. Propose a "
    + "site of yours for it, or a correction to one already in it, and a reviewer decides."
  static let steps: [(icon: Icon, text: String)] = [
    (.diveSite, "Add a dive site, or edit one of yours, and choose Public under Visibility."),
    (.landmark, "Saving shows you what would be published. Send it, and it waits under Proposed."),
    (
      .clipboardCheck,
      "A reviewer accepts it, or declines it with a reason. Until then you can withdraw it."
    ),
    (.fileText, "To correct a Commons site on your list, edit it and choose Propose a change."),
  ]
  static let stepsTitle = "How to propose a site"
  static let addAction = "Add a dive site"
  static let emptyMessage =
    "Add a dive site with Public chosen to propose it for OpenDiving Commons."

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(Self.lead)
      Text(Self.stepsTitle)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      VStack(alignment: .leading, spacing: 12) {
        ForEach(Self.steps, id: \.text) { step in
          Label {
            Text(step.text)
          } icon: {
            Image(step.icon)
              .foregroundStyle(Color.accentText)
          }
        }
      }
      .font(.subheadline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The introduction as the whole page, under the mark, with the way to a new public site: on one
/// screen, scrolling only where the text size needs it.
struct CommonsIntroPage: View {
  let add: () -> Void

  var body: some View {
    ViewThatFits(in: .vertical) {
      content
      ScrollView { content }
    }
  }

  private var content: some View {
    VStack(spacing: 24) {
      CommonsWordmarkHeader()
      CommonsIntro()
      Button(CommonsIntro.addAction, systemImage: "plus", action: add)
        .brandProminentButton()
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

/// The introduction behind the page's *i*.
struct CommonsIntroSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          CommonsWordmarkHeader()
          CommonsIntro()
        }
        .padding()
      }
      .navigationTitle("About OpenDiving Commons")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(removing: .title)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

#Preview("Page") {
  CommonsIntroPage {}
}

#Preview("Sheet") {
  Text("Your Proposals")
    .sheet(isPresented: .constant(true)) { CommonsIntroSheet() }
}
