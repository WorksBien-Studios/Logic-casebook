import SwiftUI
import LogicCasebookUI

@main
struct LogicCasebookApp: App {
    let modelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
