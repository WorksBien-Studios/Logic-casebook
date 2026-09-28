import SwiftUI
import SwiftData
import LogicCasebookApp

/// The thin app-target entry point. Everything else — screens, view models,
/// persistence, StoreKit — lives in the `LogicCasebookApp` Swift package
/// library target so it stays testable and reusable; this file only wires
/// the package's root view into a `WindowGroup`, mirroring how
/// `ios-18-shell`'s own `Examples/ShellExampleApp.swift` wires that
/// package's `AppShellView` into its example app.
@main
struct LogicCasebookiOSApp: App {
    private let container: Result<ModelContainer, Error> = Result { try CasebookModelContainer.make() }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let modelContainer):
                CasebookRootView()
                    .modelContainer(modelContainer)
            case .failure:
                ContentUnavailableView(
                    "データを利用できません",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("アプリを再起動しても解決しない場合は、サポートにお問い合わせください。")
                )
            }
        }
    }
}
