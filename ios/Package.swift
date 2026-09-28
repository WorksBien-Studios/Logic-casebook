// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LogicCasebook",
    defaultLocalization: "ja",
    platforms: [
        .iOS(.v18),
        // Not a shipping target — declared so `swift test` can run the
        // engine's test suite directly on a macOS CI runner (fast, no
        // simulator boot) before the slower `xcodebuild` iOS Simulator
        // pass. Every framework the App target touches (SwiftUI, SwiftData,
        // StoreKit, Observation, and iOS18Shell itself) already supports
        // macOS 15, so this costs nothing.
        .macOS(.v15)
    ],
    products: [
        .library(name: "LogicCasebookEngine", targets: ["LogicCasebookEngine"]),
        .library(name: "LogicCasebookApp", targets: ["LogicCasebookApp"])
    ],
    dependencies: [
        // Navigation/tab-bar chrome, SwiftData container helper and loading/empty/error
        // state view. Pinned to a specific revision (the repo has no tags yet) so the
        // app doesn't move underneath CI when the shell repo changes.
        .package(url: "https://github.com/lrodeveloperr/ios-18-shell", revision: "c082e90f9fc92970ef127792dfba2dd9cdffd710")
    ],
    targets: [
        // Pure domain engine: case models, the exhaustive constraint solver, grid/undo
        // state, hint derivation and bundle integrity checks. No SwiftUI, no UIKit —
        // only Foundation — so it stays testable and reusable independent of any UI.
        .target(
            name: "LogicCasebookEngine",
            resources: [
                .copy("Resources/CaseBundle")
            ]
        ),
        .target(
            name: "LogicCasebookApp",
            dependencies: [
                "LogicCasebookEngine",
                .product(name: "iOS18Shell", package: "ios-18-shell")
            ]
        ),
        .testTarget(
            name: "LogicCasebookEngineTests",
            dependencies: ["LogicCasebookEngine"]
        )
    ]
)
