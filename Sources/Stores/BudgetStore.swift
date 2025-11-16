import Foundation
import Observation

/// 予算管理ストア
///
/// 月次/年次/定期支払いモードを切り替えながら、表示状態を管理します。
@MainActor
@Observable
internal final class BudgetStore {
    // MARK: - Types

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
        case recurringPaymentsList = "定期支払い一覧"
    }

    // MARK: - Dependencies

    private let repository: BudgetRepository
    private let monthlyUseCase: MonthlyBudgetUseCaseProtocol
    private let annualUseCase: AnnualBudgetUseCaseProtocol
    private let recurringPaymentUseCase: RecurringPaymentSavingsUseCaseProtocol
    private let mutationUseCase: BudgetMutationUseCaseProtocol
    private let currentDateProvider: () -> Date

    // MARK: - State

    private var snapshot: BudgetSnapshot? {
        didSet {
            refreshToken = UUID()
            recalculate()
        }
    }

    internal var currentYear: Int {
        didSet {
            guard oldValue != currentYear else { return }
            Task { await reloadSnapshot() }
        }
    }

    internal var currentMonth: Int {
        didSet {
            guard oldValue != currentMonth else { return }
            refreshToken = UUID()
            recalculate()
        }
    }

    internal var displayMode: DisplayMode = .monthly
    internal private(set) var refreshToken: UUID = .init()

    internal var displayModeTraits: BudgetDisplayModeTraits {
        BudgetDisplayModeTraits(mode: displayMode)
    }

    // MARK: - Cached Data

    /// 現在の月の予算一覧
    internal var monthlyBudgets: [BudgetDTO] = []

    /// カテゴリ選択肢
    internal var selectableCategories: [Category] = []

    /// 月次計算結果
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation

    /// カテゴリ別エントリ
    internal var categoryBudgetEntries: [MonthlyBudgetEntry] = []

    /// 全体予算エントリ
    internal var overallBudgetEntry: MonthlyBudgetEntry?

    /// 年次特別枠設定
    internal var annualBudgetConfig: AnnualBudgetConfigDTO?

    /// 年次特別枠の使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage?

    /// 年次全体予算エントリ
    internal var annualOverallBudgetEntry: AnnualBudgetEntry?

    /// 年次カテゴリ別エントリ
    internal var annualCategoryBudgetEntries: [AnnualBudgetEntry] = []

    /// 月次積立金額の合計
    internal var monthlyRecurringPaymentSavingsTotal: Decimal = .zero

    /// カテゴリ別積立金額
    internal var categoryRecurringPaymentSavings: [UUID: Decimal] = [:]

    /// 定期支払い積立計算結果
    internal var recurringPaymentSavingsCalculations: [RecurringPaymentSavingsCalculation] = []

    /// 定期支払い積立の表示用エントリ
    internal var recurringPaymentSavingsEntries: [RecurringPaymentSavingsEntry] = []

    // MARK: - Initialization

    internal init(
        repository: BudgetRepository,
        monthlyUseCase: MonthlyBudgetUseCaseProtocol,
        annualUseCase: AnnualBudgetUseCaseProtocol,
        recurringPaymentUseCase: RecurringPaymentSavingsUseCaseProtocol,
        mutationUseCase: BudgetMutationUseCaseProtocol,
        currentDateProvider: @escaping () -> Date = Date.init,
    ) {
        self.repository = repository
        self.monthlyUseCase = monthlyUseCase
        self.annualUseCase = annualUseCase
        self.recurringPaymentUseCase = recurringPaymentUseCase
        self.mutationUseCase = mutationUseCase
        self.currentDateProvider = currentDateProvider

        let now = currentDateProvider()
        let initialYear = now.year
        let initialMonth = now.month

        self.currentYear = initialYear
        self.currentMonth = initialMonth

        // 初期値を設定（recalculate で上書きされる）
        self.monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: initialYear,
            month: initialMonth,
            overallCalculation: nil,
            categoryCalculations: [],
        )

        Task { await reloadSnapshot() }
    }
}

// MARK: - Data Refresh

internal extension BudgetStore {
    /// データを再取得
    func refresh() async {
        await reloadSnapshot()
    }

    /// 計算結果を再計算
    private func recalculate() {
        guard let snapshot else {
            resetAllCalculations()
            return
        }

        recalculateMonthlyBudgets(snapshot: snapshot)
        recalculateAnnualBudgets(snapshot: snapshot)
        recalculateRecurringPaymentSavings(snapshot: snapshot)
    }

