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
        let (transactions, categories) = createSampleTransactionsWithCategories()
        let year = 2025
        let month = 11

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            categories: categories,
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
        let (transactions, categories) = createSampleTransactionsWithCategories()
        let year = 2025

        // When
        let result = aggregator.aggregateAnnually(
            transactions: transactions,
            categories: categories,
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
        let (transactions, categories) = createSampleTransactionsWithCategories()

        // When
        let result = aggregator.aggregateByCategory(transactions: transactions, categories: categories)

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
        var (transactions, categories) = createSampleTransactionsWithCategories()
        // 計算対象外の取引を追加
        let excludedTx = createTransactionDTO(
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
            categories: categories,
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
        var (transactions, categories) = createSampleTransactionsWithCategories()
        // 振替取引を追加
        let transferTx = createTransactionDTO(
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
            categories: categories,
            year: 2025,
            month: 11,
            filter: filter,
        )

        // Then
        // 振替取引は集計に含まれない
        #expect(result.transactionCount == transactions.count - 1)
    }

    @Test("フィルタ：定期支払いとリンクされた取引を除外")
    internal func filter_excludeRecurringPaymentLinkedTransactions() throws {
        // Given
        var (transactions, categories) = createSampleTransactionsWithCategories()

        // 定期支払いとリンクされた取引を追加
        let linkedTx1 = createTransactionDTO(amount: -10000)
        let linkedTx2 = createTransactionDTO(amount: -5000)
        transactions.append(linkedTx1)
        transactions.append(linkedTx2)

        // 定期支払いとリンクされた取引を除外するフィルタ
        let filter = AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            excludedTransactionIds: Set([linkedTx1.id, linkedTx2.id])
        )

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            categories: categories,
            year: 2025,
            month: 11,
            filter: filter,
        )

        // Then
        // 定期支払いとリンクされた取引は集計に含まれない
        #expect(result.transactionCount == transactions.count - 2)

        // 除外された取引の金額は集計額に含まれていない
        let expectedExpense = transactions
            .filter { !filter.excludedTransactionIds.contains($0.id) }
            .filter { $0.amount < 0 }
            .reduce(Decimal.zero) { $0 + abs($1.amount) }
        #expect(result.totalExpense == expectedExpense)
    }

    // MARK: - Helper Methods

    private func createSampleTransactionsWithCategories() -> ([TransactionDTO], [CategoryDTO]) {
        let categoryId = UUID()
        let category = CategoryDTO(
            id: categoryId,
            name: "食費",
            displayOrder: 0,
            allowsAnnualBudget: false,
            parentId: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )

        let transactions = [
            createTransactionDTO(amount: 50000, categoryId: categoryId),
            createTransactionDTO(amount: -30000, categoryId: categoryId),
            createTransactionDTO(amount: -20000, categoryId: categoryId),
            createTransactionDTO(amount: 100_000, categoryId: categoryId),
            createTransactionDTO(amount: -15000, categoryId: categoryId),
        ]

        return (transactions, [category])
    }

    private func createTransactionDTO(
        amount: Decimal,
        categoryId: UUID? = nil,
        financialInstitutionId: UUID? = nil,
        isIncludedInCalculation: Bool = true,
        isTransfer: Bool = false,
    ) -> TransactionDTO {
        TransactionDTO(
            id: UUID(),
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            memo: "",
            isIncludedInCalculation: isIncludedInCalculation,
            isTransfer: isTransfer,
            financialInstitutionId: financialInstitutionId,
            majorCategoryId: categoryId,
            minorCategoryId: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )
    }
}
