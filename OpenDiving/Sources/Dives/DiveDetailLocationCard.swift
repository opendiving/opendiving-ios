import OpenDivingKit
import SwiftUI

/// Where the dive was: its trip and its dive centre, every site in the order visited, the
/// computer's entry and exit fixes with the drift between them, the entry and the boat.
/// The trip and each site push their own pages.
struct DiveDetailLocationCard: View {
  let location: DiveDetailContent.Location

  var body: some View {
    SectionCard(title: "Location", systemImage: "mappin") {
      VStack(alignment: .leading, spacing: 16) {
        if let trip = location.trip {
          LinkedBlock(label: "Trip") {
            NavigationLink {
              TripDetailView(tripUUID: trip.uuid)
            } label: {
              placeLabel(trip.name, detail: trip.locations, systemImage: "suitcase")
            }
          }
        }
        if let center = location.diveCenter {
          LinkedBlock(label: "Dive center") {
            placeLabel(center.name, detail: center.place, systemImage: "building.2")
            if let phone = center.phone {
              if let url = center.phoneURL {
                Link(destination: url) { Label(phone, systemImage: "phone") }
              } else {
                Label(phone, systemImage: "phone")
              }
            }
            if let website = center.website {
              if let url = center.websiteURL {
                Link(destination: url) { Label(website, systemImage: "globe").lineLimit(1) }
              } else {
                Label(website, systemImage: "globe").lineLimit(1)
              }
            }
          }
        }
        if !location.sites.isEmpty {
          LinkedBlock(label: location.sitesLabel) {
            ForEach(location.sites) { site in
              NavigationLink {
                SiteDetailView(siteUUID: site.id)
              } label: {
                placeLabel(site.name, detail: site.location, systemImage: "mappin.and.ellipse")
              }
            }
          }
        }
        if let entry = location.entry {
          InfoRow(label: "Entry") { Text(entry).monospacedDigit() }
        }
        if let exit = location.exit {
          InfoRow(label: "Exit") { Text(exit).monospacedDigit() }
        }
        if let drift = location.drift {
          InfoRow(label: "Entry → exit") { Text(drift).monospacedDigit() }
        }
        if let entryType = location.entryType {
          InfoRow(label: "Entry type") { Text(entryType) }
        }
        if let boatName = location.boatName {
          InfoRow(label: "Boat name") { Text(boatName) }
        }
      }
    }
  }

  /// A name over its place, led by an icon level with the name.
  private func placeLabel(_ name: String, detail: String?, systemImage: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: systemImage)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(name).fontWeight(.medium)
        if let detail {
          Text(detail).foregroundStyle(.secondary)
        }
      }
      .multilineTextAlignment(.leading)
    }
    .font(.subheadline)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }
}

/// ``InfoRow``'s label over content that holds links, which stay separate elements so each
/// can be reached and activated on its own.
private struct LinkedBlock<Content: View>: View {
  let label: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      content
        .font(.subheadline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  NavigationStack {
    ScrollView {
      if let location = DivePreviewData.content.location {
        DiveDetailLocationCard(location: location)
          .padding()
      }
    }
    .background(Color(.systemGroupedBackground))
  }
}
