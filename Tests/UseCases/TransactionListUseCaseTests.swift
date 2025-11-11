import Foundation
@testable import Kakeibo
import Testing

@Suite(.serialized)
internal struct TransactionListUseCaseTests {
    @Test("指定した月の取引のみ取得する")
    internal func fetchesOnlySelectedMonth() throws {
        let targetMonth = Date.from(year: 2025, month: 11) ?? Date()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: targetMonth) ?? targetMonth
        let repository = InMemoryTransactionRepository(
            transactions: [
                Transaction(date: targetMonth, title: "今月のランチ", amount: -1200),
                Transaction(date: previousMonth, title: "先月のランチ", amount: -800),
            ],
        )
        let useCase = DefaultTransactionListUseCase(repository: repository)

        let result = try useCase.loadTransactions(filter: makeFilter(month: targetMonth))

        #expect(result.count == 1)
        #expect(result.first?.title == "今月のランチ")
    }

    @Test("収入種別で絞り込める")
    internal func filtersByTransactionKind() throws {
        let targetMonth = Date.from(year: 2025, month: 11) ?? Date()
        let repository = InMemoryTransactionRepository(
            transactions: [
                Transaction(date: targetMonth, title: "給与", amount: 300_000),
                Transaction(date: targetMonth, title: "家賃", amount: -80000),
            ],
        )
        let useCase = DefaultTransactionListUseCase(repository: repository)

        var filter = makeFilter(month: targetMonth)
        filter.filterKind = .income

        let result = try useCase.loadTransactions(filter: filter)

        #expect(result.count == 1)
        #expect(result.first?.title == "給与")
    }

    @Test("検索キーワードでタイトルとメモを対象に絞り込める")
    internal func filtersByKeyword() throws {
        let targetMonth = Date.from(year: 2025, month: 11) ?? Date()
        let repository = InMemoryTransactionRepository(
            transactions: [
                Transaction(date: targetMonth, title: "スタバ", amount: -640, memo: "カフェ", isIncludedInCalculation: true),
                Transaction(date: targetMonth, title: "スーパー", amount: -1200),
            ],
        )
        let useCase = DefaultTransactionListUseCase(repository: repository)

        var filter = makeFilter(month: targetMonth)
        filter.searchText = SearchText("カフェ")

        let result = try useCase.loadTransactions(filter: filter)

        #expect(result.count == 1)
        #expect(result.first?.title == "スタバ")
    }

    @Test("参照データをまとめて取得できる")
    internal func loadsReferenceData() throws {
        let institution = FinancialInstitution(name: "メイン銀行")
        let major = Category(name: "食費", displayOrder: 1)
        let minor = Category(name: "外食", parent: major, displayOrder: 1)
        let repository = InMemoryTransactionRepository(
            institutions: [institution],
            categories: [major, minor],
        )
        let useCase = DefaultTransactionListUseCase(repository: repository)

        let reference = try useCase.loadReferenceData()

        #expect(reference.institutions.count == 1)
        #expect(reference.categories.count == 2)
        #expect(reference.categories.first?.name == "食費")
    }
}

private extension TransactionListUseCaseTests {
    func makeFilter(month: Date) -> TransactionListFilter {
        TransactionListFilter(
            month: month,
            searchText: SearchText(),
            filterKind: .all,
            institutionId: nil,
            categoryFilter: .init(majorCategoryId: nil, minorCategoryId: nil),
            includeOnlyCalculationTarget: true,
            excludeTransfers: true,
            sortOption: .dateDescending,
        )
    }
}
