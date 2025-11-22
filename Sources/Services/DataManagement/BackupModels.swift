import Foundation

/// バックアップ生成結果
internal struct BackupArchive: Sendable {
    internal let data: Data
    internal let metadata: BackupMetadata
    internal let suggestedFileName: String
}

/// リストア結果
internal struct BackupRestoreSummary: Sendable {
    internal let metadata: BackupMetadata
    internal let restoredCounts: BackupRecordCounts
}

/// バックアップメタデータ
internal struct BackupMetadata: Codable, Sendable {
    internal let generatedAt: Date
    internal let appVersion: String
    internal let build: String
    internal let recordCounts: BackupRecordCounts
}

/// バックアップ対象件数
internal struct BackupRecordCounts: Codable, Sendable {
    internal let transactions: Int
    internal let categories: Int
    internal let budgets: Int
    internal let annualBudgetConfigs: Int
    internal let annualBudgetAllocations: Int
    internal let financialInstitutions: Int
    internal let recurringPaymentDefinitions: Int
    internal let recurringPaymentOccurrences: Int
    internal let recurringPaymentSavingBalances: Int
    internal let customHolidays: Int
}

/// バックアップ関連エラー
internal enum BackupManagerError: LocalizedError {
    case decodingFailed

    internal var errorDescription: String? {
        switch self {
        case .decodingFailed:
            "バックアップデータの読み込みに失敗しました。"
        }
    }
}
