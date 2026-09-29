import SwiftUI
import SwiftData
import iOS18Shell

/// App entry point. Gates the shell behind the first-launch tutorial, then
/// hands navigation to the iOS 18 shell: a tab bar on iPhone that becomes a
/// sidebar on iPad, one `NavigationStack` per tab, and the search-role tab.
public struct RootView: View {
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @StateObject private var entitlements = EntitlementStore()
    @StateObject private var navigator = AppShellNavigator()

    private static let tabIDs = ["library", "search", "help"]

    public init() {
        // One-time TipKit setup. Failure only means tips do not show.
        try? AppShellTips.configure()
    }

    private var libraryTab: AppTab {
        AppTab(id: "library", title: "事件簿", systemImage: "books.vertical") { CaseLibraryView() }
    }

    private var searchTab: AppTab {
        AppTab(id: "search", title: "検索", systemImage: "magnifyingglass", role: .search) { CaseSearchView() }
    }

    private var helpTab: AppTab {
        AppTab(id: "help", title: "ヘルプ", systemImage: "questionmark.circle") { HelpView() }
    }

    public var body: some View {
        Group {
            if hasCompletedTutorial {
                AppShellView(tabIDs: Self.tabIDs, navigator: navigator) {
                    appShellTab(libraryTab, navigator: navigator)
                    appShellTab(searchTab, navigator: navigator)
                    appShellTab(helpTab, navigator: navigator)
                }
            } else {
                TutorialView { hasCompletedTutorial = true }
            }
        }
        .tint(Theme.accent)
        .environmentObject(entitlements)
        .environment(\.caseNavigation, CaseNavigation(
            popToRoot: { navigator.popToRoot(navigator.selection) },
            open: { gameCase in
                navigator.popToRoot(navigator.selection)
                navigator.navigate(to: "library", pushing: gameCase)
            }
        ))
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
