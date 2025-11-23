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
        let transactionRepository = await makeTransactionRepository { repository in
            repository.transactionCount = 1
        }
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
        )

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
        let transactionRepository = await makeTransactionRepository { repository in
            repository.transactionCount = 1
        }
        let budgetRepository = await makeBudgetRepository { repository in
            repository.budgetCount = 1
            repository.annualBudgetConfigCount = 1
            repository.categoryCount = 1
            repository.institutionCount = 1
        }
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )

        // When
        try await store.deleteAllData()

        // Then
        let deleteCalls = (
            transactionRepository.deleteAllTransactionsCallCount,
            budgetRepository.deleteAllBudgetsCallCount,
            budgetRepository.deleteAllConfigsCallCount,
            budgetRepository.deleteAllCategoriesCallCount,
            budgetRepository.deleteAllInstitutionsCallCount,
        )
        #expect(deleteCalls.0 == 1)
        #expect(deleteCalls.1 == 1)
        #expect(deleteCalls.2 == 1)
        #expect(deleteCalls.3 == 1)
        #expect(deleteCalls.4 == 1)
        #expect(store.statistics.totalRecords == 0)
        #expect(store.statusMessage?.contains("削除") == true)
    }

    @Test("refreshStatisticsで最新の件数が反映される")
    internal func refreshStatisticsRecalculatesCounts() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "refresh")
        let container = try ModelContainer.createInMemoryContainer()
        let transactionRepository = await makeTransactionRepository()
        let budgetRepository = await makeBudgetRepository()
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
        #expect(store.statistics == .empty)

        transactionRepository.transactionCount = 2
        budgetRepository.budgetCount = 3
        budgetRepository.annualBudgetConfigCount = 1
        budgetRepository.categoryCount = 4
        budgetRepository.institutionCount = 2

        // When
        await store.refreshStatistics()

        // Then
        #expect(store.statistics.transactions == 2)
        #expect(store.statistics.categories == 4)
        #expect(store.statistics.budgets == 3)
        #expect(store.statistics.annualBudgetConfigs == 1)
        #expect(store.statistics.financialInstitutions == 2)
        #expect(store.statistics.totalRecords == 12)
    }

    @Test("CSVエクスポート結果に取引が含まれる")
    internal func exportTransactionsCSVIncludesRows() async throws {
        // Given
        let defaults = makeUserDefaults(suffix: "csv")
        let container = try ModelContainer.createInMemoryContainer()
        let major = SwiftDataCategory(name: "食費")
        let minor = SwiftDataCategory(name: "外食", parent: major)
        let institution = SwiftDataFinancialInstitution(name: "銀行")
        let transaction = SwiftDataTransaction(
            date: Date(),
            title: "テスト",
            amount: -1000,
            financialInstitution: institution,
            majorCategory: major,
            minorCategory: minor,
        )
        let transactionModel = Transaction(from: transaction)
        let categoryModels = [Category(from: major), Category(from: minor)]
        let institutionModel = FinancialInstitution(from: institution)
        let transactionRepository = await makeTransactionRepository { repository in
            repository.snapshotTransactions = [transactionModel]
            repository.snapshotCategories = categoryModels
            repository.snapshotInstitutions = [institutionModel]
            repository.transactionCount = 1
        }
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
        )

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
        let backupManager = BackupManager(
            backupRepository: SwiftDataBackupRepository(modelContainer: sourceContainer)
        )
        let payload = try await backupManager.buildPayload()
        let archive = try await backupManager.createBackup(payload: payload)

        let defaults = makeUserDefaults(suffix: "restore")
        let targetContainer = try ModelContainer.createInMemoryContainer()
        let targetContext = ModelContext(targetContainer)
        let transactionRepository = await makeTransactionRepository { repository in
            repository.transactionCount = 1
        }
        let store = await makeSettingsStore(
            modelContainer: targetContainer,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
        )

        #expect(try targetContext.count(SwiftDataTransaction.self) == 0)

        // When
        let summary = try await store.restoreBackup(from: archive.data)

        // Then
        #expect(summary.metadata.recordCounts.transactions == 1)
        #expect(store.lastRestoreSummary?.metadata.recordCounts.transactions == 1)
        #expect(store.lastBackupMetadata?.generatedAt == summary.metadata.generatedAt)
        #expect(store.statistics.transactions == 1)
        #expect(store.statusMessage?.contains("復元") == true)
        #expect(try targetContext.count(SwiftDataTransaction.self) == 1)
        #expect(store.isProcessingBackup == false)
    }

    @Test("refreshStatisticsはバックグラウンドTaskからでも統計を更新する")
    internal func refreshStatistics_updatesCountsFromDetachedTask() async throws {
        let defaults = makeUserDefaults(suffix: "stats-detached")
        let container = try ModelContainer.createInMemoryContainer()
        let transactionRepository = await makeTransactionRepository { repository in
            repository.transactionCount = 5
        }
        let budgetRepository = await makeBudgetRepository { repository in
            repository.budgetCount = 3
            repository.annualBudgetConfigCount = 1
            repository.categoryCount = 4
            repository.institutionCount = 2
        }
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )

        let backgroundTask = Task.detached {
            await store.refreshStatistics()
        }
        await backgroundTask.value

        #expect(store.statistics.transactions == 5)
        #expect(store.statistics.budgets == 3)
        #expect(store.statistics.annualBudgetConfigs == 1)
        #expect(store.statistics.categories == 4)
        #expect(store.statistics.financialInstitutions == 2)
        #expect(store.statistics.totalRecords == 15)
    }
}

// MARK: - Helpers

