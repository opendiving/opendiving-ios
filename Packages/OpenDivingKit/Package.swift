// swift-tools-version: 6.2
// 6.2 rather than the newest toolchain's own: see DECISIONS.md, "The Kit's tools version is 6.2".

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .defaultIsolation(nil),
  .treatAllWarnings(as: .error),
]

let package = Package(
  name: "OpenDivingKit",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "OpenDivingKit", targets: ["OpenDivingKit"])
  ],
  targets: [
    .target(
      name: "OpenDivingKit",
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "OpenDivingKitTests",
      dependencies: ["OpenDivingKit"],
      resources: [.copy("Fixtures")],
      swiftSettings: swiftSettings
    ),
  ]
)
