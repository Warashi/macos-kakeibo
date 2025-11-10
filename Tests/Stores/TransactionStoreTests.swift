import Foundation
import Testing
@testable import Kakeibo

@Suite(.serialized)
@MainActor
internal struct TransactionStoreTests {
    @Test("初期化時に取引と参照データが読み込まれる")
    internal func initializationLoadsData() {
        let transaction = Transaction(date: sampleMonth(), title: "ランチ", amount: -1200)
        let listUseCase = TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        #expect(store.transactions.count == 1)
        #expect(store.availableInstitutions.count == 1)
        #expect(store.availableCategories.count == 2)
        #expect(listUseCase.observedFilters.count == 1)
        #expect(listUseCase.observedFilters.first?.month == store.currentMonth)
    }

    @Test("フィルタ変更でUseCaseが再実行される")
    internal func changingFiltersReloadsTransactions() {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        store.selectedFilterKind = .income

        #expect(listUseCase.observedFilters.count == 2)
        #expect(listUseCase.observedFilters.last?.filterKind == .income)
    }

    @Test("新規作成準備でフォームが初期化される")
    internal func prepareForNewTransactionInitializesForm() {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        let today = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { today })

        store.prepareForNewTransaction()

        #expect(store.formState.title.isEmpty)
        #expect(store.formState.date == today)
        #expect(store.isEditorPresented)
    }

    @Test("保存失敗時はエラーメッセージが表示される")
    internal func saveFailureUpdatesFormErrors() {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        formUseCase.saveError = TransactionFormError.validationFailed(["テストエラー"])
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        let result = store.saveCurrentForm()

        #expect(result == false)
        #expect(store.formErrors == ["テストエラー"])
    }

    @Test("削除成功時に再読込が走る")
    internal func deleteTransactionRefreshesList() {
        let transaction = Transaction(date: sampleMonth(), title: "外食", amount: -5000)
        let listUseCase = TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        let result = store.deleteTransaction(transaction)

        #expect(result)
        #expect(formUseCase.deletedTransactions.contains { $0.id == transaction.id })
        #expect(listUseCase.observedFilters.count == 2)
    }
}

// MARK: - Helpers

private extension TransactionStoreTests {
    func sampleMonth() -> Date {
        Date.from(year: 2025, month: 11) ?? Date()
    }
}

// MARK: - Stubs

private final class TransactionListUseCaseStub: TransactionListUseCaseProtocol {
    internal var transactions: [Transaction]
    internal var referenceData: TransactionReferenceData
    internal private(set) var receivedFilters: [TransactionListFilter] = []
    internal private(set) var observedFilters: [TransactionListFilter] = []

    internal init(transactions: [Transaction]) {
        self.transactions = transactions
        let institution = FinancialInstitution(name: "メイン銀行")
        let major = Category(name: "食費", displayOrder: 1)
        let minor = Category(name: "外食", parent: major, displayOrder: 1)
        self.referenceData = TransactionReferenceData(institutions: [institution], categories: [major, minor])
    }

    internal func loadReferenceData() throws -> TransactionReferenceData {
        referenceData
    }

    internal func loadTransactions(filter: TransactionListFilter) throws -> [Transaction] {
        receivedFilters.append(filter)
        return transactions
    }

    @discardableResult
    @MainActor
    internal func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([Transaction]) -> Void
    ) throws -> ObservationToken {
        observedFilters.append(filter)
        onChange(transactions)
        return ObservationToken {}
    }
}

private final class TransactionFormUseCaseStub: TransactionFormUseCaseProtocol {
    internal var saveError: Error?
    internal var deleteError: Error?
    internal private(set) var savedStates: [TransactionFormState] = []
    internal private(set) var deletedTransactions: [Transaction] = []

    internal func save(
        state: TransactionFormState,
        editingTransaction: Transaction?,
        referenceData: TransactionReferenceData
    ) throws {
        if let saveError {
            throw saveError
        }
        savedStates.append(state)
    }

    internal func delete(transaction: Transaction) throws {
        if let deleteError {
            throw deleteError
        }
        deletedTransactions.append(transaction)
    }
}
