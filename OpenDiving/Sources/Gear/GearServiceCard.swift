import OpenDivingKit
import SwiftUI

/// A gear item's service schedules, with their status, and its service history, on the item's page.
struct GearServiceCard: View {
  let gearItem: GearItemRead

  var body: some View {
    SectionCard(title: "Service", icon: .wrench) {
      Text("Service is managed on the web.")
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  let json = #"""
    {"uuid":"01a20000-0000-7000-8000-0000000000b1","name":"Twinset","brand":"Faber",
    "type":"cylinder","notes":"","rented":false,"volume":12,"working_pressure":232,
    "material":"steel","user_uuid":"01a20000-0000-7000-8000-000000000099",
    "is_archived":false,"archived_at":null,"dive_count":42,"dive_time":137520,
    "created_at":"2026-01-02T10:00:00Z"}
    """#
  if let item = try? APICoding.decoder().decode(GearItemRead.self, from: Data(json.utf8)) {
    GearServiceCard(gearItem: item)
  }
}
