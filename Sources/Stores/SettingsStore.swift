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
    private let transactionRepository: TransactionRepository
    private let budgetRepository: BudgetRepository

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
        transactionRepository: TransactionRepository,
        budgetRepository: BudgetRepository,
    ) async {
        self.modelContainer = modelContainer
        self.backupManager = backupManager ?? BackupManager(
            backupRepository: SwiftDataBackupRepository(modelContainer: modelContainer),
        )
        self.csvExporter = csvExporter
        self.userDefaults = userDefaults
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository

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

        let initialStatistics = try? await makeStatistics(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )
        statistics = initialStatistics ?? .empty
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
        statistics = await (try? makeStatistics(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository,
        )) ?? .empty
    }

    // MARK: - CSV Export

    /// 取引のCSVエクスポートを実行
    internal func exportTransactionsCSV() async throws -> CSVExportResult {
        let snapshot = try await transactionRepository.fetchCSVExportSnapshot()
        return try csvExporter.exportTransactions(snapshot)
    }

    // MARK: - Backup & Restore

    /// バックアップを作成
    internal func createBackupArchive() async throws -> BackupArchive {
        isProcessingBackup = true
        do {
            let payload = try await backupManager.buildPayload()
            let archive = try await backupManager.createBackup(payload: payload)
            isProcessingBackup = false
            lastBackupMetadata = archive.metadata
            statusMessage = "バックアップを作成しました"
            return archive
        } catch {
            isProcessingBackup = false
            throw error
        }
    }

    /// バックアップから復元
    /// - Parameter data: バックアップデータ
    /// - Returns: 復元サマリ
    internal func restoreBackup(from data: Data) async throws -> BackupRestoreSummary {
        isProcessingBackup = true
        do {
            let payload = try await backupManager.decodeBackup(from: data)
            let summary = try await backupManager.restorePayload(payload)
            await refreshStatistics()
            isProcessingBackup = false
            lastRestoreSummary = summary
            lastBackupMetadata = summary.metadata
            statusMessage = "バックアップから復元しました"
            return summary
        } catch {
            isProcessingBackup = false
            throw error
        }
    }

    /// すべてのデータを削除
    internal func deleteAllData() async throws {
        isProcessingDeletion = true
        do {
            try await transactionRepository.deleteAllTransactions()
            try await budgetRepository.deleteAllBudgets()
            try await budgetRepository.deleteAllAnnualBudgetConfigs()
            try await budgetRepository.deleteAllCategories()
            try await budgetRepository.deleteAllFinancialInstitutions()
            await refreshStatistics()
            isProcessingDeletion = false
            lastRestoreSummary = nil
            lastBackupMetadata = nil
            statusMessage = "すべてのデータを削除しました"
        } catch {
            isProcessingDeletion = false
            throw error
        }
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

private func makeStatistics(
    transactionRepository: TransactionRepository,
    budgetRepository: BudgetRepository,
) async throws -> SettingsStore.DataStatistics {
    try await SettingsStore.DataStatistics(
        transactions: transactionRepository.countTransactions(),
        categories: budgetRepository.countCategories(),
        budgets: budgetRepository.countBudgets(),
        annualBudgetConfigs: budgetRepository.countAnnualBudgetConfigs(),
        financialInstitutions: budgetRepository.countFinancialInstitutions(),
    )
}
