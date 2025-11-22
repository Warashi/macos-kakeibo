import Foundation
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
        let linkedTx1 = createTransaction(amount: -10000)
        let linkedTx2 = createTransaction(amount: -5000)
        transactions.append(linkedTx1)
        transactions.append(linkedTx2)

        // 定期支払いとリンクされた取引を除外するフィルタ
        let filter = AggregationFilter(
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            excludedTransactionIds: Set([linkedTx1.id, linkedTx2.id]),
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

    @Test("貯蓄を含む月次集計")
    internal func monthlySummary_withSavings() throws {
        // Given
        let (transactions, categories) = createSampleTransactionsWithCategories()
        let savingsGoals = createSampleSavingsGoals()
        let year = 2025
        let month = 11

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            categories: categories,
            year: year,
            month: month,
            filter: .default,
            savingsGoals: savingsGoals,
        )

        // Then
        #expect(result.year == year)
        #expect(result.month == month)
        #expect(result.totalSavings == 60000) // 10000 + 50000
        // net = totalIncome - totalExpense - totalSavings
        #expect(result.net == result.totalIncome - result.totalExpense - 60000)
    }

    @Test("非アクティブな貯蓄目標は集計に含まれない")
    internal func monthlySummary_inactiveSavingsExcluded() throws {
        // Given
        let (transactions, categories) = createSampleTransactionsWithCategories()
        var savingsGoals = createSampleSavingsGoals()

        // 2つ目の貯蓄目標を非アクティブに
        savingsGoals[1] = SavingsGoal(
            id: savingsGoals[1].id,
            name: savingsGoals[1].name,
            targetAmount: savingsGoals[1].targetAmount,
            monthlySavingAmount: savingsGoals[1].monthlySavingAmount,
            categoryId: savingsGoals[1].categoryId,
            notes: savingsGoals[1].notes,
            startDate: savingsGoals[1].startDate,
            targetDate: savingsGoals[1].targetDate,
            isActive: false, // 非アクティブ
            createdAt: savingsGoals[1].createdAt,
            updatedAt: savingsGoals[1].updatedAt,
        )

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            categories: categories,
            year: 2025,
            month: 11,
            filter: .default,
            savingsGoals: savingsGoals,
        )

        // Then
        #expect(result.totalSavings == 10000) // アクティブな目標のみ
    }

    @Test("貯蓄目標がない場合は総貯蓄額が0")
    internal func monthlySummary_noSavingsGoals() throws {
        // Given
        let (transactions, categories) = createSampleTransactionsWithCategories()
        let savingsGoals: [SavingsGoal] = []

        // When
        let result = aggregator.aggregateMonthly(
            transactions: transactions,
            categories: categories,
            year: 2025,
            month: 11,
            filter: .default,
            savingsGoals: savingsGoals,
        )

        // Then
        #expect(result.totalSavings == 0)
        #expect(result.net == result.totalIncome - result.totalExpense)
    }

    @Test("年次集計：貯蓄を含む")
    internal func annualSummary_withSavings() throws {
        // Given
        let (transactions, categories) = createSampleTransactionsWithCategories()
        let savingsGoals = createSampleSavingsGoals()
        let year = 2025

        // When
        let result = aggregator.aggregateAnnually(
            transactions: transactions,
            categories: categories,
            year: year,
            filter: .default,
            savingsGoals: savingsGoals,
        )

        // Then
        #expect(result.year == year)
        #expect(result.totalSavings == 720_000) // (10000 + 50000) * 12ヶ月
        #expect(result.net == result.totalIncome - result.totalExpense - 720_000)
        #expect(result.monthlySummaries.count == 12)
        // 各月の貯蓄額を確認
        for monthlySummary in result.monthlySummaries {
            #expect(monthlySummary.totalSavings == 60000)
        }
    }

    // MARK: - Helper Methods

    private func createSampleTransactionsWithCategories() -> ([Transaction], [Kakeibo.Category]) {
        let categoryId = UUID()
        let category = DomainFixtures.category(
            id: categoryId,
            name: "食費",
            allowsAnnualBudget: false,
        )

        let transactions = [
            createTransaction(amount: 50000, categoryId: categoryId),
            createTransaction(amount: -30000, categoryId: categoryId),
            createTransaction(amount: -20000, categoryId: categoryId),
            createTransaction(amount: 100_000, categoryId: categoryId),
            createTransaction(amount: -15000, categoryId: categoryId),
        ]

        return (transactions, [category])
    }

    private func createTransaction(
        amount: Decimal,
        categoryId: UUID? = nil,
        financialInstitutionId: UUID? = nil,
        isIncludedInCalculation: Bool = true,
        isTransfer: Bool = false,
    ) -> Transaction {
        DomainFixtures.transaction(
            date: Date.from(year: 2025, month: 11) ?? Date(),
            title: "テスト取引",
            amount: amount,
            memo: "",
            isIncludedInCalculation: isIncludedInCalculation,
            isTransfer: isTransfer,
            financialInstitutionId: financialInstitutionId,
            majorCategoryId: categoryId,
        )
    }

    private func createSampleSavingsGoals() -> [SavingsGoal] {
        [
            SavingsGoal(
                id: UUID(),
                name: "緊急費用",
                targetAmount: nil,
                monthlySavingAmount: 10000,
                categoryId: nil,
                notes: nil,
                startDate: Date(),
                targetDate: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
            ),
            SavingsGoal(
                id: UUID(),
                name: "旅行積立",
                targetAmount: 500_000,
                monthlySavingAmount: 50000,
                categoryId: nil,
                notes: nil,
                startDate: Date(),
                targetDate: nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
            ),
        ]
    }
}
