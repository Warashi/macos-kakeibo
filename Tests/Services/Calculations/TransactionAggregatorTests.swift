import Foundation
import SwiftData
import Testing

@testable import Kakeibo

@Suite(.serialized)
internal struct TransactionAggregatorTests {
    private let aggregator: TransactionAggregator = TransactionAggregator()

    @Test("月次集計：正常ケース")
    internal func monthlySummary_success() throws {
        // Given
        let transactions = createSampleTransactions()
        let year = 2025
        let month = 11

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            year: year,
            month: month,
            filter: .default,
        )

        // Then
        #expect(result.year == year)
        #expect(result.month == month)
        #expect(result.totalIncome > 0)
        #expect(result.totalExpense > 0)
        #expect(result.transactionCount > 0)
    }

    @Test("年次集計：正常ケース")
    internal func annualSummary_success() throws {
        // Given
        let transactions = createSampleTransactions()
        let year = 2025

        // When
        let result = aggregator.aggregateAnnually(
            transactions: transactions,
            year: year,
            filter: .default,
        )

        // Then
        #expect(result.year == year)
        #expect(result.totalIncome > 0)
        #expect(result.totalExpense > 0)
        #expect(result.monthlySummaries.count == 12)
    }

    @Test("カテゴリ別集計：正常ケース")
    internal func aggregateByCategory_success() throws {
        // Given
        let transactions = createSampleTransactions()

        // When
        let result = aggregator.aggregateByCategory(transactions: transactions)

        // Then
        #expect(!result.isEmpty)
        // 支出額の降順でソートされているか確認
        for index in 0 ..< result.count - 1 {
            #expect(result[index].totalExpense >= result[index + 1].totalExpense)
        }
    }

    @Test("フィルタ：計算対象のみ")
    internal func filter_calculationTargetOnly() throws {
        // Given
        var transactions = createSampleTransactions()
        // 計算対象外の取引を追加
        let excludedTx = createTransaction(
            amount: 10000,
            isIncludedInCalculation: false,
        )
        transactions.append(excludedTx)

        let filter = AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: false,
        )

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            year: 2025,
            month: 11,
            filter: filter,
        )

        // Then
        // 計算対象外の取引は集計に含まれない
        #expect(result.transactionCount == transactions.count - 1)
    }

    @Test("フィルタ：振替除外")
    internal func filter_excludeTransfers() throws {
        // Given
        var transactions = createSampleTransactions()
        // 振替取引を追加
        let transferTx = createTransaction(
            amount: 5000,
            isTransfer: true,
        )
        transactions.append(transferTx)

        let filter = AggregationFilter(
            includeOnlyCalculationTarget: false,
            excludeTransfers: true,
        )

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            year: 2025,
            month: 11,
            filter: filter,
        )

        // Then
        // 振替取引は集計に含まれない
        #expect(result.transactionCount == transactions.count - 1)
    }

    // MARK: - Helper Methods

    private func createSampleTransactions() -> [Transaction] {
        let category = Category(name: "食費")
        let institution = FinancialInstitution(name: "銀行A")

        return [
            createTransaction(amount: 50000, category: category, institution: institution),
            createTransaction(amount: -30000, category: category, institution: institution),
            createTransaction(amount: -20000, category: category, institution: institution),
            createTransaction(amount: 100_000, category: category, institution: institution),
            createTransaction(amount: -15000, category: category, institution: institution),
        ]
    }

    private func createTransaction(
        amount: Decimal,
        category: Kakeibo.Category? = nil,
        institution: FinancialInstitution? = nil,
        isIncludedInCalculation: Bool = true,
        isTransfer: Bool = false,
    ) -> Transaction {
        Transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            isIncludedInCalculation: isIncludedInCalculation,
            isTransfer: isTransfer,
            financialInstitution: institution,
            majorCategory: category,
        )
    }
}
