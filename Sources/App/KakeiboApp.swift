import SwiftUI
import SwiftData

@main
struct KakeiboApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer.createKakeiboContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .modelContainer(modelContainer)
    }
}