    /// すべての計算結果を初期値にリセット
    private func resetAllCalculations() {
        monthlyBudgets = []
        selectableCategories = []
        monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: currentYear,
            month: currentMonth,
            overallCalculation: nil,
            categoryCalculations: [],
        )
        categoryBudgetEntries = []
        overallBudgetEntry = nil
        annualBudgetConfig = nil
        annualBudgetUsage = nil
        annualOverallBudgetEntry = nil
        annualCategoryBudgetEntries = []
        monthlyRecurringPaymentSavingsTotal = .zero
        categoryRecurringPaymentSavings = [:]
        recurringPaymentSavingsCalculations = []
        recurringPaymentSavingsEntries = []
    }

    /// 月次予算データを再計算
    private func recalculateMonthlyBudgets(snapshot: BudgetSnapshot) {
        monthlyBudgets = monthlyUseCase.monthlyBudgets(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        selectableCategories = snapshot.categories
        monthlyBudgetCalculation = monthlyUseCase.monthlyCalculation(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        categoryBudgetEntries = monthlyUseCase.categoryEntries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        overallBudgetEntry = monthlyUseCase.overallEntry(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
    }

    /// 年次予算データを再計算
    private func recalculateAnnualBudgets(snapshot: BudgetSnapshot) {
        annualBudgetConfig = snapshot.annualBudgetConfig
        annualBudgetUsage = annualUseCase.annualBudgetUsage(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        annualOverallBudgetEntry = annualUseCase.annualOverallEntry(
            snapshot: snapshot,
            year: currentYear,
        )
        annualCategoryBudgetEntries = annualUseCase.annualCategoryEntries(
            snapshot: snapshot,
            year: currentYear,
        )
    }

    /// 定期支払い積立データを再計算
    private func recalculateRecurringPaymentSavings(snapshot: BudgetSnapshot) {
        monthlyRecurringPaymentSavingsTotal = recurringPaymentUseCase.monthlySavingsTotal(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        categoryRecurringPaymentSavings = recurringPaymentUseCase.categorySavings(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        recurringPaymentSavingsCalculations = recurringPaymentUseCase.calculations(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
        recurringPaymentSavingsEntries = recurringPaymentUseCase.entries(
            snapshot: snapshot,
            year: currentYear,
            month: currentMonth,
        )
    }
}

// MARK: - Navigation

internal extension BudgetStore {
    func moveToPreviousMonth() {
        updateNavigation { $0.moveToPreviousMonth() }
    }

    func moveToNextMonth() {
        updateNavigation { $0.moveToNextMonth() }
    }

    func moveToCurrentMonth() {
        updateNavigation { $0.moveToCurrentMonth() }
    }

    func moveToPreviousYear() {
        updateNavigation { $0.moveToPreviousYear() }
    }

    func moveToNextYear() {
        updateNavigation { $0.moveToNextYear() }
    }

    func moveToCurrentYear() {
        updateNavigation { $0.moveToCurrentYear() }
    }

    func moveToPresent() {
        updateNavigation { $0.moveToPresent(displayMode: displayMode) }
    }
}

// MARK: - Mutations

internal extension BudgetStore {
    func addBudget(_ input: BudgetInput) async throws {
        try await mutationUseCase.addBudget(input: input)
        await reloadSnapshot()
    }

    func updateBudget(budget: BudgetDTO, input: BudgetInput) async throws {
        try await mutationUseCase.updateBudget(budget, input: input)
        await reloadSnapshot()
    }

    func deleteBudget(_ budget: BudgetDTO) async throws {
        try await mutationUseCase.deleteBudget(budget)
        await reloadSnapshot()
    }

    func upsertAnnualBudgetConfig(
        totalAmount: Decimal,
        policy: AnnualBudgetPolicy,
        allocations: [AnnualAllocationDraft],
    ) async throws {
        let input = AnnualBudgetConfigInput(
            year: currentYear,
            totalAmount: totalAmount,
            policy: policy,
            allocations: allocations,
        )
        try await mutationUseCase.upsertAnnualBudgetConfig(input)
        await reloadSnapshot()
    }
}

// MARK: - Private Helpers

private extension BudgetStore {
    func reloadSnapshot() async {
        snapshot = try? await repository.fetchSnapshot(for: currentYear)
    }

    private func updateNavigation(_ update: (inout BudgetNavigationState) -> Bool) {
        var state = BudgetNavigationState(
            year: currentYear,
            month: currentMonth,
            currentDateProvider: currentDateProvider,
        )
        let changed = update(&state)
        guard changed else { return }
        applyNavigation(state)
    }

    private func applyNavigation(_ state: BudgetNavigationState) {
        if currentYear != state.year {
            currentYear = state.year
        }
        if currentMonth != state.month {
            currentMonth = state.month
        }
    }
}

// MARK: - Error

internal enum BudgetStoreError: Error {
    case categoryNotFound
    case duplicateAnnualAllocationCategory
    case invalidPeriod
}
