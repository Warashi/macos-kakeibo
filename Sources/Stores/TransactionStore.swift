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

    /// 取引リストの表示種別フィルタ
    internal enum TransactionFilterKind: String, CaseIterable, Identifiable, Hashable {
        case all = "すべて"
        case income = "収入"
        case expense = "支出"

        internal var id: Self { self }
        internal var label: String { rawValue }
    }

    /// 取引フォームで使用する入出金種別
    internal enum TransactionKind: String, CaseIterable, Identifiable {
        case income = "収入"
        case expense = "支出"

        internal var id: Self { self }
        internal var label: String { rawValue }
    }

    /// 並び替えオプション
    internal enum SortOption: String, CaseIterable, Identifiable {
        case dateDescending = "日付（新しい順）"
        case dateAscending = "日付（古い順）"
        case amountDescending = "金額（大きい順）"
        case amountAscending = "金額（小さい順）"

        internal var id: Self { self }
        internal var label: String { rawValue }
    }

    /// 日毎の取引セクション
    internal struct TransactionSection: Identifiable {
        internal let date: Date
        internal let transactions: [Transaction]

        internal var id: Date { date }
        internal var title: String { date.longDateFormatted }
    }

    /// 取引フォーム状態
    internal struct TransactionFormState: Equatable {
        internal var date: Date
        internal var title: String
        internal var memo: String
        internal var amountText: String
        internal var transactionKind: TransactionKind
        internal var isIncludedInCalculation: Bool
        internal var isTransfer: Bool
        internal var financialInstitutionId: UUID?
        internal var majorCategoryId: UUID?
        internal var minorCategoryId: UUID?

        internal static func empty(defaultDate: Date) -> TransactionFormState {
            TransactionFormState(
                date: defaultDate,
                title: "",
                memo: "",
                amountText: "",
                transactionKind: .expense,
                isIncludedInCalculation: true,
                isTransfer: false,
                financialInstitutionId: nil,
                majorCategoryId: nil,
                minorCategoryId: nil,
            )
        }

        internal static func from(transaction: Transaction) -> TransactionFormState {
            TransactionFormState(
                date: transaction.date,
                title: transaction.title,
                memo: transaction.memo,
                amountText: TransactionStore.amountString(from: transaction.absoluteAmount),
                transactionKind: transaction.isExpense ? .expense : .income,
                isIncludedInCalculation: transaction.isIncludedInCalculation,
                isTransfer: transaction.isTransfer,
                financialInstitutionId: transaction.financialInstitution?.id,
                majorCategoryId: transaction.majorCategory?.id,
                minorCategoryId: transaction.minorCategory?.id,
            )
        }
    }

    /// 取引作成・更新時のデータ
    internal struct TransactionData {
        internal let amount: Decimal
        internal let institution: FinancialInstitution?
        internal let majorCategory: Category?
        internal let minorCategory: Category?
    }

    // MARK: - Properties

    private let modelContext: ModelContext

    private var cachedTransactions: [Transaction] = [] {
        didSet { applyFilters() }
    }

    internal var transactions: [Transaction] = []
    internal var searchText: String = "" {
        didSet { applyFilters() }
    }

    internal var selectedFilterKind: TransactionFilterKind = .all {
        didSet { applyFilters() }
    }

    internal var selectedInstitutionId: UUID? {
        didSet { applyFilters() }
    }

    internal var selectedMajorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMajorCategoryId else { return }
            if selectedMajorCategoryId == nil {
                selectedMinorCategoryId = nil
            } else if let minorId = selectedMinorCategoryId,
                      lookupCategory(id: minorId)?.parent?.id != selectedMajorCategoryId {
                selectedMinorCategoryId = nil
            }
            applyFilters()
        }
    }

    internal var selectedMinorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMinorCategoryId else { return }
            applyFilters()
        }
    }

    internal var includeOnlyCalculationTarget: Bool = true {
        didSet { applyFilters() }
    }

    internal var excludeTransfers: Bool = true {
        didSet { applyFilters() }
    }

    internal var sortOption: SortOption = .dateDescending {
        didSet { applyFilters() }
    }

    internal var currentMonth: Date {
        didSet {
            let normalized = currentMonth.startOfMonth
            if currentMonth != normalized {
                currentMonth = normalized
                return
            }
            applyFilters()
        }
    }

    internal private(set) var availableInstitutions: [FinancialInstitution] = []
    internal private(set) var availableCategories: [Category] = []

    internal var isEditorPresented: Bool = false
    internal private(set) var editingTransaction: Transaction?
    internal var formState: TransactionFormState
    internal var formErrors: [String] = []

    // MARK: - Initialization

    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.currentMonth = Date().startOfMonth
        self.formState = .empty(defaultDate: Date())
        refresh()
    }
}

