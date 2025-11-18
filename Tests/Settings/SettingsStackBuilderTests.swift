import Foundation
import SwiftData
@testable import Kakeibo
import Testing

@Suite(.serialized)
@MainActor
internal struct SettingsStackBuilderTests {
    @Test("SettingsStore を構築して統計を初期化できる")
    func makeSettingsStoreInitializesStatistics() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let store = await SettingsStackBuilder.makeSettingsStore(modelContainer: container)

        let stats = await MainActor.run { store.statistics }
        #expect(stats == .empty)
    }

    @Test("ImportStore を構築して初期ステップを保持する")
    func makeImportStoreInitializesState() async throws {
        let container = try ModelContainer.createInMemoryContainer()
        let store = await SettingsStackBuilder.makeImportStore(modelContainer: container)

        let step = await MainActor.run { store.step }
        #expect(step == .fileSelection)
    }
}
