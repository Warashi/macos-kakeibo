import Foundation
import Observation
import SwiftData

/// 設定画面全体を管理するストア
@MainActor
@Observable
internal final class SettingsStore {
    // MARK: - Nested Types

    /// データ件数のサマリ
    internal struct DataStatistics: Equatable, Sendable {
        internal let transactions: Int
        internal let categories: Int
        internal let budgets: Int
        internal let annualBudgetConfigs: Int
        internal let financialInstitutions: Int

        internal static let empty: DataStatistics = .init(
            transactions: 0,
            categories: 0,
            budgets: 0,
            annualBudgetConfigs: 0,
            financialInstitutions: 0,
        )

        internal var totalRecords: Int {
            transactions + categories + budgets + annualBudgetConfigs + financialInstitutions
        }
    }

    // MARK: - Dependencies

    private let modelContainer: ModelContainer
    private let backupManager: BackupManager
    private let csvExporter: CSVExporter
    private let userDefaults: UserDefaults

    // MARK: - User Settings

    internal var includeOnlyCalculationTarget: Bool {
        didSet {
            persistCalculationRules()
        }
    }

    internal var excludeTransfers: Bool {
        didSet {
            persistCalculationRules()
        }
    }

    internal var showCategoryFullPath: Bool {
        didSet {
            persistDisplaySettings()
        }
    }

    internal var useThousandSeparator: Bool {
        didSet {
            persistDisplaySettings()
        }
    }

    // MARK: - UI State

    internal private(set) var statistics: DataStatistics = .empty
    internal private(set) var lastBackupMetadata: BackupMetadata?
    internal private(set) var lastRestoreSummary: BackupRestoreSummary?
    internal var statusMessage: String?
    internal var isProcessingBackup: Bool = false
    internal var isProcessingDeletion: Bool = false

    // MARK: - Initialization

    internal init(
        modelContainer: ModelContainer,
        backupManager: BackupManager? = nil,
        csvExporter: CSVExporter = CSVExporter(),
        userDefaults: UserDefaults = .standard,
    ) {
        self.modelContainer = modelContainer
        self.backupManager = backupManager ?? BackupManager(modelContainer: modelContainer)
        self.csvExporter = csvExporter
        self.userDefaults = userDefaults

        includeOnlyCalculationTarget = userDefaults.bool(
            forKey: UserDefaultsKey.includeOnlyCalculationTarget,
            defaultValue: true,
        )
        excludeTransfers = userDefaults.bool(
            forKey: UserDefaultsKey.excludeTransfers,
            defaultValue: true,
        )
        showCategoryFullPath = userDefaults.bool(
            forKey: UserDefaultsKey.showCategoryFullPath,
            defaultValue: true,
        )
        useThousandSeparator = userDefaults.bool(
            forKey: UserDefaultsKey.useThousandSeparator,
            defaultValue: true,
        )

        let context = ModelContext(modelContainer)
        statistics = (try? makeStatistics(modelContext: context)) ?? .empty
    }

    // MARK: - Settings Handling

    private func persistCalculationRules() {
        userDefaults.set(includeOnlyCalculationTarget, forKey: UserDefaultsKey.includeOnlyCalculationTarget)
        userDefaults.set(excludeTransfers, forKey: UserDefaultsKey.excludeTransfers)
    }

    private func persistDisplaySettings() {
        userDefaults.set(showCategoryFullPath, forKey: UserDefaultsKey.showCategoryFullPath)
        userDefaults.set(useThousandSeparator, forKey: UserDefaultsKey.useThousandSeparator)
    }

    // MARK: - Statistics

    /// データ件数を再計算
    internal func refreshStatistics() async {
        let container = modelContainer
        let result = await Task { @DatabaseActor () -> DataStatistics? in
            let context = ModelContext(container)
            return try? makeStatistics(modelContext: context)
        }.value
        statistics = result ?? .empty
    }

    // MARK: - CSV Export

    /// 取引のCSVエクスポートを実行
    internal func exportTransactionsCSV() async throws -> CSVExportResult {
        let container = modelContainer
        let exporter = csvExporter
        return try await Task { @DatabaseActor () throws -> CSVExportResult in
            let context = ModelContext(container)
            let transactions = try context.fetchAll(Transaction.self)
            return try exporter.exportTransactions(transactions)
        }.value
    }

    // MARK: - Backup & Restore

    /// バックアップを作成
    @MainActor
    internal func createBackupArchive() async throws -> BackupArchive {
        isProcessingBackup = true
        defer {
            isProcessingBackup = false
        }
        let payload = try await backupManager.buildPayload()
        let archive = try await backupManager.createBackup(payload: payload)
        lastBackupMetadata = archive.metadata
        statusMessage = "バックアップを作成しました"
        return archive
    }

    /// バックアップから復元
    /// - Parameter data: バックアップデータ
    /// - Returns: 復元サマリ
    @MainActor
    internal func restoreBackup(from data: Data) async throws -> BackupRestoreSummary {
        isProcessingBackup = true
        defer {
            isProcessingBackup = false
        }
        let payload = try await backupManager.decodeBackup(from: data)
        let summary = try await backupManager.restorePayload(payload)
        lastRestoreSummary = summary
        lastBackupMetadata = summary.metadata
        await refreshStatistics()
        statusMessage = "バックアップから復元しました"
        return summary
    }

    /// すべてのデータを削除
    internal func deleteAllData() async throws {
        isProcessingDeletion = true
        defer { isProcessingDeletion = false }

        let container = modelContainer
        try await Task { @DatabaseActor in
            try clearAllData(in: ModelContext(container))
        }.value
        await refreshStatistics()
        lastRestoreSummary = nil
        lastBackupMetadata = nil
        statusMessage = "すべてのデータを削除しました"
    }

    // MARK: - Internal Keys

    private enum UserDefaultsKey {
        static let includeOnlyCalculationTarget: String = "settings.includeOnlyCalculationTarget"
        static let excludeTransfers: String = "settings.excludeTransfers"
        static let showCategoryFullPath: String = "settings.showCategoryFullPath"
        static let useThousandSeparator: String = "settings.useThousandSeparator"
    }

}

// MARK: - UserDefaults Helper

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

// MARK: - Persistence Helpers

private func makeStatistics(modelContext: ModelContext) throws -> SettingsStore.DataStatistics {
    try SettingsStore.DataStatistics(
        transactions: modelContext.count(Transaction.self),
        categories: modelContext.count(Category.self),
        budgets: modelContext.count(Budget.self),
        annualBudgetConfigs: modelContext.count(AnnualBudgetConfig.self),
        financialInstitutions: modelContext.count(FinancialInstitution.self),
    )
}

private func clearAllData(in context: ModelContext) throws {
    try deleteAll(Transaction.self, in: context)
    try deleteAll(Budget.self, in: context)
    try deleteAll(AnnualBudgetConfig.self, in: context)
    try deleteCategoriesSafely(in: context)
    try deleteAll(FinancialInstitution.self, in: context)
    try context.save()
}

private func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
    let descriptor: ModelFetchRequest<T> = ModelFetchFactory.make()
    let items = try context.fetch(descriptor)
    for item in items {
        context.delete(item)
    }
}

private func deleteCategoriesSafely(in context: ModelContext) throws {
    let descriptor: ModelFetchRequest<Category> = ModelFetchFactory.make()
    let categories = try context.fetch(descriptor)
    let minors = categories.filter(\.isMinor)
    let majors = categories.filter(\.isMajor)

    for category in minors + majors {
        context.delete(category)
    }
}
