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
            transactionRepository: transactionRepository
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
            budgetRepository: budgetRepository
        )

        // When
        try await store.deleteAllData()

        // Then
        let deleteCalls = await Task { @DatabaseActor () -> (
            Int,
            Int,
            Int,
            Int,
            Int
        ) in
            (
                transactionRepository.deleteAllTransactionsCallCount,
                budgetRepository.deleteAllBudgetsCallCount,
                budgetRepository.deleteAllConfigsCallCount,
                budgetRepository.deleteAllCategoriesCallCount,
                budgetRepository.deleteAllInstitutionsCallCount
            )
        }.value
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
            budgetRepository: budgetRepository
        )
        #expect(store.statistics == .empty)

        await Task { @DatabaseActor in
            transactionRepository.transactionCount = 2
            budgetRepository.budgetCount = 3
            budgetRepository.annualBudgetConfigCount = 1
            budgetRepository.categoryCount = 4
            budgetRepository.institutionCount = 2
        }.value

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
        let major = CategoryEntity(name: "食費")
        let minor = CategoryEntity(name: "外食", parent: major)
        let institution = FinancialInstitution(name: "銀行")
        let transaction = Transaction(
            date: Date(),
            title: "テスト",
            amount: -1_000,
            financialInstitution: institution,
            majorCategory: major,
            minorCategory: minor
        )
        let transactionDTO = TransactionDTO(from: transaction)
        let categoryDTOs = [Category(from: major), Category(from: minor)]
        let institutionDTO = FinancialInstitutionDTO(from: institution)
        let transactionRepository = await makeTransactionRepository { repository in
            repository.snapshotTransactions = [transactionDTO]
            repository.snapshotCategories = categoryDTOs
            repository.snapshotInstitutions = [institutionDTO]
            repository.transactionCount = 1
        }
        let store = await makeSettingsStore(
            modelContainer: container,
            userDefaults: defaults,
            transactionRepository: transactionRepository
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
        let backupManager = BackupManager(modelContainer: sourceContainer)
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
            transactionRepository: transactionRepository
        )

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
    let category = CategoryEntity(name: "食費")
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
    userDefaults: UserDefaults,
    transactionRepository: MockTransactionRepository? = nil,
    budgetRepository: MockBudgetRepository? = nil
) async -> SettingsStore {
    let resolvedTransactionRepository: MockTransactionRepository
    if let transactionRepository {
        resolvedTransactionRepository = transactionRepository
    } else {
        resolvedTransactionRepository = await makeTransactionRepository()
    }
    let resolvedBudgetRepository: MockBudgetRepository
    if let budgetRepository {
        resolvedBudgetRepository = budgetRepository
    } else {
        resolvedBudgetRepository = await makeBudgetRepository()
    }
    return await SettingsStore(
        modelContainer: modelContainer,
        userDefaults: userDefaults,
        transactionRepository: resolvedTransactionRepository,
        budgetRepository: resolvedBudgetRepository
    )
}

@MainActor
private func makeTransactionRepository(
    configure: (@DatabaseActor (MockTransactionRepository) -> Void)? = nil
) async -> MockTransactionRepository {
    await Task { @DatabaseActor () -> MockTransactionRepository in
        let repository = MockTransactionRepository()
        configure?(repository)
        return repository
    }.value
}

@MainActor
private func makeBudgetRepository(
    configure: (@DatabaseActor (MockBudgetRepository) -> Void)? = nil
) async -> MockBudgetRepository {
    await Task { @DatabaseActor () -> MockBudgetRepository in
        let repository = MockBudgetRepository()
        configure?(repository)
        return repository
    }.value
}

@DatabaseActor
private final class MockTransactionRepository: TransactionRepository {
    internal var transactionCount: Int = 0
    internal var snapshotTransactions: [TransactionDTO] = []
    internal var snapshotCategories: [Kakeibo.Category] = []
    internal var snapshotInstitutions: [FinancialInstitutionDTO] = []
    internal private(set) var deleteAllTransactionsCallCount: Int = 0

