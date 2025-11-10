import Foundation
import Observation
import SwiftData

/// 取引一覧画面用のストア
///
/// - 検索やフィルタの状態管理
/// - 取引のCRUD操作
/// - 金額サマリの計算
@Observable
@MainActor
internal final class TransactionStore {
    // MARK: - Nested Types

    /// 日毎の取引セクション
    internal struct TransactionSection: Identifiable {
        internal let date: Date
        internal let transactions: [Transaction]

        internal var id: Date { date }
        internal var title: String { date.longDateFormatted }
    }

    // MARK: - Properties

    private let listUseCase: TransactionListUseCaseProtocol
    private let formUseCase: TransactionFormUseCaseProtocol
    private let clock: () -> Date
    @ObservationIgnored
    private var transactionsToken: ObservationToken?

    internal var transactions: [Transaction] = []
    internal var searchText: String = "" {
        didSet { reloadTransactions() }
    }

    internal var selectedFilterKind: TransactionFilterKind = .all {
        didSet { reloadTransactions() }
    }

    internal var selectedInstitutionId: UUID? {
        didSet { reloadTransactions() }
    }

    internal var selectedMajorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMajorCategoryId else { return }
            if selectedMajorCategoryId == nil {
                selectedMinorCategoryId = nil
            } else if let minorId = selectedMinorCategoryId,
                      referenceData.category(id: minorId)?.parent?.id != selectedMajorCategoryId {
                selectedMinorCategoryId = nil
            }
            reloadTransactions()
        }
    }

    internal var selectedMinorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMinorCategoryId else { return }
            reloadTransactions()
        }
    }

    internal var includeOnlyCalculationTarget: Bool = true {
        didSet { reloadTransactions() }
    }

    internal var excludeTransfers: Bool = true {
        didSet { reloadTransactions() }
    }

    internal var sortOption: TransactionSortOption = .dateDescending {
        didSet { reloadTransactions() }
    }

    internal var currentMonth: Date {
        didSet {
            let normalized = currentMonth.startOfMonth
            if currentMonth != normalized {
                currentMonth = normalized
                return
            }
            reloadTransactions()
        }
    }

    internal private(set) var availableInstitutions: [FinancialInstitution] = []
    internal private(set) var availableCategories: [Category] = []
    internal var listErrorMessage: String?

    internal var isEditorPresented: Bool = false
    internal private(set) var editingTransaction: Transaction?
    internal var formState: TransactionFormState
    internal var formErrors: [String] = []

    private var referenceData: TransactionReferenceData {
        TransactionReferenceData(institutions: availableInstitutions, categories: availableCategories)
    }

    // MARK: - Initialization

    internal convenience init(modelContext: ModelContext) {
        let repository = SwiftDataTransactionRepository(modelContext: modelContext)
        let listUseCase = DefaultTransactionListUseCase(repository: repository)
        let formUseCase = DefaultTransactionFormUseCase(repository: repository)
        self.init(listUseCase: listUseCase, formUseCase: formUseCase)
    }

    internal init(
        listUseCase: TransactionListUseCaseProtocol,
        formUseCase: TransactionFormUseCaseProtocol,
        clock: @escaping () -> Date = Date.init
    ) {
        self.listUseCase = listUseCase
        self.formUseCase = formUseCase
        self.clock = clock
        let now = clock()
        self.currentMonth = now.startOfMonth
        self.formState = .empty(defaultDate: now)
        refresh()
    }

    deinit {
        transactionsToken?.cancel()
    }
}

// MARK: - Public API

internal extension TransactionStore {
    /// 参照データと取引を再取得
    func refresh() {
        loadReferenceData()
        reloadTransactions()
    }

    /// 現在の月ラベル
    var currentMonthLabel: String {
        currentMonth.yearMonthFormatted
    }

