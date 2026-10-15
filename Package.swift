// swift-tools-version:5.9
// This manifest exists so you can open the folder in Xcode / VS Code and get
// code completion. The actual .app bundle is produced by ./build.sh.
import PackageDescription

let package = Package(
    name: "Vidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Vidget",
            path: "Sources/Vidget",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
