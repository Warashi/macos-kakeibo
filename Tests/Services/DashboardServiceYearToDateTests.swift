import Foundation
import Testing

@testable import Kakeibo

@Suite("DashboardService 年次積算の調整")
internal struct DashboardServiceYearToDateTests {
    @Test("貯蓄と積立を当月までの月数で年次積算する")
    internal func accumulatesSavingsAndRecurringUpToCurrentMonth() throws {
        let currentDate = try #require(Date.from(year: 2025, month: 10, day: 30))
        let monthPeriodCalculator = MonthPeriodCalculator(
            monthStartDay: 25,
            monthStartDayAdjustment: .none,
            businessDayService: BusinessDayService(),
        )
        let service = DashboardService(
            monthPeriodCalculator: monthPeriodCalculator,
            currentDateProvider: { currentDate },
        )

        let savingsGoal = SavingsGoal(
            id: UUID(),
            name: "貯蓄",
            targetAmount: nil,
            monthlySavingAmount: 1000,
            categoryId: nil,
            notes: nil,
            startDate: currentDate,
            targetDate: nil,
            isActive: true,
            createdAt: currentDate,
            updatedAt: currentDate,
        )

        let recurringDefinition = RecurringPaymentDefinition(
            id: UUID(),
            name: "積立",
            notes: "",
            amount: 2000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: currentDate,
            endDate: nil,
            categoryId: nil,
            savingStrategy: .customMonthly,
            customMonthlySavingAmount: 2000,
            dateAdjustmentPolicy: .none,
            recurrenceDayPattern: nil,
            matchKeywords: [],
            createdAt: currentDate,
            updatedAt: currentDate,
        )

        let snapshot = DashboardSnapshot(
            monthlyTransactions: [],
            annualTransactions: [],
            budgets: [],
            categories: [],
            config: nil,
            savingsGoals: [savingsGoal],
            savingsGoalBalances: [],
            recurringPaymentDefinitions: [recurringDefinition],
            recurringPaymentOccurrences: [],
            recurringPaymentBalances: [],
        )

        let result = service.calculate(
            snapshot: snapshot,
            year: 2025,
            month: 12,
            displayMode: .annual,
        )

        #expect(result.savingsSummary.yearToDateMonthlySavings == 10000)
        #expect(result.recurringPaymentSummary.yearToDateMonthlyAmount == 20000)
        #expect(result.annualSummary.totalSavings == 10000)
        #expect(result.annualSummary.recurringPaymentAllocation == 20000)
    }
}
