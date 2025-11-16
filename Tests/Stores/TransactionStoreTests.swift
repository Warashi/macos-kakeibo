import Foundation
@testable import Kakeibo
import Testing

@Suite(.serialized)
@MainActor
internal struct TransactionStoreTests {
    @Test("初期化時に取引と参照データが読み込まれる")
    internal func initializationLoadsData() async {
        let transaction = TransactionDTO(
            id: UUID(),
            date: sampleMonth(),
            title: "ランチ",
            amount: -1200,
            memo: "",
            isIncludedInCalculation: true,
            isTransfer: false,
            importIdentifier: nil,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )
        let listUseCase = await TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        // 初期化の完了を待つ
        await store.refresh()

        #expect(store.transactions.count == 1)
        #expect(store.availableInstitutions.count == 1)
        #expect(store.availableCategories.count == 2)
        let filters = await Task { @DatabaseActor in
            listUseCase.observedFilters
        }.value
        #expect(filters.count == 2)
        #expect(filters.first?.month == store.currentMonth)
    }

    @Test("フィルタ変更でUseCaseが再実行される")
    internal func changingFiltersReloadsTransactions() async {
        let listUseCase = await TransactionListUseCaseStub(transactions: [])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        await store.refresh()
        store.selectedFilterKind = .income
        // フィルタ変更後の非同期処理の完了を待つ
        try? await Task.sleep(for: .milliseconds(10))

        let filters = await Task { @DatabaseActor in
            listUseCase.observedFilters
        }.value
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
        await Task { @DatabaseActor in
            formUseCase.saveError = TransactionFormError.validationFailed(["テストエラー"])
        }.value
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
        )

        let result = await store.saveCurrentForm()

        #expect(result == false)
        #expect(store.formErrors == ["テストエラー"])
    }

    @Test("削除成功時に再読込が走る")
    internal func deleteTransactionRefreshesList() async {
        let transaction = TransactionDTO(
            id: UUID(),
            date: sampleMonth(),
            title: "外食",
            amount: -5000,
            memo: "",
            isIncludedInCalculation: true,
            isTransfer: false,
            importIdentifier: nil,
            financialInstitutionId: nil,
            majorCategoryId: nil,
            minorCategoryId: nil,
            createdAt: Date(),
            updatedAt: Date(),
        )
        let listUseCase = await TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = await TransactionFormUseCaseStub()
        let store = TransactionStore(listUseCase: listUseCase, formUseCase: formUseCase, clock: { sampleMonth() })

        // 初期化Task の完了を待つ
        try? await Task.sleep(for: .milliseconds(10))
        await store.refresh()
        let result = await store.deleteTransaction(transaction.id)
        // deleteTransaction内でrefresh()が呼ばれるので、その完了を待つ
        try? await Task.sleep(for: .milliseconds(100))

        #expect(result)
        let deletedIds = await Task { @DatabaseActor in
            formUseCase.deletedTransactionIds
        }.value
        #expect(deletedIds.contains(transaction.id))
        let filters = await Task { @DatabaseActor in
            listUseCase.observedFilters
        }.value
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
    internal var receivedFilters: [TransactionListFilter] = []
    internal var observedFilters: [TransactionListFilter] = []

    internal init(transactions: [TransactionDTO]) {
        self.transactions = transactions
        let institution = FinancialInstitution(name: "メイン銀行")
        let major = CategoryEntity(name: "食費", displayOrder: 1)
        let minor = CategoryEntity(name: "外食", parent: major, displayOrder: 1)
        self.referenceData = TransactionReferenceData(
            institutions: [FinancialInstitution(from: institution)],
            categories: [Category(from: major), Category(from: minor)],
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
    internal var savedStates: [TransactionFormState] = []
    internal var deletedTransactionIds: [UUID] = []

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
