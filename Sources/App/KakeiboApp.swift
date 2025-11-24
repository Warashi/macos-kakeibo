import SwiftData
import SwiftUI

@main
internal struct KakeiboApp: App {
    internal let modelContainer: ModelContainer
    internal let storeFactory: StoreFactory
    internal let appState: AppState

    internal init() {
        do {
            let container = try ModelContainer.createKakeiboContainer()
            modelContainer = container
            let state = AppState()
            appState = state
            storeFactory = SwiftDataStoreFactory(modelContainer: container, appState: state)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    internal var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(\.appModelContainer, modelContainer)
        .environment(\.storeFactory, storeFactory)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(modelContainer)
    }
}
