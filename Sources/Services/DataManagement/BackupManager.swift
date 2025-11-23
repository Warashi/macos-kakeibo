import Foundation

/// バックアップとリストアを担当するコンポーネント
internal actor BackupManager {
    private let backupRepository: BackupRepository

    internal init(backupRepository: BackupRepository) {
        self.backupRepository = backupRepository
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
    internal func buildPayload() async throws -> BackupPayload {
        let entities = try await backupRepository.fetchAllEntities()

        let metadata = BackupMetadata(
            generatedAt: Date(),
            appVersion: AppConstants.App.version,
            build: AppConstants.App.build,
            recordCounts: BackupRecordCounts(
                transactions: entities.transactions.count,
                categories: entities.categories.count,
                budgets: entities.budgets.count,
                annualBudgetConfigs: entities.annualBudgetConfigs.count,
                annualBudgetAllocations: entities.annualBudgetAllocations.count,
                financialInstitutions: entities.financialInstitutions.count,
                recurringPaymentDefinitions: entities.recurringPaymentDefinitions.count,
                recurringPaymentOccurrences: entities.recurringPaymentOccurrences.count,
                recurringPaymentSavingBalances: entities.recurringPaymentSavingBalances.count,
                customHolidays: entities.customHolidays.count
            )
        )

        return BackupPayload(
            metadata: metadata,
            transactions: entities.transactions,
            categories: entities.categories,
            budgets: entities.budgets,
            annualBudgetConfigs: entities.annualBudgetConfigs,
            annualBudgetAllocations: entities.annualBudgetAllocations,
            financialInstitutions: entities.financialInstitutions,
            recurringPaymentDefinitions: entities.recurringPaymentDefinitions,
            recurringPaymentOccurrences: entities.recurringPaymentOccurrences,
            recurringPaymentSavingBalances: entities.recurringPaymentSavingBalances,
            customHolidays: entities.customHolidays
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
    internal func restorePayload(_ payload: BackupPayload) async throws -> BackupRestoreSummary {
        let entities = BackupEntitiesData(
            transactions: payload.transactions,
            categories: payload.categories,
            budgets: payload.budgets,
            annualBudgetConfigs: payload.annualBudgetConfigs,
            annualBudgetAllocations: payload.annualBudgetAllocations,
            financialInstitutions: payload.financialInstitutions,
            recurringPaymentDefinitions: payload.recurringPaymentDefinitions,
            recurringPaymentOccurrences: payload.recurringPaymentOccurrences,
            recurringPaymentSavingBalances: payload.recurringPaymentSavingBalances,
            customHolidays: payload.customHolidays
        )

        try await backupRepository.restoreEntities(entities)

        return BackupRestoreSummary(
            metadata: payload.metadata,
            restoredCounts: payload.metadata.recordCounts
        )
    }

    private nonisolated func makeFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Backup.fileDateFormat
        formatter.locale = Foundation.Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "\(AppConstants.Backup.filePrefix)\(timestamp).\(AppConstants.Backup.fileExtension)"
    }
}