@MainActor
private func seedTransaction(in context: ModelContext) throws {
    let category = SwiftDataCategory(name: "食費")
    let institution = SwiftDataFinancialInstitution(name: "銀行")
    let transaction = SwiftDataTransaction(
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
    userDefaults: UserDefaults,
    transactionRepository: MockTransactionRepository? = nil,
    budgetRepository: MockBudgetRepository? = nil,
) async -> SettingsStore {
    let resolvedTransactionRepository: MockTransactionRepository = if let transactionRepository {
        transactionRepository
    } else {
        await makeTransactionRepository()
    }
    let resolvedBudgetRepository: MockBudgetRepository = if let budgetRepository {
        budgetRepository
    } else {
        await makeBudgetRepository()
    }
    return await SettingsStore(
        modelContainer: modelContainer,
        userDefaults: userDefaults,
        transactionRepository: resolvedTransactionRepository,
        budgetRepository: resolvedBudgetRepository,
    )
}

@MainActor
private func makeTransactionRepository(
    configure: ((MockTransactionRepository) -> Void)? = nil,
) async -> MockTransactionRepository {
    let repository = MockTransactionRepository()
    configure?(repository)
    return repository
}

@MainActor
private func makeBudgetRepository(
    configure: ((MockBudgetRepository) -> Void)? = nil,
) async -> MockBudgetRepository {
    let repository = MockBudgetRepository()
    configure?(repository)
    return repository
}

private final class MockTransactionRepository: TransactionRepository {
    internal var transactionCount: Int = 0
    internal var snapshotTransactions: [Transaction] = []
    internal var snapshotCategories: [Kakeibo.Category] = []
    internal var snapshotInstitutions: [FinancialInstitution] = []
    internal private(set) var deleteAllTransactionsCallCount: Int = 0

    internal func fetchTransactions(query: TransactionQuery) async throws -> [Transaction] {
        unsupported(#function)
    }

    internal func fetchAllTransactions() async throws -> [Transaction] {
        snapshotTransactions
    }

    internal func fetchCSVExportSnapshot() async throws -> TransactionCSVExportSnapshot {
        TransactionCSVExportSnapshot(
            transactions: snapshotTransactions,
            categories: snapshotCategories,
            institutions: snapshotInstitutions,
        )
    }

    internal func countTransactions() async throws -> Int {
        transactionCount
    }

    internal func fetchInstitutions() async throws -> [FinancialInstitution] {
        snapshotInstitutions
    }

    internal func fetchCategories() async throws -> [Kakeibo.Category] {
        snapshotCategories
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @Sendable ([Transaction]) -> Void,
    ) async throws -> ObservationHandle {
        unsupported(#function)
    }

    internal func findTransaction(id: UUID) async throws -> Transaction? {
        unsupported(#function)
    }

    internal func findByIdentifier(_ identifier: String) async throws -> Transaction? {
        unsupported(#function)
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) async throws -> UUID {
        unsupported(#function)
    }

    internal func update(_ input: TransactionUpdateInput) async throws {
        unsupported(#function)
    }

    internal func deleteAllTransactions() async throws {
        deleteAllTransactionsCallCount += 1
        transactionCount = 0
    }

    internal func delete(id: UUID) async throws {
        unsupported(#function)
    }

    internal func saveChanges() async throws {}
}

private final class MockBudgetRepository: BudgetRepository {
    internal var budgetCount: Int = 0
    internal var annualBudgetConfigCount: Int = 0
    internal var categoryCount: Int = 0
    internal var institutionCount: Int = 0

    internal private(set) var deleteAllBudgetsCallCount: Int = 0
    internal private(set) var deleteAllConfigsCallCount: Int = 0
    internal private(set) var deleteAllCategoriesCallCount: Int = 0
    internal private(set) var deleteAllInstitutionsCallCount: Int = 0

    internal func fetchSnapshot(for year: Int) async throws -> BudgetSnapshot {
        unsupported(#function)
    }

    internal func category(id: UUID) async throws -> Kakeibo.Category? {
        unsupported(#function)
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) async throws -> Kakeibo.Category? {
        unsupported(#function)
    }

    internal func createCategory(name: String, parentId: UUID?) async throws -> UUID {
        unsupported(#function)
    }

    internal func countCategories() async throws -> Int {
        categoryCount
    }

    internal func findInstitutionByName(_ name: String) async throws -> FinancialInstitution? {
        unsupported(#function)
    }

    internal func createInstitution(name: String) async throws -> UUID {
        unsupported(#function)
    }

    internal func countFinancialInstitutions() async throws -> Int {
        institutionCount
    }

    internal func annualBudgetConfig(for year: Int) async throws -> AnnualBudgetConfig? {
        nil
    }

    internal func countAnnualBudgetConfigs() async throws -> Int {
        annualBudgetConfigCount
    }

    internal func addBudget(_ input: BudgetInput) async throws {
        unsupported(#function)
    }

    internal func updateBudget(input: BudgetUpdateInput) async throws {
        unsupported(#function)
    }

    internal func deleteBudget(id: UUID) async throws {
        unsupported(#function)
    }

    internal func deleteAllBudgets() async throws {
        deleteAllBudgetsCallCount += 1
        budgetCount = 0
    }

    internal func deleteAllAnnualBudgetConfigs() async throws {
        deleteAllConfigsCallCount += 1
        annualBudgetConfigCount = 0
    }

    internal func deleteAllCategories() async throws {
        deleteAllCategoriesCallCount += 1
        categoryCount = 0
    }

    internal func deleteAllFinancialInstitutions() async throws {
        deleteAllInstitutionsCallCount += 1
        institutionCount = 0
    }

    internal func countBudgets() async throws -> Int {
        budgetCount
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) async throws {
        unsupported(#function)
    }

    internal func saveChanges() async throws {}
}

private func unsupported(_ function: StaticString) -> Never {
    preconditionFailure("\(function) is not supported in this context")
}