    /// 収入合計
    var totalIncome: Decimal {
        transactions
            .filter(\.isIncome)
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    /// 支出合計（正の値）
    var totalExpense: Decimal {
        transactions
            .filter(\.isExpense)
            .reduce(into: Decimal.zero) { $0 += abs($1.amount) }
    }

    /// 差引（収入 - 支出）
    var netAmount: Decimal {
        totalIncome - totalExpense
    }

    /// セクション化された取引
    var sections: [TransactionSection] {
        var order: [Date] = []
        var grouped: [Date: [Transaction]] = [:]
        for transaction in transactions {
            let day = Calendar.current.startOfDay(for: transaction.date)
            if grouped[day] == nil {
                order.append(day)
            }
            grouped[day, default: []].append(transaction)
        }

        return order.compactMap { day in
            guard let entries = grouped[day] else { return nil }
            return TransactionSection(date: day, transactions: entries)
        }
    }

    /// 大項目一覧
    var majorCategories: [Category] {
        availableCategories
            .filter(\.isMajor)
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.name < rhs.name
                }
                return lhs.displayOrder < rhs.displayOrder
            }
    }

    /// 指定した大項目に紐づく中項目一覧
    func minorCategories(for majorCategoryId: UUID?) -> [Category] {
        guard let majorCategoryId else { return [] }
        return availableCategories
            .filter { $0.parent?.id == majorCategoryId }
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.name < rhs.name
                }
                return lhs.displayOrder < rhs.displayOrder
            }
    }

    /// 月を前に移動
    func moveToPreviousMonth() {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        currentMonth = previous
    }

    /// 月を次に移動
    func moveToNextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        currentMonth = next
    }

    /// 今月に戻る
    func moveToCurrentMonth() {
        currentMonth = clock().startOfMonth
    }

    /// フィルタを初期状態に戻す
    func resetFilters() {
        searchText = ""
        selectedFilterKind = .all
        selectedInstitutionId = nil
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
        includeOnlyCalculationTarget = true
        excludeTransfers = true
        sortOption = .dateDescending
    }

    /// 新規作成モードに切り替え
    func prepareForNewTransaction() {
        editingTransaction = nil
        let today = clock()
        let defaultDate = today.isSameMonth(as: currentMonth) ? today : currentMonth
        formState = .empty(defaultDate: defaultDate)
        formErrors = []
        isEditorPresented = true
    }

    /// 既存取引の編集を開始
    func startEditing(transaction: Transaction) {
        editingTransaction = transaction
        formState = .from(transaction: transaction)
        formErrors = []
        isEditorPresented = true
    }

    /// 編集をキャンセル
    func cancelEditing() {
        editingTransaction = nil
        isEditorPresented = false
        formErrors = []
    }

    /// 中項目選択の整合性を確保
    func ensureMinorCategoryConsistency() {
        guard let majorId = formState.majorCategoryId else {
            formState.minorCategoryId = nil
            return
        }

        if let minorId = formState.minorCategoryId,
           referenceData.category(id: minorId)?.parent?.id != majorId {
            formState.minorCategoryId = nil
        }
    }

    /// フォーム内容を保存
    @discardableResult
    func saveCurrentForm() -> Bool {
        do {
            try formUseCase.save(
                state: formState,
                editingTransaction: editingTransaction,
                referenceData: referenceData
            )
            formErrors = []
            isEditorPresented = false
            refresh()
            return true
        } catch let error as TransactionFormError {
            formErrors = error.messages
            return false
        } catch {
            formErrors = ["保存に失敗しました: \(error.localizedDescription)"]
            return false
        }
    }

    /// 取引を削除
    @discardableResult
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        do {
            try formUseCase.delete(transaction: transaction)
            formErrors = []
            refresh()
            return true
        } catch let error as TransactionFormError {
            formErrors = error.messages
            return false
        } catch {
            formErrors = ["削除に失敗しました: \(error.localizedDescription)"]
            return false
        }
    }
}

// MARK: - Private Helpers

private extension TransactionStore {
    func loadReferenceData() {
        do {
            let reference = try listUseCase.loadReferenceData()
            availableInstitutions = reference.institutions
            availableCategories = reference.categories
            listErrorMessage = nil
        } catch {
            availableInstitutions = []
            availableCategories = []
            listErrorMessage = "参照データの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func reloadTransactions() {
        transactionsToken?.cancel()
        do {
            transactionsToken = try listUseCase.observeTransactions(filter: makeFilter()) { [weak self] result in
                guard let self else { return }
                self.transactions = result
                self.listErrorMessage = nil
            }
        } catch {
            transactionsToken = nil
            transactions = []
            listErrorMessage = "取引の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func makeFilter() -> TransactionListFilter {
        TransactionListFilter(
            month: currentMonth,
            searchText: searchText,
            filterKind: selectedFilterKind,
            institutionId: selectedInstitutionId,
            majorCategoryId: selectedMajorCategoryId,
            minorCategoryId: selectedMinorCategoryId,
            includeOnlyCalculationTarget: includeOnlyCalculationTarget,
            excludeTransfers: excludeTransfers,
            sortOption: sortOption
        )
    }
}
