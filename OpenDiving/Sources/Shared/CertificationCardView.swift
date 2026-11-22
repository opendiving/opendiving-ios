import OpenDivingKit
import SwiftUI
import UIKit

/// One certification as a card, on More's *Certifications* and on a course's: its front behind the
/// details, in the card's shape so the front shows whole, or the water and an icon where there is
/// no picture to show — none stored, a PDF, or one that could not be had. Nothing while the
/// picture is on its way, so a card that has one does not flash an icon first.
struct CertificationCardView: View {
  let certificationUUID: UUID
  let content: CertificationCardContent

  @Environment(Session.self) private var session
  @State private var front: UIImage?
  @State private var loading = true

  var body: some View {
    Color.clear
      .aspectRatio(CertificationCardCrop.aspect, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .background { backdrop }
      .overlay(alignment: .bottom) { details }
      .background(Color(.systemBackground))
      .clipShape(.formSection)
      .accessibilityElement(children: .combine)
      .task(id: content.front) { await load() }
  }

  @ViewBuilder private var backdrop: some View {
    if let front {
      Image(uiImage: front)
        .resizable()
        .scaledToFill()
        .accessibilityHidden(true)
    } else if !loading {
      UnplacedBackdropView(icon: content.missingFrontIcon, coveredBottom: 100)
    }
  }

  /// One line: a long level gives up its tail before the expiry gives up a letter. The agency
  /// can truncate too, since an agency outside the vocabulary is the diver's free text.
  private var details: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(content.name)
        .font(.headline)
        .lineLimit(1)
      if let badge = content.badge {
        BadgeView(badge).fixedSize()
      }
      Spacer(minLength: 6)
      if let agency = content.agency {
        BadgeView(agency, style: .outline)
      }
    }
    .shadow(color: Color(.systemBackground).opacity(0.6), radius: 3)
    .padding(CardBackdropFrame.glassPadding)
    .background { GlassCard(shape: .formSection(inset: CardBackdropFrame.glassInset)) }
    .padding(CardBackdropFrame.glassInset)
  }

  private func load() async {
    guard let file = content.front else {
      front = nil
      loading = false
      return
    }
    loading = true
    let bytes = await CertificationCardImages.bytes(
      of: certificationUUID, file, session: session)
    front = bytes.flatMap(UIImage.init(data:))
    loading = false
  }
}

#Preview {
  let certification = try! APICoding.decoder().decode(
    CertificationRead.self,
    from: Data(
      """
      {"uuid": "01a0b07a-206e-76bd-bc56-e9646791ba20", "agency": "sdi", "agency_other": null,
       "name": "Solo Diver", "certification_number": "0000000", "certified_on": "2025-09-25",
       "expires_on": null, "instructor_number": null, "notes": "",
       "user_uuid": "01a0a51f-afe3-7363-a0bc-b0d634c35923", "course_uuid": null,
       "contact_uuid": null, "instructor_uuid": null, "files": [],
       "created_at": "2026-09-17T17:46:28.846182Z"}
      """.utf8))
  CertificationCardView(
    certificationUUID: certification.uuid,
    content: CertificationCardContent(certification, today: CalendarDate.today())
  )
  .padding()
  .environment(Session.stub(transport: StubTransport(routes: [:])))
}
