import Foundation

internal extension Budget {
    init(from record: SwiftDataBudget) {
        self.init(
            id: record.id,
            amount: record.amount,
            categoryId: record.category?.id,
            startYear: record.startYear,
            startMonth: record.startMonth,
            endYear: record.endYear,
            endMonth: record.endMonth,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension Category {
    init(from record: SwiftDataCategory) {
        self.init(
            id: record.id,
            name: record.name,
            displayOrder: record.displayOrder,
            allowsAnnualBudget: record.allowsAnnualBudget,
            parentId: record.parent?.id,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension Transaction {
    init(from record: SwiftDataTransaction) {
        self.init(
            id: record.id,
            date: record.date,
            title: record.title,
            amount: record.amount,
            memo: record.memo,
            isIncludedInCalculation: record.isIncludedInCalculation,
            isTransfer: record.isTransfer,
            importIdentifier: record.importIdentifier,
            financialInstitutionId: record.financialInstitution?.id,
            majorCategoryId: record.majorCategory?.id,
            minorCategoryId: record.minorCategory?.id,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension FinancialInstitution {
    init(from record: SwiftDataFinancialInstitution) {
        self.init(
            id: record.id,
            name: record.name,
            displayOrder: record.displayOrder,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension AnnualBudgetAllocation {
    init(from record: SwiftDataAnnualBudgetAllocation) {
        self.init(
            id: record.id,
            amount: record.amount,
            categoryId: record.category.id,
            policyOverride: record.policyOverride,
            configId: record.config?.id,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension AnnualBudgetConfig {
    init(from record: SwiftDataAnnualBudgetConfig) {
        self.init(
            id: record.id,
            year: record.year,
            totalAmount: record.totalAmount,
            policy: record.policy,
            allocations: record.allocations.map { AnnualBudgetAllocation(from: $0) },
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension RecurringPaymentDefinition {
    init(from record: SwiftDataRecurringPaymentDefinition) {
        self.init(
            id: record.id,
            name: record.name,
            notes: record.notes,
            amount: record.amount,
            recurrenceIntervalMonths: record.recurrenceIntervalMonths,
            firstOccurrenceDate: record.firstOccurrenceDate,
            endDate: record.endDate,
            leadTimeMonths: record.leadTimeMonths,
            categoryId: record.category?.id,
            savingStrategy: record.savingStrategy,
            customMonthlySavingAmount: record.customMonthlySavingAmount,
            dateAdjustmentPolicy: record.dateAdjustmentPolicy,
            recurrenceDayPattern: record.recurrenceDayPattern,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension RecurringPaymentOccurrence {
    init(from record: SwiftDataRecurringPaymentOccurrence) {
        self.init(
            id: record.id,
            definitionId: record.definition.id,
            scheduledDate: record.scheduledDate,
            expectedAmount: record.expectedAmount,
            status: record.status,
            actualDate: record.actualDate,
            actualAmount: record.actualAmount,
            transactionId: record.transaction?.id,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}

internal extension RecurringPaymentSavingBalance {
    init(from record: SwiftDataRecurringPaymentSavingBalance) {
        self.init(
            id: record.id,
            definitionId: record.definition.id,
            totalSavedAmount: record.totalSavedAmount,
            totalPaidAmount: record.totalPaidAmount,
            lastUpdatedYear: record.lastUpdatedYear,
            lastUpdatedMonth: record.lastUpdatedMonth,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
        )
    }
}
