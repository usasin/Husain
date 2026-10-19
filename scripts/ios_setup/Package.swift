// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "prono4_ios_setup",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", exact: "8.27.7"),
        // AEXML 4.7.3 raises its minimum OS above XcodeProj 8.27.7's declaration.
        .package(url: "https://github.com/tadija/AEXML.git", exact: "4.7.0"),
    ],
    targets: [
        .executableTarget(name: "prono4_ios_setup", dependencies: ["XcodeProj"], path: "Sources"),
    ]
)
