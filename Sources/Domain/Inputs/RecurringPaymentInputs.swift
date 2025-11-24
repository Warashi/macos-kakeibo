import Foundation

/// 定期支払い定義の入力パラメータ
internal struct RecurringPaymentDefinitionInput: Sendable {
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
    internal let matchKeywords: [String]

    internal init(
        name: String,
        notes: String = "",
        amount: Decimal,
        recurrenceIntervalMonths: Int,
        firstOccurrenceDate: Date,
        endDate: Date? = nil,
        categoryId: UUID? = nil,
        savingStrategy: RecurringPaymentSavingStrategy = .evenlyDistributed,
        customMonthlySavingAmount: Decimal? = nil,
        dateAdjustmentPolicy: DateAdjustmentPolicy = .none,
        recurrenceDayPattern: DayOfMonthPattern? = nil,
        matchKeywords: [String] = [],
    ) {
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
        self.matchKeywords = matchKeywords
    }
}

/// 定期支払いOccurrence完了時の入力パラメータ
internal struct OccurrenceCompletionInput: Sendable {
    internal let actualDate: Date
    internal let actualAmount: Decimal
    internal let transaction: Transaction?

    internal init(
        actualDate: Date,
        actualAmount: Decimal,
        transaction: Transaction? = nil,
    ) {
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transaction = transaction
    }
}

/// 定期支払いOccurrence更新時の入力パラメータ
internal struct OccurrenceUpdateInput: Sendable {
    internal let status: RecurringPaymentStatus
    internal let actualDate: Date?
    internal let actualAmount: Decimal?
    internal let transaction: Transaction?

    internal init(
        status: RecurringPaymentStatus,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transaction: Transaction? = nil,
    ) {
        self.status = status
        self.actualDate = actualDate
        self.actualAmount = actualAmount
        self.transaction = transaction
    }
}
