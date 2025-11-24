import SwiftData
import SwiftUI

@main
internal struct KakeiboApp: App {
    internal let modelContainer: ModelContainer
    internal let storeFactory: StoreFactory

    internal init() {
        do {
            let container = try ModelContainer.createKakeiboContainer()
            modelContainer = container
            storeFactory = SwiftDataStoreFactory(modelContainer: container)
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
