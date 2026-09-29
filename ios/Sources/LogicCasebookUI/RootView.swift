import SwiftUI
import SwiftData

/// App entry point. Wires up SwiftData (local-only progress, per the locked
/// spec's "no account, no server dependency") and the StoreKit entitlement
/// store, and gates the case library behind the first-launch tutorial.
public struct RootView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @StateObject private var entitlements = EntitlementStore()

    public init() {}

    public var body: some View {
        Group {
            if hasCompletedTutorial {
                CaseLibraryView()
            } else {
                TutorialView { hasCompletedTutorial = true }
            }
        }
        .environmentObject(entitlements)
        .task { await entitlements.start() }
    }
}

/// The SwiftData schema for the app: currently just per-case progress.
public enum AppModelContainer {
    public static func make() -> ModelContainer {
        do {
            return try ModelContainer(for: CaseProgress.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }
}
