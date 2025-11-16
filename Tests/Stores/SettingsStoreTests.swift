import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite(.serialized)
@MainActor
internal struct SettingsStoreTests {
    @Test("UserDefaultsの値を初期値として読み込む")
    internal func initializationLoadsDefaults() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "initialization")
        defaults.set(false, forKey: "settings.includeOnlyCalculationTarget")
        defaults.set(false, forKey: "settings.excludeTransfers")
        defaults.set(true, forKey: "settings.showCategoryFullPath")
        defaults.set(false, forKey: "settings.useThousandSeparator")

        let container = try ModelContainer.createInMemoryContainer()

        // When
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)

        // Then
        #expect(store.includeOnlyCalculationTarget == false)
        #expect(store.excludeTransfers == false)
        #expect(store.showCategoryFullPath == true)
        #expect(store.useThousandSeparator == false)
    }

    @Test("設定変更がUserDefaultsに保存される")
    internal func updatingSettingsPersists() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "persist")
        let container = try ModelContainer.createInMemoryContainer()
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)

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
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)

        // When
        let archive = try await store.createBackupArchive()

        // Then
        #expect(!archive.data.isEmpty)
        #expect(store.lastBackupMetadata != nil)
        #expect(store.statistics.transactions == 1)
    }

    @Test("全データ削除でModelContextが空になる")
    internal func deleteAllDataClearsContext() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "delete")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        try seedTransaction(in: context)
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)

        // When
        try await store.deleteAllData()

        // Then
        #expect(try context.count(Transaction.self) == 0)
        #expect(store.statistics.totalRecords == 0)
        #expect(store.statusMessage?.contains("削除") == true)
    }

    @Test("refreshStatisticsで最新の件数が反映される")
    internal func refreshStatisticsRecalculatesCounts() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "refresh")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)
        #expect(store.statistics == .empty)

        try seedTransaction(in: context)

        // When
        await store.refreshStatistics()

        // Then
        #expect(store.statistics.transactions == 1)
        #expect(store.statistics.totalRecords == 3)
    }

    @Test("CSVエクスポート結果に取引が含まれる")
    internal func exportTransactionsCSVIncludesRows() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "csv")
        let container = try ModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        try seedTransaction(in: context)
        let store = await makeSettingsStore(modelContainer: container, userDefaults: defaults)

        // When
        let result = try await store.exportTransactionsCSV()

        // Then
        #expect(result.rowCount == 1)
        #expect(result.header.contains("title"))
        #expect(result.string.contains("テスト"))
    }

    @Test("バックアップからの復元後に状態が更新される")
    internal func restoreBackupUpdatesState() async throws {
        // Given
        let sourceContainer = try ModelContainer.createInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        try seedTransaction(in: sourceContext)
        let backupManager = BackupManager(modelContainer: sourceContainer)
        let payload = try await backupManager.buildPayload()
        let archive = try await backupManager.createBackup(payload: payload)

        let defaults = makeUserDefaults(suffix: "restore")
        let targetContainer = try ModelContainer.createInMemoryContainer()
        let targetContext = ModelContext(targetContainer)
        let store = await makeSettingsStore(modelContainer: targetContainer, userDefaults: defaults)

        #expect(try targetContext.count(Transaction.self) == 0)

        // When
        let summary = try await store.restoreBackup(from: archive.data)

        // Then
        #expect(summary.metadata.recordCounts.transactions == 1)
        #expect(store.lastRestoreSummary?.metadata.recordCounts.transactions == 1)
        #expect(store.lastBackupMetadata?.generatedAt == summary.metadata.generatedAt)
        #expect(store.statistics.transactions == 1)
        #expect(store.statusMessage?.contains("復元") == true)
        #expect(try targetContext.count(Transaction.self) == 1)
        #expect(store.isProcessingBackup == false)
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
        majorCategory: category,
    )
    context.insert(category)
    context.insert(institution)
    context.insert(transaction)
    try context.save()
}

private func makeUserDefaults(suffix: String) -> UserDefaults {
    let suiteName = "SettingsStoreTests.\(suffix)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("Failed to create UserDefaults for test suite: \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func makeSettingsStore(
    modelContainer: ModelContainer,
    userDefaults: UserDefaults
) async -> SettingsStore {
    let repositories = await makeSettingsStoreRepositories(modelContainer: modelContainer)
    return await SettingsStore(
        modelContainer: modelContainer,
        userDefaults: userDefaults,
        transactionRepository: repositories.transaction,
        budgetRepository: repositories.budget
    )
}

private func makeSettingsStoreRepositories(
    modelContainer: ModelContainer
) async -> (transaction: TransactionRepository, budget: BudgetRepository) {
    await Task { @DatabaseActor () -> (TransactionRepository, BudgetRepository) in
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: modelContainer)
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: modelContainer)
        return (transactionRepository, budgetRepository)
    }.value
}
