import Foundation
@testable import Kakeibo
import Testing

@Suite(.serialized)
@MainActor
internal struct TransactionStoreTests {
    @Test("初期化時に取引と参照データが読み込まれる")
    internal func initializationLoadsData() async {
        let transaction = Transaction(
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
        let listUseCase = TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
            appState: AppState(),
        )

        // 初期化の完了を待つ
        await store.refresh()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(store.transactions.count == 1)
        #expect(store.availableInstitutions.count == 1)
        #expect(store.availableCategories.count == 2)
        let filters = await listUseCase.observedFiltersHistory()
        #expect(filters.count == 2)
        #expect(filters.first?.month == store.currentMonth)
    }

    @Test("refreshはバックグラウンドTaskからでも取引を読み込む")
    internal func refreshLoadsTransactionsFromDetachedTask() async {
        let transaction = Transaction(
            id: UUID(),
            date: sampleMonth(),
            title: "テスト取引",
            amount: -500,
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
        let listUseCase = TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
            appState: AppState(),
        )

        let backgroundTask = Task.detached {
            await store.refresh()
        }
        await backgroundTask.value
        try? await Task.sleep(for: .milliseconds(10))

        #expect(store.transactions.count == 1)
        #expect(store.transactions.first?.id == transaction.id)
    }

    @Test("フィルタ変更でUseCaseが再実行される")
    internal func changingFiltersReloadsTransactions() async {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
            appState: AppState(),
        )

        await store.refresh()
        store.selectedFilterKind = .income
        // フィルタ変更後の非同期処理の完了を待つ
        try? await Task.sleep(for: .milliseconds(10))

        let filters = await listUseCase.observedFiltersHistory()
        #expect(filters.count == 3)
        #expect(filters.last?.filterKind == .income)
    }

    @Test("新規作成準備でフォームが初期化される")
    internal func prepareForNewTransactionInitializesForm() async {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        let today = Date.from(year: 2025, month: 11, day: 15) ?? Date()
        let appState = AppState()
        appState.sharedYear = Calendar.current.component(.year, from: today)
        appState.sharedMonth = Calendar.current.component(.month, from: today)
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { today },
            appState: appState,
        )

        store.prepareForNewTransaction()

        #expect(store.formState.title.isEmpty)
        #expect(store.formState.date == today)
        #expect(store.isEditorPresented)
    }

    @Test("保存失敗時はエラーメッセージが表示される")
    internal func saveFailureUpdatesFormErrors() async {
        let listUseCase = TransactionListUseCaseStub(transactions: [])
        let formUseCase = TransactionFormUseCaseStub()
        await formUseCase.setSaveError(TransactionFormError.validationFailed(["テストエラー"]))
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
            appState: AppState(),
        )

        let result = await store.saveCurrentForm()

        #expect(result == false)
        #expect(store.formErrors == ["テストエラー"])
    }

    @Test("削除成功時に再読込が走る")
    internal func deleteTransactionRefreshesList() async {
        let transaction = Transaction(
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
        let listUseCase = TransactionListUseCaseStub(transactions: [transaction])
        let formUseCase = TransactionFormUseCaseStub()
        let store = TransactionStore(
            listUseCase: listUseCase,
            formUseCase: formUseCase,
            clock: { sampleMonth() },
            appState: AppState(),
        )

        // 初期化Task の完了を待つ
        try? await Task.sleep(for: .milliseconds(10))
        await store.refresh()
        let result = await store.deleteTransaction(transaction.id)
        // deleteTransaction内でrefresh()が呼ばれるので、その完了を待つ
        try? await Task.sleep(for: .milliseconds(100))

        #expect(result)
        let deletedIds = await formUseCase.deletedTransactionIdsHistory()
        #expect(deletedIds.contains(transaction.id))
        let filters = await listUseCase.observedFiltersHistory()
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

private actor TransactionListUseCaseStub: TransactionListUseCaseProtocol {
    private let transactions: [Transaction]
    private let referenceData: TransactionReferenceData
    private var receivedFilters: [TransactionListFilter] = []
    private var observedFilters: [TransactionListFilter] = []

    internal init(transactions: [Transaction]) {
        self.transactions = transactions
        let institution = SwiftDataFinancialInstitution(name: "メイン銀行")
        let major = SwiftDataCategory(name: "食費", displayOrder: 1)
        let minor = SwiftDataCategory(name: "外食", parent: major, displayOrder: 1)
        self.referenceData = TransactionReferenceData(
            institutions: [FinancialInstitution(from: institution)],
            categories: [Category(from: major), Category(from: minor)],
        )
    }

    internal func loadReferenceData() async throws -> TransactionReferenceData {
        referenceData
    }

    internal func loadTransactions(filter: TransactionListFilter) async throws -> [Transaction] {
        receivedFilters.append(filter)
        return transactions
    }

    @discardableResult
    internal func observeTransactions(
        filter: TransactionListFilter,
        onChange: @escaping @Sendable ([Transaction]) -> Void,
    ) async throws -> ObservationHandle {
        observedFilters.append(filter)
        onChange(transactions)
        return ObservationHandle(token: ObservationToken {})
    }

    internal func observedFiltersHistory() -> [TransactionListFilter] {
        observedFilters
    }
}

private actor TransactionFormUseCaseStub: TransactionFormUseCaseProtocol {
    private var saveError: Error?
    private var deleteError: Error?
    private var savedStates: [TransactionFormState] = []
    private var deletedTransactionIds: [UUID] = []

    internal func setSaveError(_ error: Error?) {
        saveError = error
    }

    internal func setDeleteError(_ error: Error?) {
        deleteError = error
    }

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

    internal func deletedTransactionIdsHistory() -> [UUID] {
        deletedTransactionIds
    }
}
