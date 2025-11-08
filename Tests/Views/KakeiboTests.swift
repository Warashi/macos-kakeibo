@testable import Kakeibo
import SwiftData
import SwiftUI
import Testing

@Suite("Kakeibo Tests")
internal struct KakeiboTests {
    @Test("ContentView can be initialized")
    internal func contentViewInitialization() {
        let view = ContentView()
        // ViewがSwiftUIのView protocolに準拠していることを確認
        let _: any View = view
    }

    @Test("RootView can be initialized with AppState")
    internal func rootViewInitialization() {
        let state = AppState()
        let view = RootView(appState: state)
        let _: any View = view
    }

    @Test("SidebarView can be initialized with AppState")
    internal func sidebarViewInitialization() {
        let state = AppState()
        let view = SidebarView(appState: state)
        let _: any View = view
    }

    @Test("CSVImportView can be initialized")
    internal func csvImportViewInitialization() {
        let view = CSVImportView()
        let _: any View = view

    @Test("SettingsView can be initialized with ModelContext")
    internal func settingsViewInitialization() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let view = SettingsView(modelContext: context)
        let _: any View = view
    }
}
