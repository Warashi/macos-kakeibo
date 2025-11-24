import Foundation

// SwiftDataモデルからBackup DTOへの変換

extension BackupTransactionDTO {
    internal init(transaction: SwiftDataTransaction) {
        self.init(
            id: transaction.id,
            date: transaction.date,
            title: transaction.title,
            amount: transaction.amount,
            memo: transaction.memo,
            isIncludedInCalculation: transaction.isIncludedInCalculation,
            isTransfer: transaction.isTransfer,
            financialInstitutionId: transaction.financialInstitution?.id,
            majorCategoryId: transaction.majorCategory?.id,
            minorCategoryId: transaction.minorCategory?.id,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt,
        )
    }
}

extension BackupCategory {
    internal init(category: SwiftDataCategory) {
        self.init(
            id: category.id,
            name: category.name,
            parentId: category.parent?.id,
            allowsAnnualBudget: category.allowsAnnualBudget,
            displayOrder: category.displayOrder,
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
        )
    }
}

extension BackupBudgetDTO {
    internal init(budget: SwiftDataBudget) {
        self.init(
            id: budget.id,
            amount: budget.amount,
            categoryId: budget.category?.id,
            startYear: budget.startYear,
            startMonth: budget.startMonth,
            endYear: budget.endYear,
            endMonth: budget.endMonth,
            createdAt: budget.createdAt,
            updatedAt: budget.updatedAt,
        )
    }
}

extension BackupAnnualBudgetConfig {
    internal init(config: SwiftDataAnnualBudgetConfig) {
        self.init(
            id: config.id,
            year: config.year,
            totalAmount: config.totalAmount,
            policyRawValue: config.policy.rawValue,
            createdAt: config.createdAt,
            updatedAt: config.updatedAt,
        )
    }
}

extension BackupFinancialInstitutionDTO {
    internal init(institution: SwiftDataFinancialInstitution) {
        self.init(
            id: institution.id,
            name: institution.name,
            displayOrder: institution.displayOrder,
            createdAt: institution.createdAt,
            updatedAt: institution.updatedAt,
        )
    }
}

extension BackupAnnualBudgetAllocationDTO {
    internal init(allocation: SwiftDataAnnualBudgetAllocation) {
        self.init(
            id: allocation.id,
            amount: allocation.amount,
            categoryId: allocation.category.id,
            policyOverrideRawValue: allocation.policyOverrideRawValue,
            configId: allocation.config?.id,
            createdAt: allocation.createdAt,
            updatedAt: allocation.updatedAt,
        )
    }
}

extension BackupRecurringPaymentDefinitionDTO {
    internal init(definition: SwiftDataRecurringPaymentDefinition) {
        self.init(
            id: definition.id,
            name: definition.name,
            notes: definition.notes,
            amount: definition.amount,
            recurrenceIntervalMonths: definition.recurrenceIntervalMonths,
            firstOccurrenceDate: definition.firstOccurrenceDate,
            endDate: definition.endDate,
            categoryId: definition.category?.id,
            savingStrategy: definition.savingStrategy,
            customMonthlySavingAmount: definition.customMonthlySavingAmount,
            dateAdjustmentPolicy: definition.dateAdjustmentPolicy,
            recurrenceDayPattern: definition.recurrenceDayPattern,
            createdAt: definition.createdAt,
            updatedAt: definition.updatedAt,
        )
    }
}

extension BackupRecurringPaymentOccurrenceDTO {
    internal init(occurrence: SwiftDataRecurringPaymentOccurrence) {
        self.init(
            id: occurrence.id,
            definitionId: occurrence.definitionId,
            scheduledDate: occurrence.scheduledDate,
            expectedAmount: occurrence.expectedAmount,
            status: occurrence.status,
            actualDate: occurrence.actualDate,
            actualAmount: occurrence.actualAmount,
            transactionId: occurrence.transaction?.id,
            createdAt: occurrence.createdAt,
            updatedAt: occurrence.updatedAt,
        )
    }
}

extension BackupRecurringPaymentSavingBalanceDTO {
    internal init(balance: SwiftDataRecurringPaymentSavingBalance) {
        self.init(
            id: balance.id,
            definitionId: balance.definition.id,
            totalSavedAmount: balance.totalSavedAmount,
            totalPaidAmount: balance.totalPaidAmount,
            lastUpdatedYear: balance.lastUpdatedYear,
            lastUpdatedMonth: balance.lastUpdatedMonth,
            createdAt: balance.createdAt,
            updatedAt: balance.updatedAt,
        )
    }
}

extension BackupCustomHolidayDTO {
    internal init(holiday: SwiftDataCustomHoliday) {
        self.init(
            id: holiday.id,
            date: holiday.date,
            name: holiday.name,
            isRecurring: holiday.isRecurring,
            createdAt: holiday.createdAt,
            updatedAt: holiday.updatedAt,
        )
    }
}
