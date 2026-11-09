import Foundation

/// How a site is marked wherever it is listed or drawn: a Commons record, a site of the diver's
/// own proposed to the Commons and waiting for review, or one that is the diver's alone.
///
/// Ordered by precedence: a group of sites on the map takes the mark of its highest.
public enum DiveSiteMark: Int, Comparable, Hashable, Sendable, CaseIterable {
  case `private` = 0
  case proposed = 1
  case commons = 2

  public init(owner: String, proposalStatus: String?) {
    if owner == DiveSiteOwner.commons {
      self = .commons
    } else if proposalStatus == DiveSiteProposalStatus.waiting {
      self = .proposed
    } else {
      self = .private
    }
  }

  public static func < (lhs: DiveSiteMark, rhs: DiveSiteMark) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  /// The word beside a site's name.
  public var label: String {
    switch self {
    case .commons: DiveSiteSummary.commonsLabel
    case .proposed: "Proposed"
    case .private: "Private"
    }
  }

  public var accessibilityLabel: String {
    switch self {
    case .commons: "OpenDiving Commons site"
    case .proposed: "Proposed to OpenDiving Commons"
    case .private: "Private site"
    }
  }

  /// The mark as a chip over a card's title.
  public var chip: Chip {
    Chip(text: label, accessibilityLabel: accessibilityLabel, kind: .site(self))
  }
}
