import SwiftData
import SwiftUI

@main
internal struct KakeiboApp: App {
    internal let modelContainer: ModelContainer

    internal init() {
        do {
            let container = try ModelContainer.createKakeiboContainer()
            modelContainer = container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    internal var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(\.appModelContainer, modelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(modelContainer)
    }
}
