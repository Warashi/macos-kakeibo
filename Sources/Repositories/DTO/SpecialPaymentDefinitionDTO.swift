import Foundation

/// SpecialPaymentDefinitionのDTO（Sendable）
internal struct SpecialPaymentDefinitionDTO: Sendable {
    internal let id: UUID
    internal let name: String
    internal let notes: String
    internal let amount: Decimal
    internal let recurrenceIntervalMonths: Int
    internal let firstOccurrenceDate: Date
    internal let leadTimeMonths: Int
    internal let categoryId: UUID?
    internal let savingStrategy: SpecialPaymentSavingStrategy
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
        leadTimeMonths: Int,
        categoryId: UUID?,
        savingStrategy: SpecialPaymentSavingStrategy,
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
        self.leadTimeMonths = leadTimeMonths
        self.categoryId = categoryId
        self.savingStrategy = savingStrategy
        self.customMonthlySavingAmount = customMonthlySavingAmount
        self.dateAdjustmentPolicy = dateAdjustmentPolicy
        self.recurrenceDayPattern = recurrenceDayPattern
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from definition: SpecialPaymentDefinition) {
        self.id = definition.id
        self.name = definition.name
        self.notes = definition.notes
        self.amount = definition.amount
        self.recurrenceIntervalMonths = definition.recurrenceIntervalMonths
        self.firstOccurrenceDate = definition.firstOccurrenceDate
        self.leadTimeMonths = definition.leadTimeMonths
        self.categoryId = definition.category?.id
        self.savingStrategy = definition.savingStrategy
        self.customMonthlySavingAmount = definition.customMonthlySavingAmount
        self.dateAdjustmentPolicy = definition.dateAdjustmentPolicy
        self.recurrenceDayPattern = definition.recurrenceDayPattern
        self.createdAt = definition.createdAt
        self.updatedAt = definition.updatedAt
    }
}
