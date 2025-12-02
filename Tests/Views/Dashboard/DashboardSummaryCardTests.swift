import Testing

@testable import Kakeibo

@Suite("DashboardSummaryCard Tests")
@MainActor
internal struct DashboardSummaryCardTests {
    @Test("年次表示では積立が年初から当月までの合計になる")
    internal func annualModeShowsYearToDateRecurringSavings() {
        let monthlySummary = MonthlySummary(
            year: 2025,
            month: 10,
            totalIncome: 0,
            totalExpense: 0,
            totalSavings: 0,
            recurringPaymentAllocation: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
        )

        let annualSummary = AnnualSummary(
            year: 2025,
            totalIncome: 0,
            totalExpense: 0,
            totalSavings: 0,
            recurringPaymentAllocation: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
            monthlySummaries: [],
        )

        let recurringSummary = RecurringPaymentSummary(
            totalMonthlyAmount: 1000,
            yearToDateMonthlyAmount: 5000,
            currentMonthExpected: 0,
            currentMonthActual: 0,
            currentMonthRemaining: 0,
            definitions: [],
        )

        let card = DashboardSummaryCard(
            displayMode: .annual,
            monthlySummary: monthlySummary,
            annualSummary: annualSummary,
            monthlyBudgetCalculation: MonthlyBudgetCalculation(
                year: 2025,
                month: 10,
                overallCalculation: nil,
                categoryCalculations: [],
            ),
            annualBudgetProgress: nil,
            recurringPaymentSummary: recurringSummary,
        )

        let recurringMetric = card.summaryMetricsForTesting.first { $0.title == "積立" }
        #expect(recurringMetric?.amount == recurringSummary.yearToDateMonthlyAmount)
    }
}
