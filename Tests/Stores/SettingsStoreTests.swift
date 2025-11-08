@testable import Kakeibo
import Foundation
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct SettingsStoreTests {
    @Test("UserDefaultsの値を初期値として読み込む")
    internal func initializationLoadsDefaults() throws {
        // Given
        let defaults = makeUserDefaults(suffix: "initialization")
        defaults.set(false, forKey: "settings.includeOnlyCalculationTarget")
        defaults.set(false, forKey: "settings.excludeTransfers")
        defaults.set(true, forKey: "settings.showCategoryFullPath")
        defaults.set(false, forKey: "settings.useThousandSeparator")

        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)

        // When
        let store = SettingsStore(modelContext: context, userDefaults: defaults)

        // Then
        #expect(store.includeOnlyCalculationTarget == false)
        #expect(store.excludeTransfers == false)
        #expect(store.showCategoryFullPath == true)
        #expect(store.useThousandSeparator == false)
    }

    @Test("設定変更がUserDefaultsに保存される")
    internal func updatingSettingsPersists() throws {
        // Given
        let defaults = makeUserDefaults(suffix: "persist")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = SettingsStore(modelContext: context, userDefaults: defaults)

        // When
        store.includeOnlyCalculationTarget = false
        store.showCategoryFullPath = false

        // Then
        #expect(defaults.bool(forKey: "settings.includeOnlyCalculationTarget") == false)
        #expect(defaults.bool(forKey: "settings.showCategoryFullPath") == false)
    }

    @Test("バックアップ生成後にメタデータが更新される")
    internal func backupUpdatesMetadata() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "backup")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        try seedTransaction(in: context)
        let store = SettingsStore(modelContext: context, userDefaults: defaults)

        // When
        let archive = try await store.createBackupArchive()

        // Then
        #expect(!archive.data.isEmpty)
        #expect(store.lastBackupMetadata != nil)
        #expect(store.statistics.transactions == 1)
    }

    @Test("全データ削除でModelContextが空になる")
    internal func deleteAllDataClearsContext() throws {
        // Given
        let defaults = makeUserDefaults(suffix: "delete")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        try seedTransaction(in: context)
        let store = SettingsStore(modelContext: context, userDefaults: defaults)

        // When
        try store.deleteAllData()

        // Then
        #expect(try context.count(Transaction.self) == 0)
        #expect(store.statistics.totalRecords == 0)
        #expect(store.statusMessage?.contains("削除") == true)
    }
}

// MARK: - Helpers

@MainActor
private func seedTransaction(in context: ModelContext) throws {
    let category = Category(name: "食費")
    let institution = FinancialInstitution(name: "銀行")
    let transaction = Transaction(
        date: Date(),
        title: "テスト",
        amount: -1000,
        financialInstitution: institution,
        majorCategory: category
    )
    context.insert(category)
    context.insert(institution)
    context.insert(transaction)
    try context.save()
}

private func makeUserDefaults(suffix: String) -> UserDefaults {
    let suiteName = "SettingsStoreTests.\(suffix)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
