import Foundation

// MARK: - Backup Models

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

// MARK: - Entities Data

/// バックアップ用のエンティティデータ
/// BackupPayloadからメタデータを除いた、純粋なエンティティデータ
internal struct BackupEntitiesData: Sendable {
    internal let transactions: [BackupTransactionDTO]
    internal let categories: [BackupCategory]
    internal let budgets: [BackupBudgetDTO]
    internal let annualBudgetConfigs: [BackupAnnualBudgetConfig]
    internal let annualBudgetAllocations: [BackupAnnualBudgetAllocationDTO]
    internal let financialInstitutions: [BackupFinancialInstitutionDTO]
    internal let recurringPaymentDefinitions: [BackupRecurringPaymentDefinitionDTO]
    internal let recurringPaymentOccurrences: [BackupRecurringPaymentOccurrenceDTO]
    internal let recurringPaymentSavingBalances: [BackupRecurringPaymentSavingBalanceDTO]
    internal let customHolidays: [BackupCustomHolidayDTO]
}

// MARK: - Payload DTOs

internal struct BackupPayload: Codable, Sendable {
    internal let metadata: BackupMetadata
    internal let transactions: [BackupTransactionDTO]
    internal let categories: [BackupCategory]
    internal let budgets: [BackupBudgetDTO]
    internal let annualBudgetConfigs: [BackupAnnualBudgetConfig]
    internal let annualBudgetAllocations: [BackupAnnualBudgetAllocationDTO]
    internal let financialInstitutions: [BackupFinancialInstitutionDTO]
    internal let recurringPaymentDefinitions: [BackupRecurringPaymentDefinitionDTO]
    internal let recurringPaymentOccurrences: [BackupRecurringPaymentOccurrenceDTO]
    internal let recurringPaymentSavingBalances: [BackupRecurringPaymentSavingBalanceDTO]
    internal let customHolidays: [BackupCustomHolidayDTO]
}

internal struct BackupTransactionDTO: Codable, Sendable {
    internal let id: UUID
    internal let date: Date
    internal let title: String
    internal let amount: Decimal
    internal let memo: String
    internal let isIncludedInCalculation: Bool
    internal let isTransfer: Bool
    internal let financialInstitutionId: UUID?
    internal let majorCategoryId: UUID?
    internal let minorCategoryId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupCategory: Codable, Sendable {
    internal let id: UUID
    internal let name: String
    internal let parentId: UUID?
    internal let allowsAnnualBudget: Bool
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupBudgetDTO: Codable, Sendable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupAnnualBudgetConfig: Codable, Sendable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policyRawValue: String
    internal let createdAt: Date
    internal let updatedAt: Date

    internal var policy: AnnualBudgetPolicy {
        AnnualBudgetPolicy(rawValue: policyRawValue) ?? .automatic
    }
}

internal struct BackupFinancialInstitutionDTO: Codable, Sendable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupAnnualBudgetAllocationDTO: Codable, Sendable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID
    internal let policyOverrideRawValue: String?
    internal let configId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupRecurringPaymentDefinitionDTO: Codable, Sendable {
    internal let id: UUID
    internal let name: String
    internal let notes: String
    internal let amount: Decimal
    internal let recurrenceIntervalMonths: Int
    internal let firstOccurrenceDate: Date
    internal let endDate: Date?
    internal let categoryId: UUID?
    internal let savingStrategy: RecurringPaymentSavingStrategy
    internal let customMonthlySavingAmount: Decimal?
    internal let dateAdjustmentPolicy: DateAdjustmentPolicy
    internal let recurrenceDayPattern: DayOfMonthPattern?
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupRecurringPaymentOccurrenceDTO: Codable, Sendable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let scheduledDate: Date
    internal let expectedAmount: Decimal
    internal let status: RecurringPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transactionId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupRecurringPaymentSavingBalanceDTO: Codable, Sendable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let totalSavedAmount: Decimal
    internal let totalPaidAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date
}

internal struct BackupCustomHolidayDTO: Codable, Sendable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date
}
