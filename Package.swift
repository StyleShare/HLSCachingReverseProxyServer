// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "HLSCachingReverseProxyServer",
  platforms: [
    .macOS(.v10_11), .iOS(.v8), .tvOS(.v9)
  ],
  products: [
    .library(name: "HLSCachingReverseProxyServer", targets: ["HLSCachingReverseProxyServer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/Quick/Nimble.git", .revision("50c3f82c3d23af1d6e710226015b3e94b5265f71")),
    .package(url: "https://github.com/devxoul/SafeCollection.git", .upToNextMajor(from: "3.1.0")),
  ],
  targets: [
    .target(name: "HLSCachingReverseProxyServer"),
    .testTarget(name: "HLSCachingReverseProxyServerTests", dependencies: ["HLSCachingReverseProxyServer", "Nimble", "SafeCollection"]),
  ]
)
