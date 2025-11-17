import Foundation

/// ドメイン層で扱う定期支払い定義
internal struct RecurringPaymentDefinition: Sendable {
    internal let id: UUID
    internal let name: String
    internal let notes: String
    internal let amount: Decimal
    internal let recurrenceIntervalMonths: Int
    internal let firstOccurrenceDate: Date
    internal let endDate: Date?
    internal let leadTimeMonths: Int
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
        leadTimeMonths: Int,
        categoryId: UUID?,
        savingStrategy: RecurringPaymentSavingStrategy,
        customMonthlySavingAmount: Decimal?,
        dateAdjustmentPolicy: DateAdjustmentPolicy,
        recurrenceDayPattern: DayOfMonthPattern?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.amount = amount
        self.recurrenceIntervalMonths = recurrenceIntervalMonths
        self.firstOccurrenceDate = firstOccurrenceDate
        self.endDate = endDate
        self.leadTimeMonths = leadTimeMonths
        self.categoryId = categoryId
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.recurrenceDayPattern = recurrenceDayPattern
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from definition: RecurringPaymentDefinitionEntity) {
        self.id = definition.id
        self.name = definition.name
        self.notes = definition.notes
        self.amount = definition.amount
        self.recurrenceIntervalMonths = definition.recurrenceIntervalMonths
        self.firstOccurrenceDate = definition.firstOccurrenceDate
        self.endDate = definition.endDate
        self.leadTimeMonths = definition.leadTimeMonths
        self.categoryId = definition.category?.id
        self.savingStrategy = definition.savingStrategy
        self.customMonthlySavingAmount = definition.customMonthlySavingAmount
        self.dateAdjustmentPolicy = definition.dateAdjustmentPolicy
        self.recurrenceDayPattern = definition.recurrenceDayPattern
        self.createdAt = definition.createdAt
        self.updatedAt = definition.updatedAt
    }

    /// 月次の積立金額（カスタムの場合は指定値、均等配分なら周期で割った値）
    internal var monthlySavingAmount: Decimal {
        switch savingStrategy {
        case .disabled:
            return 0
        case .evenlyDistributed:
            guard recurrenceIntervalMonths > 0 else { return 0 }
            return amount.safeDivide(Decimal(recurrenceIntervalMonths))
        case .customMonthly:
            return customMonthlySavingAmount ?? 0
        }
    }
}
