import Foundation

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

internal struct BackupTransactionDTO: Codable {
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

    internal init(transaction: SwiftDataTransaction) {
        self.id = transaction.id
        self.date = transaction.date
        self.title = transaction.title
        self.amount = transaction.amount
        self.memo = transaction.memo
        self.isIncludedInCalculation = transaction.isIncludedInCalculation
        self.isTransfer = transaction.isTransfer
        self.financialInstitutionId = transaction.financialInstitution?.id
        self.majorCategoryId = transaction.majorCategory?.id
        self.minorCategoryId = transaction.minorCategory?.id
        self.createdAt = transaction.createdAt
        self.updatedAt = transaction.updatedAt
    }
}

internal struct BackupCategory: Codable {
    internal let id: UUID
    internal let name: String
    internal let parentId: UUID?
    internal let allowsAnnualBudget: Bool
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(category: SwiftDataCategory) {
        self.id = category.id
        self.name = category.name
        self.parentId = category.parent?.id
        self.allowsAnnualBudget = category.allowsAnnualBudget
        self.displayOrder = category.displayOrder
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
    }
}

internal struct BackupBudgetDTO: Codable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID?
    internal let startYear: Int
    internal let startMonth: Int
    internal let endYear: Int
    internal let endMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(budget: SwiftDataBudget) {
        self.id = budget.id
        self.amount = budget.amount
        self.categoryId = budget.category?.id
        self.startYear = budget.startYear
        self.startMonth = budget.startMonth
        self.endYear = budget.endYear
        self.endMonth = budget.endMonth
        self.createdAt = budget.createdAt
        self.updatedAt = budget.updatedAt
    }
}

internal struct BackupAnnualBudgetConfig: Codable {
    internal let id: UUID
    internal let year: Int
    internal let totalAmount: Decimal
    internal let policyRawValue: String
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(config: SwiftDataAnnualBudgetConfig) {
        self.id = config.id
        self.year = config.year
        self.totalAmount = config.totalAmount
        self.policyRawValue = config.policy.rawValue
        self.createdAt = config.createdAt
        self.updatedAt = config.updatedAt
    }

    internal var policy: AnnualBudgetPolicy {
        AnnualBudgetPolicy(rawValue: policyRawValue) ?? .automatic
    }
}

internal struct BackupFinancialInstitutionDTO: Codable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(institution: SwiftDataFinancialInstitution) {
        self.id = institution.id
        self.name = institution.name
        self.displayOrder = institution.displayOrder
        self.createdAt = institution.createdAt
        self.updatedAt = institution.updatedAt
    }
}

internal struct BackupAnnualBudgetAllocationDTO: Codable {
    internal let id: UUID
    internal let amount: Decimal
    internal let categoryId: UUID
    internal let policyOverrideRawValue: String?
    internal let configId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(allocation: SwiftDataAnnualBudgetAllocation) {
        self.id = allocation.id
        self.amount = allocation.amount
        self.categoryId = allocation.category.id
        self.policyOverrideRawValue = allocation.policyOverrideRawValue
        self.configId = allocation.config?.id
        self.createdAt = allocation.createdAt
        self.updatedAt = allocation.updatedAt
    }
}

internal struct BackupRecurringPaymentDefinitionDTO: Codable {
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

    internal init(definition: SwiftDataRecurringPaymentDefinition) {
        self.id = definition.id
        self.name = definition.name
        self.notes = definition.notes
        self.amount = definition.amount
        self.recurrenceIntervalMonths = definition.recurrenceIntervalMonths
        self.firstOccurrenceDate = definition.firstOccurrenceDate
        self.endDate = definition.endDate
        self.categoryId = definition.category?.id
        self.savingStrategy = definition.savingStrategy
        self.customMonthlySavingAmount = definition.customMonthlySavingAmount
        self.dateAdjustmentPolicy = definition.dateAdjustmentPolicy
        self.recurrenceDayPattern = definition.recurrenceDayPattern
        self.createdAt = definition.createdAt
        self.updatedAt = definition.updatedAt
    }
}

internal struct BackupRecurringPaymentOccurrenceDTO: Codable {
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

    internal init(occurrence: SwiftDataRecurringPaymentOccurrence) {
        self.id = occurrence.id
        self.definitionId = occurrence.definitionId
        self.scheduledDate = occurrence.scheduledDate
        self.expectedAmount = occurrence.expectedAmount
        self.status = occurrence.status
        self.actualDate = occurrence.actualDate
        self.actualAmount = occurrence.actualAmount
        self.transactionId = occurrence.transaction?.id
        self.createdAt = occurrence.createdAt
        self.updatedAt = occurrence.updatedAt
    }
}

internal struct BackupRecurringPaymentSavingBalanceDTO: Codable {
    internal let id: UUID
    internal let definitionId: UUID
    internal let totalSavedAmount: Decimal
    internal let totalPaidAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(balance: SwiftDataRecurringPaymentSavingBalance) {
        self.id = balance.id
        self.definitionId = balance.definition.id
        self.totalSavedAmount = balance.totalSavedAmount
        self.totalPaidAmount = balance.totalPaidAmount
        self.lastUpdatedYear = balance.lastUpdatedYear
        self.lastUpdatedMonth = balance.lastUpdatedMonth
        self.createdAt = balance.createdAt
        self.updatedAt = balance.updatedAt
    }
}

internal struct BackupCustomHolidayDTO: Codable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(holiday: SwiftDataCustomHoliday) {
        self.id = holiday.id
        self.date = holiday.date
        self.name = holiday.name
        self.isRecurring = holiday.isRecurring
        self.createdAt = holiday.createdAt
        self.updatedAt = holiday.updatedAt
    }
}
