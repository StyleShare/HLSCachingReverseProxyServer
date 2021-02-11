// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "HLSCachingReverseProxyServer",
  platforms: [
    .macOS(.v10_11), .iOS(.v9), .tvOS(.v9)
  ],
  products: [
    .library(name: "HLSCachingReverseProxyServer", targets: ["HLSCachingReverseProxyServer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "9.0.0")),
    .package(url: "https://github.com/devxoul/SafeCollection.git", .upToNextMajor(from: "3.1.0")),
  ],
  targets: [
    .target(name: "HLSCachingReverseProxyServer"),
    .testTarget(name: "HLSCachingReverseProxyServerTests", dependencies: ["HLSCachingReverseProxyServer", "Nimble", "SafeCollection"]),
  ]
)
