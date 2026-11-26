import OpenDivingKit
import SwiftUI

/// What the profile shows, kept by the map it is pushed from: each visit after the first opens on
/// the head, the section and the lists as the last one left them, read again behind them, rather
/// than on an empty page that loads.
@MainActor
@Observable
final class ProfilePage {
  let avatar: AvatarModel
  let model: ProfileModel
  let dives: PagedList<DiveListItem>
  let numbering: DiveNumberingModel
  let trips: PagedList<TripRead>
  let checkin: CheckinSheetModel
  let pictures = PictureCache()
  var section = ProfileSection.dives

  init(session: Session, avatar: AvatarModel) {
    self.avatar = avatar
    model = ProfileModel(session: session)
    dives = ProfileDives.list(session)
    numbering = DiveNumberingModel(session: session)
    trips = ProfileTrips.list(session)
    checkin = CheckinSheetModel(session: session)
  }
}
