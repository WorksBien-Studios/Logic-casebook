// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LogicCasebook",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "LogicCasebookEngine", targets: ["LogicCasebookEngine"]),
        .library(name: "LogicCasebookContent", targets: ["LogicCasebookContent"]),
        .library(name: "LogicCasebookUI", targets: ["LogicCasebookUI"]),
    ],
    dependencies: [
        // The iOS 18 app shell (tab bar / sidebar, per-tab NavigationStack,
        // search-role tab, TipKit setup). Pinned to a commit so builds are
        // reproducible.
        .package(
            url: "https://github.com/lrodeveloperr/ios-18-shell",
            revision: "c082e90f9fc92970ef127792dfba2dd9cdffd710"
        ),
    ],
    targets: [
        // Pure-Swift domain engine: content model, solver, hint and solution
        // checking. No UI dependency, matches the locked spec's architecture
        // (docs/logic-casebook-locked-process-flow.md, section 5).
        .target(
            name: "LogicCasebookEngine",
            path: "Sources/LogicCasebookEngine"
        ),
        // Bundles the canonical 1,000-case content bundle and decodes it.
        // Kept as its own target so both the app and the test suite load
        // the exact same resource without duplicating it in two places.
        .target(
            name: "LogicCasebookContent",
            dependencies: ["LogicCasebookEngine"],
            path: "Sources/LogicCasebookContent",
            resources: [.copy("Resources/cases.v1.json")]
        ),
        // SwiftUI presentation layer: tutorial, case library, search, help,
        // briefing, logic workspace, completion and purchase screens.
        .target(
            name: "LogicCasebookUI",
            dependencies: [
                "LogicCasebookEngine",
                "LogicCasebookContent",
                .product(name: "iOS18Shell", package: "ios-18-shell"),
            ],
            path: "Sources/LogicCasebookUI"
        ),
        .testTarget(
            name: "LogicCasebookEngineTests",
            dependencies: ["LogicCasebookEngine", "LogicCasebookContent"],
            path: "Tests/LogicCasebookEngineTests"
        ),
        // Exercises EntitlementStore's StoreKit 2 purchase/restore flow
        // against a local StoreKit Testing configuration (StoreKitTest /
        // SKTestSession) -- the supported, CI-runnable substitute for a real
        // App Store sandbox account, which this environment has no way to
        // authenticate against.
        .testTarget(
            name: "LogicCasebookUITests",
            dependencies: ["LogicCasebookUI"],
            path: "Tests/LogicCasebookUITests",
            resources: [.copy("Resources/Configuration.storekit")]
        ),
    ]
)
