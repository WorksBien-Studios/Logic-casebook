import SwiftUI
import iOS18Shell

/// The app's whole scene: first-launch tutorial gate (spec §4.1 — no
/// account request, tracking prompt, paywall or marketing screen may
/// precede it), then the `iOS18Shell`-driven tab shell. Library and Help
/// are the only two tabs the locked spec calls for; Help carries the
/// tutorial-replay entry point §4.1 requires.
public struct CasebookRootView: View {
    @AppStorage("com.logiccasebook.hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var purchaseStore = PurchaseStore()
    @StateObject private var navigator = AppShellNavigator()

    public init() {
        // UI tests launch with this argument to reach the library directly,
        // rather than re-driving the tutorial's paging in every test.
        if ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_TUTORIAL") {
            UserDefaults.standard.set(true, forKey: "com.logiccasebook.hasCompletedTutorial")
        }
    }

    public var body: some View {
        Group {
            if hasCompletedTutorial {
                AppShellView(tabIDs: ["library", "help"], navigator: navigator) {
                    appShellTab(AppTab(id: "library", title: "事件簿", systemImage: "books.vertical", role: .search) {
                        CaseLibraryView()
                    }, navigator: navigator)
                    appShellTab(AppTab(id: "help", title: "ヘルプ", systemImage: "questionmark.circle") {
                        HelpView()
                    }, navigator: navigator)
                }
                .accessibilityIdentifier("casebook.library.shell")
            } else {
                TutorialView { hasCompletedTutorial = true }
            }
        }
        .environment(purchaseStore)
    }
}

private struct HelpView: View {
    @State private var showTutorial = false
    var body: some View {
        List {
            Button("チュートリアルをもう一度見る") { showTutorial = true }
        }
        .navigationTitle("ヘルプ")
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(isPresentedFromHelp: true) { showTutorial = false }
        }
    }
}
