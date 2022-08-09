// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "FNZombie",
  platforms: [
    .iOS(.v12),
  ],
  products: [
    .library(
      name: "FNZombie",
      type: .static,
      targets: ["FNZombie"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "FNZombie",
      dependencies: [
        "swift_shims",
      ],
      path: "Sources/FNZombie",
      cSettings: [
        .headerSearchPath("include"),
        .unsafeFlags(["-fno-objc-arc"])
      ]
    ),
    .target(
      name: "swift_shims",
      path: "Sources/swift_shims"
    )
  ]
)