// MARK: - Public API

internal extension TransactionStore {
    /// 参照データと取引を再取得
    func refresh() {
        loadReferenceData()
        loadTransactions()
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
        currentMonth = Date().startOfMonth
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
        let today = Date()
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
           lookupCategory(id: minorId)?.parent?.id != majorId {
            formState.minorCategoryId = nil
        }
    }

    /// フォーム内容を保存
    @discardableResult
    func saveCurrentForm() -> Bool {
        formErrors = validateForm()
        guard formErrors.isEmpty else { return false }

        guard let amountMagnitude = parsedAmountMagnitude() else {
            formErrors = ["金額を正しく入力してください"]
            return false
        }

        let signedAmount = signedAmount(from: amountMagnitude)
        let institution = lookupInstitution(id: formState.financialInstitutionId)
        let majorCategory = lookupCategory(id: formState.majorCategoryId)
        let minorCategory = lookupCategory(id: formState.minorCategoryId)

        let data = TransactionData(
            amount: signedAmount,
            institution: institution,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )

        if let editingTransaction {
            update(transaction: editingTransaction, data: data)
        } else {
            createTransaction(data: data)
        }

        do {
            try modelContext.save()
            formErrors = []
            isEditorPresented = false
            refresh()
            return true
        } catch {
            formErrors = ["保存に失敗しました: \(error.localizedDescription)"]
            return false
        }
    }

    /// 取引を削除
    @discardableResult
    func deleteTransaction(_ transaction: Transaction) -> Bool {
        modelContext.delete(transaction)
        do {
            try modelContext.save()
            formErrors = []
            refresh()
            return true
        } catch {
            formErrors = ["削除に失敗しました: \(error.localizedDescription)"]
            return false
        }
    }
}

// MARK: - Private Helpers

