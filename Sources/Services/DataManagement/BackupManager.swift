import Foundation
import SwiftData

/// バックアップとリストアを担当するコンポーネント
internal actor BackupManager {
    private let modelContainer: ModelContainer

    internal init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// バックアップを生成
    /// - Parameter payload: バックアップペイロード (MainActor で事前に生成)
    /// - Returns: バックアップデータとメタデータ
    internal func createBackup(payload: BackupPayload) throws -> BackupArchive {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let fileName = makeFileName(for: payload.metadata.generatedAt)
        return BackupArchive(data: data, metadata: payload.metadata, suggestedFileName: fileName)
    }

    /// バックアップペイロードを構築
    internal func buildPayload() throws -> BackupPayload {
        let modelContext = ModelContext(modelContainer)
        let transactions = try modelContext.fetchAll(SwiftDataTransaction.self)
        let categories = try modelContext.fetchAll(SwiftDataCategory.self)
        let budgets = try modelContext.fetchAll(SwiftDataBudget.self)
        let configs = try modelContext.fetchAll(SwiftDataAnnualBudgetConfig.self)
        let allocations = try modelContext.fetchAll(SwiftDataAnnualBudgetAllocation.self)
        let institutions = try modelContext.fetchAll(SwiftDataFinancialInstitution.self)
        let definitions = try modelContext.fetchAll(SwiftDataRecurringPaymentDefinition.self)
        let occurrences = try modelContext.fetchAll(SwiftDataRecurringPaymentOccurrence.self)
        let balances = try modelContext.fetchAll(SwiftDataRecurringPaymentSavingBalance.self)
        let holidays = try modelContext.fetchAll(SwiftDataCustomHoliday.self)

        let metadata = BackupMetadata(
            generatedAt: Date(),
            appVersion: AppConstants.App.version,
            build: AppConstants.App.build,
            recordCounts: BackupRecordCounts(
                transactions: transactions.count,
                categories: categories.count,
                budgets: budgets.count,
                annualBudgetConfigs: configs.count,
                annualBudgetAllocations: allocations.count,
                financialInstitutions: institutions.count,
                recurringPaymentDefinitions: definitions.count,
                recurringPaymentOccurrences: occurrences.count,
                recurringPaymentSavingBalances: balances.count,
                customHolidays: holidays.count,
            ),
        )

        return BackupPayload(
            metadata: metadata,
            transactions: transactions.map(BackupTransactionDTO.init),
            categories: categories.map(BackupCategory.init),
            budgets: budgets.map(BackupBudgetDTO.init),
            annualBudgetConfigs: configs.map(BackupAnnualBudgetConfig.init),
            annualBudgetAllocations: allocations.map(BackupAnnualBudgetAllocationDTO.init),
            financialInstitutions: institutions.map(BackupFinancialInstitutionDTO.init),
            recurringPaymentDefinitions: definitions.map(BackupRecurringPaymentDefinitionDTO.init),
            recurringPaymentOccurrences: occurrences.map(BackupRecurringPaymentOccurrenceDTO.init),
            recurringPaymentSavingBalances: balances.map(BackupRecurringPaymentSavingBalanceDTO.init),
            customHolidays: holidays.map(BackupCustomHolidayDTO.init),
        )
    }

    /// バックアップからデータを復元（デコードのみ）
    /// - Parameter data: バックアップデータ
    /// - Returns: デコードされたペイロード
    internal func decodeBackup(from data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let payload = try? decoder.decode(BackupPayload.self, from: data) else {
            throw BackupManagerError.decodingFailed
        }

        return payload
    }

    /// ペイロードからデータを復元
    internal func restorePayload(_ payload: BackupPayload) throws -> BackupRestoreSummary {
        let modelContext = ModelContext(modelContainer)
        try clearAllData(in: modelContext)

        // 依存関係の順序に従って復元
        let institutions = try insertFinancialInstitutions(payload.financialInstitutions, context: modelContext)
        let categories = try insertCategories(payload.categories, context: modelContext)
        try insertCustomHolidays(payload.customHolidays, context: modelContext)
        let configs = try insertAnnualBudgetConfigs(payload.annualBudgetConfigs, context: modelContext)
        try insertAnnualBudgetAllocations(
            payload.annualBudgetAllocations,
            categories: categories,
            configs: configs,
            context: modelContext,
        )
        try insertBudgets(payload.budgets, categories: categories, context: modelContext)
        let definitions = try insertRecurringPaymentDefinitions(
            payload.recurringPaymentDefinitions,
            categories: categories,
            context: modelContext,
        )
        let transactions = try insertTransactions(
            payload.transactions,
            categories: categories,
            institutions: institutions,
            context: modelContext,
        )
        try insertRecurringPaymentOccurrences(
            payload.recurringPaymentOccurrences,
            definitions: definitions,
            transactions: transactions,
            context: modelContext,
        )
        try insertRecurringPaymentSavingBalances(
            payload.recurringPaymentSavingBalances,
            definitions: definitions,
            context: modelContext,
        )

        try modelContext.save()

        return BackupRestoreSummary(
            metadata: payload.metadata,
            restoredCounts: payload.metadata.recordCounts,
        )
    }

    // MARK: - Clear

    private func clearAllData(in context: ModelContext) throws {
        // 依存関係の順序に注意して削除
        try deleteAll(SwiftDataRecurringPaymentOccurrence.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentSavingBalance.self, in: context)
        try deleteAll(SwiftDataRecurringPaymentDefinition.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetAllocation.self, in: context)
        try deleteAll(SwiftDataTransaction.self, in: context)
        try deleteAll(SwiftDataBudget.self, in: context)
        try deleteAll(SwiftDataAnnualBudgetConfig.self, in: context)
        try deleteCategoriesSafely(in: context)
        try deleteAll(SwiftDataFinancialInstitution.self, in: context)
        try deleteAll(SwiftDataCustomHoliday.self, in: context)
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }

    /// 親子関係を維持しながらカテゴリを削除
    private func deleteCategoriesSafely(in context: ModelContext) throws {
        let descriptor: ModelFetchRequest<SwiftDataCategory> = ModelFetchFactory.make()
        let categories = try context.fetch(descriptor)
        let minors = categories.filter(\.isMinor)
        let majors = categories.filter(\.isMajor)

        for category in minors + majors {
            context.delete(category)
        }
    }

    private nonisolated func makeFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Backup.fileDateFormat
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "\(AppConstants.Backup.filePrefix)\(timestamp).\(AppConstants.Backup.fileExtension)"
    }
}
