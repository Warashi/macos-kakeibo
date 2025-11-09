import Foundation
import SwiftData
import Testing

@testable import Kakeibo

internal struct ReferenceData {
    internal let institution: FinancialInstitution
    internal let majorCategory: Kakeibo.Category
    internal let minorCategory: Kakeibo.Category
}

@Suite(.serialized)
@MainActor
internal struct TransactionStoreTests {
    @Test("初期化時に今月の取引だけが読み込まれる")
    internal func initializationLoadsCurrentMonthTransactions() throws {
        let (context, targetDate) = try prepareContext()
        let otherDate = Calendar.current.date(byAdding: .month, value: -1, to: targetDate) ?? targetDate

        context.insert(Transaction(date: targetDate, title: "ランチ", amount: -1200))
        context.insert(Transaction(date: otherDate, title: "先月ランチ", amount: -800))
        try context.save()

        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate

        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.title == "ランチ")
    }

    @Test("種別フィルタで収入のみ絞り込める")
    internal func filterByTransactionKind() throws {
        let (context, targetDate) = try prepareContext()
        context.insert(Transaction(date: targetDate, title: "給与", amount: 300_000))
        context.insert(Transaction(date: targetDate, title: "家賃", amount: -80000))
        try context.save()

        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate
        store.selectedFilterKind = .income

        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.isIncome == true)
    }

    @Test("検索キーワードでタイトルとメモを対象に絞り込める")
    internal func searchByKeyword() throws {
        let (context, targetDate) = try prepareContext()
        context.insert(Transaction(date: targetDate, title: "スタバ", amount: -640, memo: "カフェ"))
        context.insert(Transaction(date: targetDate, title: "スーパー", amount: -1200))
        try context.save()

        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate
        store.searchText = "カフェ"

        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.title == "スタバ")
    }

    @Test("新規取引を保存できる")
    internal func saveNewTransaction() throws {
        let (context, targetDate) = try prepareContext()
        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate

        store.prepareForNewTransaction()
        store.formState.title = "書籍"
        store.formState.amountText = "2800"
        store.formState.memo = "Swift本"
        store.formState.transactionKind = .expense
        store.formState.date = targetDate

        let result = store.saveCurrentForm()

        #expect(result)
        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.title == "書籍")
    }

    @Test("取引を削除できる")
    internal func deleteTransaction() throws {
        let (context, targetDate) = try prepareContext()
        let transaction = Transaction(date: targetDate, title: "外食", amount: -5000)
        context.insert(transaction)
        try context.save()

        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate

        #expect(store.transactions.count == 1)
        _ = store.deleteTransaction(transaction)
        #expect(store.transactions.isEmpty)
    }

    @Test("既存取引の編集が保存される")
    internal func editTransactionPersistsChanges() throws {
        let (context, targetDate) = try prepareContext()
        let refData = try seedReferenceData(in: context)

        let transaction = Transaction(
            date: targetDate,
            title: "昼食",
            amount: -800,
            memo: "Before",
            financialInstitution: refData.institution,
            majorCategory: refData.majorCategory,
            minorCategory: refData.minorCategory,
        )
        context.insert(transaction)
        try context.save()

        let store = TransactionStore(modelContext: context)
        store.currentMonth = targetDate

        store.startEditing(transaction: transaction)
        store.formState.title = "会食"
        store.formState.memo = "After"
        store.formState.amountText = "12,000"
        store.formState.transactionKind = .income
        store.formState.isIncludedInCalculation = false
        store.formState.isTransfer = true
        store.formState.financialInstitutionId = refData.institution.id
        store.formState.majorCategoryId = refData.majorCategory.id
        store.formState.minorCategoryId = refData.minorCategory.id

        let result = store.saveCurrentForm()

        #expect(result)
        #expect(transaction.title == "会食")
        #expect(transaction.amount == 12000)
        #expect(transaction.isIncludedInCalculation == false)
        #expect(transaction.isTransfer == true)
        #expect(transaction.financialInstitution?.id == refData.institution.id)
        #expect(transaction.majorCategory?.id == refData.majorCategory.id)
        #expect(transaction.minorCategory?.id == refData.minorCategory.id)
    }

    // MARK: - Helpers

    private func prepareContext() throws -> (ModelContext, Date) {
        let container = try ModelContainer(
            for: Transaction.self, Category.self, FinancialInstitution.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true),
        )
        let context = ModelContext(container)

        let targetDate = Date.from(year: 2025, month: 11) ?? Date()
        return (context, targetDate)
    }

    private func seedReferenceData(in context: ModelContext) throws -> ReferenceData {
        let institution = FinancialInstitution(name: "メイン銀行")
        let major = Kakeibo.Category(name: "食費", displayOrder: 1)
        let minor = Kakeibo.Category(name: "外食", parent: major, displayOrder: 1)
        context.insert(major)
        context.insert(minor)
        context.insert(institution)
        try context.save()
        return ReferenceData(institution: institution, majorCategory: major, minorCategory: minor)
    }
}
