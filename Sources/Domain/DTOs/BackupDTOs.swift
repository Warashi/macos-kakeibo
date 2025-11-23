import Foundation

// MARK: - Backup Models

/// バックアップ生成結果
internal struct BackupArchive: Sendable {
    internal let data: Data
    internal let metadata: BackupMetadata
    internal let suggestedFileName: String

    internal init(data: Data, metadata: BackupMetadata, suggestedFileName: String) {
        self.data = data
        self.metadata = metadata
        self.suggestedFileName = suggestedFileName
    }
}

/// リストア結果
internal struct BackupRestoreSummary: Sendable {
    internal let metadata: BackupMetadata
    internal let restoredCounts: BackupRecordCounts

    internal init(metadata: BackupMetadata, restoredCounts: BackupRecordCounts) {
        self.metadata = metadata
        self.restoredCounts = restoredCounts
    }
}

/// バックアップメタデータ
internal struct BackupMetadata: Codable, Sendable {
    internal let generatedAt: Date
    internal let appVersion: String
    internal let build: String
    internal let recordCounts: BackupRecordCounts

    internal init(generatedAt: Date, appVersion: String, build: String, recordCounts: BackupRecordCounts) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.build = build
        self.recordCounts = recordCounts
    }
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

    internal init(
        transactions: Int,
        categories: Int,
        budgets: Int,
        annualBudgetConfigs: Int,
        annualBudgetAllocations: Int,
        financialInstitutions: Int,
        recurringPaymentDefinitions: Int,
        recurringPaymentOccurrences: Int,
        recurringPaymentSavingBalances: Int,
        customHolidays: Int
    ) {
        self.transactions = transactions
        self.categories = categories
        self.budgets = budgets
        self.annualBudgetConfigs = annualBudgetConfigs
        self.annualBudgetAllocations = annualBudgetAllocations
        self.financialInstitutions = financialInstitutions
        self.recurringPaymentDefinitions = recurringPaymentDefinitions
        self.recurringPaymentOccurrences = recurringPaymentOccurrences
        self.recurringPaymentSavingBalances = recurringPaymentSavingBalances
        self.customHolidays = customHolidays
    }
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

    internal init(
        transactions: [BackupTransactionDTO],
        categories: [BackupCategory],
        budgets: [BackupBudgetDTO],
        annualBudgetConfigs: [BackupAnnualBudgetConfig],
        annualBudgetAllocations: [BackupAnnualBudgetAllocationDTO],
        financialInstitutions: [BackupFinancialInstitutionDTO],
        recurringPaymentDefinitions: [BackupRecurringPaymentDefinitionDTO],
        recurringPaymentOccurrences: [BackupRecurringPaymentOccurrenceDTO],
        recurringPaymentSavingBalances: [BackupRecurringPaymentSavingBalanceDTO],
        customHolidays: [BackupCustomHolidayDTO]
    ) {
        self.transactions = transactions
        self.categories = categories
        self.budgets = budgets
        self.annualBudgetConfigs = annualBudgetConfigs
        self.annualBudgetAllocations = annualBudgetAllocations
        self.financialInstitutions = financialInstitutions
        self.recurringPaymentDefinitions = recurringPaymentDefinitions
        self.recurringPaymentOccurrences = recurringPaymentOccurrences
        self.recurringPaymentSavingBalances = recurringPaymentSavingBalances
        self.customHolidays = customHolidays
    }
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

    internal init(
        metadata: BackupMetadata,
        transactions: [BackupTransactionDTO],
        categories: [BackupCategory],
        budgets: [BackupBudgetDTO],
        annualBudgetConfigs: [BackupAnnualBudgetConfig],
        annualBudgetAllocations: [BackupAnnualBudgetAllocationDTO],
        financialInstitutions: [BackupFinancialInstitutionDTO],
        recurringPaymentDefinitions: [BackupRecurringPaymentDefinitionDTO],
        recurringPaymentOccurrences: [BackupRecurringPaymentOccurrenceDTO],
        recurringPaymentSavingBalances: [BackupRecurringPaymentSavingBalanceDTO],
        customHolidays: [BackupCustomHolidayDTO]
    ) {
        self.metadata = metadata
        self.transactions = transactions
        self.categories = categories
        self.budgets = budgets
        self.annualBudgetConfigs = annualBudgetConfigs
        self.annualBudgetAllocations = annualBudgetAllocations
        self.financialInstitutions = financialInstitutions
        self.recurringPaymentDefinitions = recurringPaymentDefinitions
        self.recurringPaymentOccurrences = recurringPaymentOccurrences
        self.recurringPaymentSavingBalances = recurringPaymentSavingBalances
        self.customHolidays = customHolidays
    }
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

    internal init(
        id: UUID,
        date: Date,
        title: String,
        amount: Decimal,
        memo: String,
        isIncludedInCalculation: Bool,
        isTransfer: Bool,
        financialInstitutionId: UUID?,
        majorCategoryId: UUID?,
        minorCategoryId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.amount = amount
        self.memo = memo
        self.isIncludedInCalculation = isIncludedInCalculation
        self.isTransfer = isTransfer
        self.financialInstitutionId = financialInstitutionId
        self.majorCategoryId = majorCategoryId
        self.minorCategoryId = minorCategoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

internal struct BackupCategory: Codable, Sendable {
    internal let id: UUID
    internal let name: String
    internal let parentId: UUID?
    internal let allowsAnnualBudget: Bool
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        name: String,
        parentId: UUID?,
        allowsAnnualBudget: Bool,
        displayOrder: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.allowsAnnualBudget = allowsAnnualBudget
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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

    internal init(
        id: UUID,
        amount: Decimal,
        categoryId: UUID?,
        startYear: Int,
        startMonth: Int,
        endYear: Int,
        endMonth: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.startYear = startYear
        self.startMonth = startMonth
        self.endYear = endYear
        self.endMonth = endMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

internal struct BackupAnnualBudgetConfig: Codable, Sendable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policyRawValue: String
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        year: Int,
        totalAmount: Decimal,
        policyRawValue: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.year = year
        self.totalAmount = totalAmount
        self.policyRawValue = policyRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

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

    internal init(
        id: UUID,
        name: String,
        displayOrder: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

internal struct BackupAnnualBudgetAllocationDTO: Codable, Sendable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID
    internal let policyOverrideRawValue: String?
    internal let configId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        amount: Decimal,
        categoryId: UUID,
        policyOverrideRawValue: String?,
        configId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.policyOverrideRawValue = policyOverrideRawValue
        self.configId = configId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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

    internal init(
        id: UUID,
        name: String,
        notes: String,
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        endDate: Date?,
        categoryId: UUID?,
        savingStrategy: RecurringPaymentSavingStrategy,
        customMonthlySavingAmount: Decimal?,
        dateAdjustmentPolicy: DateAdjustmentPolicy,
        recurrenceDayPattern: DayOfMonthPattern?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.amount = amount
        self.recurrenceIntervalMonths = recurrenceIntervalMonths
        self.firstOccurrenceDate = firstOccurrenceDate
        self.endDate = endDate
        self.categoryId = categoryId
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.recurrenceDayPattern = recurrenceDayPattern
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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

    internal init(
        id: UUID,
        definitionId: UUID,
        scheduledDate: Date,
        expectedAmount: Decimal,
        status: RecurringPaymentStatus,
        actualDate: Date?,
        actualAmount: Decimal?,
        transactionId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.definitionId = definitionId
        self.scheduledDate = scheduledDate
        self.expectedAmount = expectedAmount
        self.status = status
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transactionId = transactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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

    internal init(
        id: UUID,
        definitionId: UUID,
        totalSavedAmount: Decimal,
        totalPaidAmount: Decimal,
        lastUpdatedYear: Int,
        lastUpdatedMonth: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.definitionId = definitionId
        self.totalSavedAmount = totalSavedAmount
        self.totalPaidAmount = totalPaidAmount
        self.lastUpdatedYear = lastUpdatedYear
        self.lastUpdatedMonth = lastUpdatedMonth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

internal struct BackupCustomHolidayDTO: Codable, Sendable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        date: Date,
        name: String,
        isRecurring: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.isRecurring = isRecurring
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
