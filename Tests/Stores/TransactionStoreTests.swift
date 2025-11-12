import Foundation
@testable import Kakeibo
import Testing

@Suite(.serialized)
@MainActor
internal struct TransactionStoreTests {
    @Test("初期化時に取引と参照データが読み込まれる")
    internal func initializationLoadsData() async {
        let transaction = Transaction(date: sampleMonth(), title: "ランチ", amount: -1200)
        let listUseCase = await TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        #expect(store.transactions.count == 1)
        #expect(store.availableInstitutions.count == 1)
        #expect(store.availableCategories.count == 2)
        let filters = await listUseCase.observedFilters
        #expect(filters.count == 2)
        #expect(filters.first?.month == store.currentMonth)
    }

    @Test("フィルタ変更でUseCaseが再実行される")
    internal func changingFiltersReloadsTransactions() async {
        let listUseCase = await TransactionListUseCaseStub(transactions: [])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        store.selectedFilterKind = .income

        let filters = await listUseCase.observedFilters
        #expect(filters.count == 3)
        #expect(filters.last?.filterKind == .income)
    }

    @Test("新規作成準備でフォームが初期化される")
    internal func prepareForNewTransactionInitializesForm() async {
        let listUseCase = await TransactionListUseCaseStub(transactions: [])
        let formUseCase = await TransactionFormUseCaseStub()
        let today = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { today })

        store.prepareForNewTransaction()

        #expect(store.formState.title.isEmpty)
        #expect(store.formState.date == today)
        #expect(store.isEditorPresented)
    }

    @Test("保存失敗時はエラーメッセージが表示される")
    internal func saveFailureUpdatesFormErrors() async {
        let listUseCase = await TransactionListUseCaseStub(transactions: [])
        let formUseCase = await TransactionFormUseCaseStub()
        nonisolated(unsafe) var formUseCaseMutable = formUseCase
        await DatabaseActor.run {
            formUseCaseMutable.saveError = TransactionFormError.validationFailed(["テストエラー"])
        }
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCaseMutable, clock: { sampleMonth() })

        let result = store.saveCurrentForm()

        #expect(result == false)
        #expect(store.formErrors == ["テストエラー"])
    }

    @Test("削除成功時に再読込が走る")
    internal func deleteTransactionRefreshesList() async {
        let transaction = Transaction(date: sampleMonth(), title: "外食", amount: -5000)
        let listUseCase = await TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        let transactionDTO = TransactionDTO(from: transaction)
        let result = await store.deleteTransaction(transactionDTO.id)

        #expect(result)
        let deletedIds = await formUseCase.deletedTransactionIds
        #expect(deletedIds.contains(transaction.id))
        let filters = await listUseCase.observedFilters
        #expect(filters.count == 4)
    }
}

// MARK: - Helpers

private extension TransactionStoreTests {
    func sampleMonth() -> Date {
        Date.from(year: 2025, month: 11) ?? Date()
    }
}

// MARK: - Stubs

@DatabaseActor
private final class TransactionListUseCaseStub: TransactionListUseCaseProtocol, @unchecked Sendable {
    internal var transactions: [TransactionDTO]
    internal var referenceData: TransactionReferenceData
    internal private(set) var receivedFilters: [TransactionListFilter] = []
    internal private(set) var observedFilters: [TransactionListFilter] = []

    internal init(transactions: [Transaction]) {
        self.transactions = transactions.map { TransactionDTO(from: $0) }
        let institution = FinancialInstitution(name: "メイン銀行")
        let major = Category(name: "食費", displayOrder: 1)
        let minor = Category(name: "外食", parent: major, displayOrder: 1)
        self.referenceData = TransactionReferenceData(
            institutions: [FinancialInstitutionDTO(from: institution)],
            categories: [CategoryDTO(from: major), CategoryDTO(from: minor)],
        )
    }

    internal func loadReferenceData() async throws -> TransactionReferenceData {
        referenceData
    }

    internal func loadTransactions(filter: TransactionListFilter) async throws -> [TransactionDTO] {
        receivedFilters.append(filter)
        return transactions
    }

    @discardableResult
    internal func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @MainActor ([TransactionDTO]) -> Void,
    ) async throws -> ObservationToken {
        observedFilters.append(filter)
        await onChange(transactions)
        return ObservationToken {}
    }
}

@DatabaseActor
private final class TransactionFormUseCaseStub: TransactionFormUseCaseProtocol, @unchecked Sendable {
    internal var saveError: Error?
    internal var deleteError: Error?
    internal private(set) var savedStates: [TransactionFormState] = []
    internal private(set) var deletedTransactionIds: [UUID] = []

    internal func save(
        state: TransactionFormState,
        editingTransactionId: UUID?,
        referenceData: TransactionReferenceData,
    ) async throws {
        if let saveError {
            throw saveError
        }
        savedStates.append(state)
    }

    internal func delete(transactionId: UUID) async throws {
        if let deleteError {
            throw deleteError
        }
        deletedTransactionIds.append(transactionId)
    }
}
