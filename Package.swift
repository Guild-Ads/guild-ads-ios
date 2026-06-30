// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "GuildAdsSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "GuildAds",
            targets: ["GuildAds"]
        ),
    ],
    targets: [
        .target(
            name: "GuildAds",
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "GuildAdsTests",
            dependencies: ["GuildAds"]
        ),
    ]
)