private extension TransactionStore {
    func loadReferenceData() {
        let institutionDescriptor = FetchDescriptor<FinancialInstitution>(
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)],
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)],
        )

        availableInstitutions = (try? modelContext.fetch(institutionDescriptor)) ?? []
        availableCategories = (try? modelContext.fetch(categoryDescriptor)) ?? []
    }

    private func loadTransactions() {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse),
            ],
        )
        cachedTransactions = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func applyFilters() {
        guard !cachedTransactions.isEmpty else {
            transactions = []
            return
        }

        let trimmedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filtered = cachedTransactions.filter { transaction in
            shouldIncludeTransaction(transaction, trimmedSearch: trimmedSearch)
        }

        transactions = sort(transactions: filtered)
    }

    private func shouldIncludeTransaction(_ transaction: Transaction, trimmedSearch: String) -> Bool {
        guard matchesDateRange(transaction) else { return false }
        guard matchesCalculationTarget(transaction) else { return false }
        guard matchesTransferFilter(transaction) else { return false }
        guard matchesTransactionKind(transaction) else { return false }
        guard matchesInstitution(transaction) else { return false }
        guard matchesCategory(transaction) else { return false }
        guard matchesSearchText(transaction, trimmedSearch: trimmedSearch) else { return false }

        return true
    }

    private func matchesDateRange(_ transaction: Transaction) -> Bool {
        transaction.date.year == currentMonth.year &&
            transaction.date.month == currentMonth.month
    }

    private func matchesCalculationTarget(_ transaction: Transaction) -> Bool {
        !includeOnlyCalculationTarget || transaction.isIncludedInCalculation
    }

    private func matchesTransferFilter(_ transaction: Transaction) -> Bool {
        !excludeTransfers || !transaction.isTransfer
    }

    private func matchesTransactionKind(_ transaction: Transaction) -> Bool {
        switch selectedFilterKind {
        case .income:
            transaction.isIncome
        case .expense:
            transaction.isExpense
        case .all:
            true
        }
    }

    private func matchesInstitution(_ transaction: Transaction) -> Bool {
        guard let institutionId = selectedInstitutionId else { return true }
        return transaction.financialInstitution?.id == institutionId
    }


    private func matchesSearchText(_ transaction: Transaction, trimmedSearch: String) -> Bool {
        guard !trimmedSearch.isEmpty else { return true }

        let haystacks = [
            transaction.title.lowercased(),
            transaction.memo.lowercased(),
            transaction.categoryFullName.lowercased(),
            transaction.financialInstitution?.name.lowercased() ?? "",
        ]
        return haystacks.contains { $0.contains(trimmedSearch) }
    }

    private func sort(transactions: [Transaction]) -> [Transaction] {
        transactions.sorted { lhs, rhs in
            switch sortOption {
            case .dateDescending:
                if lhs.date == rhs.date {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.date > rhs.date
            case .dateAscending:
                if lhs.date == rhs.date {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.date < rhs.date
            case .amountDescending:
                let lhsAmount = lhs.absoluteAmount
                let rhsAmount = rhs.absoluteAmount
                if lhsAmount == rhsAmount {
                    return lhs.date > rhs.date
                }
                return lhsAmount > rhsAmount
            case .amountAscending:
                let lhsAmount = lhs.absoluteAmount
                let rhsAmount = rhs.absoluteAmount
                if lhsAmount == rhsAmount {
                    return lhs.date < rhs.date
                }
                return lhsAmount < rhsAmount
            }
        }
    }

    private func validateForm() -> [String] {
        var errors: [String] = []

        if formState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("内容を入力してください")
        }

        if parsedAmountMagnitude() == nil {
            errors.append("金額を入力してください")
        }

        if let minorId = formState.minorCategoryId {
            guard let majorId = formState.majorCategoryId else {
                errors.append("中項目を選択した場合は大項目も選択してください")
                return errors
            }

            if lookupCategory(id: minorId)?.parent?.id != majorId {
                errors.append("中項目の親カテゴリが一致していません")
            }
        }

        return errors
    }

    private func parsedAmountMagnitude() -> Decimal? {
        let sanitized = formState.amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }
        return Decimal(string: sanitized)?.magnitude
    }

    private func signedAmount(from magnitude: Decimal) -> Decimal {
        formState.transactionKind == .expense ? -magnitude : magnitude
    }

    private func lookupInstitution(id: UUID?) -> FinancialInstitution? {
        guard let id else { return nil }
        return availableInstitutions.first { $0.id == id }
    }

    private func lookupCategory(id: UUID?) -> Category? {
        guard let id else { return nil }
        return availableCategories.first { $0.id == id }
    }

    private func update(transaction: Transaction, data: TransactionData) {
        transaction.title = formState.title
        transaction.memo = formState.memo
        transaction.date = formState.date
        transaction.amount = data.amount
        transaction.isIncludedInCalculation = formState.isIncludedInCalculation
        transaction.isTransfer = formState.isTransfer
        transaction.financialInstitution = data.institution
        transaction.majorCategory = data.majorCategory
        transaction.minorCategory = data.minorCategory
        transaction.updatedAt = Date()
    }

    private func createTransaction(data: TransactionData) {
        let transaction = Transaction(
            date: formState.date,
            title: formState.title,
            amount: data.amount,
            memo: formState.memo,
            isIncludedInCalculation: formState.isIncludedInCalculation,
            isTransfer: formState.isTransfer,
            financialInstitution: data.institution,
            majorCategory: data.majorCategory,
            minorCategory: data.minorCategory,
        )
        modelContext.insert(transaction)
    }

    private nonisolated static func amountString(from decimal: Decimal) -> String {
        NSDecimalNumber(decimal: decimal).stringValue
    }
}
