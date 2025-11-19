import Foundation
@testable import Kakeibo

internal enum DomainFixtures {
    internal static func category(
        id: UUID = UUID(),
        name: String = "カテゴリ",
        displayOrder: Int = 0,
        allowsAnnualBudget: Bool = false,
        parentId: UUID? = nil,
        parent: Kakeibo.Category? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> Kakeibo.Category {
        Kakeibo.Category(
            id: id,
            name: name,
            displayOrder: displayOrder,
            allowsAnnualBudget: allowsAnnualBudget,
            parentId: parent?.id ?? parentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func budget(
        id: UUID = UUID(),
        amount: Decimal = 10000,
        categoryId: UUID? = nil,
        category: Kakeibo.Category? = nil,
        startYear: Int = Date().year,
        startMonth: Int = Date().month,
        endYear: Int? = nil,
        endMonth: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> Budget {
        let resolvedEndYear = endYear ?? startYear
        let resolvedEndMonth = endMonth ?? startMonth
        return Budget(
            id: id,
            amount: amount,
            categoryId: category?.id ?? categoryId,
            startYear: startYear,
            startMonth: startMonth,
            endYear: resolvedEndYear,
            endMonth: resolvedEndMonth,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func transaction(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "取引",
        amount: Decimal = -1000,
        memo: String = "",
        isIncludedInCalculation: Bool = true,
        isTransfer: Bool = false,
        importIdentifier: String? = nil,
        financialInstitutionId: UUID? = nil,
        financialInstitution: FinancialInstitution? = nil,
        majorCategory: Kakeibo.Category? = nil,
        majorCategoryId: UUID? = nil,
        minorCategory: Kakeibo.Category? = nil,
        minorCategoryId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> Transaction {
        Transaction(
            id: id,
            date: date,
            title: title,
            amount: amount,
            memo: memo,
            isIncludedInCalculation: isIncludedInCalculation,
            isTransfer: isTransfer,
            importIdentifier: importIdentifier,
            financialInstitutionId: financialInstitution?.id ?? financialInstitutionId,
            majorCategoryId: majorCategory?.id ?? majorCategoryId,
            minorCategoryId: minorCategory?.id ?? minorCategoryId,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func financialInstitution(
        id: UUID = UUID(),
        name: String = "テスト銀行",
        displayOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> FinancialInstitution {
        FinancialInstitution(
            id: id,
            name: name,
            displayOrder: displayOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func annualBudgetAllocation(
        id: UUID = UUID(),
        amount: Decimal = 10000,
        category: Kakeibo.Category,
        policyOverride: AnnualBudgetPolicy? = nil,
        configId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> AnnualBudgetAllocation {
        AnnualBudgetAllocation(
            id: id,
            amount: amount,
            categoryId: category.id,
            policyOverride: policyOverride,
            configId: configId,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func annualBudgetConfig(
        id: UUID = UUID(),
        year: Int,
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy = .automatic,
        allocations: [AnnualBudgetAllocation] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> AnnualBudgetConfig {
        AnnualBudgetConfig(
            id: id,
            year: year,
            totalAmount: totalAmount,
            policy: policy,
            allocations: allocations,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func recurringPaymentDefinition(
        id: UUID = UUID(),
        name: String = "定期支払い",
        notes: String = "",
        amount: Decimal = 10000,
        recurrenceIntervalMonths: Int = 12,
        firstOccurrenceDate: Date = Date(),
        endDate: Date? = nil,
        leadTimeMonths: Int = 0,
        category: Kakeibo.Category? = nil,
        categoryId: UUID? = nil,
        savingStrategy: RecurringPaymentSavingStrategy = .evenlyDistributed,
        customMonthlySavingAmount: Decimal? = nil,
        dateAdjustmentPolicy: DateAdjustmentPolicy = .none,
        recurrenceDayPattern: DayOfMonthPattern? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> RecurringPaymentDefinition {
        RecurringPaymentDefinition(
            id: id,
            name: name,
            notes: notes,
            amount: amount,
            recurrenceIntervalMonths: recurrenceIntervalMonths,
            firstOccurrenceDate: firstOccurrenceDate,
            endDate: endDate,
            leadTimeMonths: leadTimeMonths,
            categoryId: category?.id ?? categoryId,
            savingStrategy: savingStrategy,
            customMonthlySavingAmount: customMonthlySavingAmount,
            dateAdjustmentPolicy: dateAdjustmentPolicy,
            recurrenceDayPattern: recurrenceDayPattern,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func recurringPaymentOccurrence(
        id: UUID = UUID(),
        definition: RecurringPaymentDefinition,
        scheduledDate: Date = Date(),
        expectedAmount: Decimal = 10000,
        status: RecurringPaymentStatus = .planned,
        actualDate: Date? = nil,
        actualAmount: Decimal? = nil,
        transactionId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> RecurringPaymentOccurrence {
        RecurringPaymentOccurrence(
            id: id,
            definitionId: definition.id,
            scheduledDate: scheduledDate,
            expectedAmount: expectedAmount,
            status: status,
            actualDate: actualDate,
            actualAmount: actualAmount,
            transactionId: transactionId,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

    internal static func recurringPaymentSavingBalance(
        id: UUID = UUID(),
        definition: RecurringPaymentDefinition,
        totalSavedAmount: Decimal = 0,
        totalPaidAmount: Decimal = 0,
        lastUpdatedYear: Int = Date().year,
        lastUpdatedMonth: Int = Date().month,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> RecurringPaymentSavingBalance {
        RecurringPaymentSavingBalance(
            id: id,
            definitionId: definition.id,
            totalSavedAmount: totalSavedAmount,
            totalPaidAmount: totalPaidAmount,
            lastUpdatedYear: lastUpdatedYear,
            lastUpdatedMonth: lastUpdatedMonth,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }
}