    internal func fetchTransactions(query: TransactionQuery) throws -> [TransactionDTO] {
        unsupported(#function)
    }

    internal func fetchAllTransactions() throws -> [TransactionDTO] {
        snapshotTransactions
    }

    internal func fetchCSVExportSnapshot() throws -> TransactionCSVExportSnapshot {
        TransactionCSVExportSnapshot(
            transactions: snapshotTransactions,
            categories: snapshotCategories,
            institutions: snapshotInstitutions
        )
    }

    internal func countTransactions() throws -> Int {
        transactionCount
    }

    internal func fetchInstitutions() throws -> [FinancialInstitutionDTO] {
        snapshotInstitutions
    }

    internal func fetchCategories() throws -> [Kakeibo.Category] {
        snapshotCategories
    }

    @discardableResult
    internal func observeTransactions(
        query: TransactionQuery,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void
    ) throws -> ObservationToken {
        unsupported(#function)
    }

    internal func findTransaction(id: UUID) throws -> TransactionDTO? {
        unsupported(#function)
    }

    internal func findByIdentifier(_ identifier: String) throws -> TransactionDTO? {
        unsupported(#function)
    }

    @discardableResult
    internal func insert(_ input: TransactionInput) throws -> UUID {
        unsupported(#function)
    }

    internal func update(_ input: TransactionUpdateInput) throws {
        unsupported(#function)
    }

    internal func deleteAllTransactions() throws {
        deleteAllTransactionsCallCount += 1
        transactionCount = 0
    }

    internal func delete(id: UUID) throws {
        unsupported(#function)
    }

    internal func saveChanges() throws {}
}

@DatabaseActor
private final class MockBudgetRepository: BudgetRepository {
    internal var budgetCount: Int = 0
    internal var annualBudgetConfigCount: Int = 0
    internal var categoryCount: Int = 0
    internal var institutionCount: Int = 0

    internal private(set) var deleteAllBudgetsCallCount: Int = 0
    internal private(set) var deleteAllConfigsCallCount: Int = 0
    internal private(set) var deleteAllCategoriesCallCount: Int = 0
    internal private(set) var deleteAllInstitutionsCallCount: Int = 0

    internal func fetchSnapshot(for year: Int) throws -> BudgetSnapshot {
        unsupported(#function)
    }

    internal func category(id: UUID) throws -> Kakeibo.Category? {
        unsupported(#function)
    }

    internal func findCategoryByName(_ name: String, parentId: UUID?) throws -> Kakeibo.Category? {
        unsupported(#function)
    }

    internal func createCategory(name: String, parentId: UUID?) throws -> UUID {
        unsupported(#function)
    }

    internal func countCategories() throws -> Int {
        categoryCount
    }

    internal func findInstitutionByName(_ name: String) throws -> FinancialInstitutionDTO? {
        unsupported(#function)
    }

    internal func createInstitution(name: String) throws -> UUID {
        unsupported(#function)
    }

    internal func countFinancialInstitutions() throws -> Int {
        institutionCount
    }

    internal func annualBudgetConfig(for year: Int) throws -> AnnualBudgetConfigDTO? {
        nil
    }

    internal func countAnnualBudgetConfigs() throws -> Int {
        annualBudgetConfigCount
    }

    internal func addBudget(_ input: BudgetInput) throws {
        unsupported(#function)
    }

    internal func updateBudget(input: BudgetUpdateInput) throws {
        unsupported(#function)
    }

    internal func deleteBudget(id: UUID) throws {
        unsupported(#function)
    }

    internal func deleteAllBudgets() throws {
        deleteAllBudgetsCallCount += 1
        budgetCount = 0
    }

    internal func deleteAllAnnualBudgetConfigs() throws {
        deleteAllConfigsCallCount += 1
        annualBudgetConfigCount = 0
    }

    internal func deleteAllCategories() throws {
        deleteAllCategoriesCallCount += 1
        categoryCount = 0
    }

    internal func deleteAllFinancialInstitutions() throws {
        deleteAllInstitutionsCallCount += 1
        institutionCount = 0
    }

    internal func countBudgets() throws -> Int {
        budgetCount
    }

    internal func upsertAnnualBudgetConfig(_ input: AnnualBudgetConfigInput) throws {
        unsupported(#function)
    }

    internal func saveChanges() throws {}
}

private func unsupported(_ function: StaticString) -> Never {
    preconditionFailure("\(function) is not supported in this context")
}
