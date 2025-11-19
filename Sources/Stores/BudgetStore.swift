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

    private struct BudgetCalculationContext: Sendable {
        internal let snapshot: BudgetSnapshot
        internal let year: Int
        internal let month: Int
        internal let monthlyUseCase: MonthlyBudgetUseCaseProtocol
        internal let annualUseCase: AnnualBudgetUseCaseProtocol
        internal let recurringPaymentUseCase: RecurringPaymentSavingsUseCaseProtocol
    }

    // MARK: - State

    private var snapshot: BudgetSnapshot?

    internal var currentYear: Int {
        didSet {
            guard oldValue != currentYear else { return }
            Task { [weak self] in
                await self?.reloadSnapshot()
            }
        }
    }

    internal var currentMonth: Int {
        didSet {
            guard oldValue != currentMonth else { return }
            refreshToken = UUID()
            _ = scheduleRecalculation()
        }
    }

    internal var displayMode: DisplayMode = .monthly
    internal private(set) var refreshToken: UUID = .init()

    internal var displayModeTraits: BudgetDisplayModeTraits {
        BudgetDisplayModeTraits(mode: displayMode)
    }

    // MARK: - Cached Data

    /// 現在の月の予算一覧
    internal var monthlyBudgets: [Budget] = []

    /// カテゴリ選択肢
    internal var selectableCategories: [Category] = []

    /// 月次計算結果
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation

    /// カテゴリ別エントリ
    internal var categoryBudgetEntries: [MonthlyBudgetEntry] = []

    /// 全体予算エントリ
    internal var overallBudgetEntry: MonthlyBudgetEntry?

    /// 年次特別枠設定
    internal var annualBudgetConfig: AnnualBudgetConfig?

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

    @ObservationIgnored
    private var calculationTask: Task<Void, Never>?

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

        Task { [weak self] in
            await self?.reloadSnapshot()
        }
    }

    deinit {
        calculationTask?.cancel()
    }
}

// MARK: - Data Refresh

internal extension BudgetStore {
    /// データを再取得
    func refresh() async {
        await reloadSnapshot()
    }

    /// 計算結果を再計算
    @discardableResult
    private func scheduleRecalculation() -> Task<Void, Never> {
        calculationTask?.cancel()

        guard let snapshot else {
            let year = currentYear
            let month = currentMonth
            resetAllCalculations(year: year, month: month)
            calculationTask = nil
            return Task {}
        }

        let year = currentYear
        let month = currentMonth
        let monthlyUseCase = self.monthlyUseCase
        let annualUseCase = self.annualUseCase
        let recurringPaymentUseCase = self.recurringPaymentUseCase
        let context = BudgetCalculationContext(
            snapshot: snapshot,
            year: year,
            month: month,
            monthlyUseCase: monthlyUseCase,
            annualUseCase: annualUseCase,
            recurringPaymentUseCase: recurringPaymentUseCase,
        )

        let task = Task { [context, weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                BudgetStore.makeCalculationResult(context: context)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.currentYear == context.year, self.currentMonth == context.month else { return }
                self.applyCalculationResult(result)
            }
        }
        calculationTask = task
        return task
    }

    @MainActor
    private func resetAllCalculations(year: Int, month: Int) {
        monthlyBudgets = []
        selectableCategories = []
        monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: year,
            month: month,
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

    private nonisolated static func makeCalculationResult(
        context: BudgetCalculationContext,
    ) -> BudgetCalculationResult {
        let snapshot = context.snapshot
        let year = context.year
        let month = context.month
        let monthlyUseCase = context.monthlyUseCase
        let annualUseCase = context.annualUseCase
        let recurringPaymentUseCase = context.recurringPaymentUseCase
        BudgetCalculationResult(
            year: year,
            month: month,
            monthlyBudgets: monthlyUseCase.monthlyBudgets(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            selectableCategories: snapshot.categories,
            monthlyBudgetCalculation: monthlyUseCase.monthlyCalculation(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            categoryBudgetEntries: monthlyUseCase.categoryEntries(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            overallBudgetEntry: monthlyUseCase.overallEntry(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            annualBudgetConfig: snapshot.annualBudgetConfig,
            annualBudgetUsage: annualUseCase.annualBudgetUsage(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            annualOverallBudgetEntry: annualUseCase.annualOverallEntry(
                snapshot: snapshot,
                year: year,
            ),
            annualCategoryBudgetEntries: annualUseCase.annualCategoryEntries(
                snapshot: snapshot,
                year: year,
            ),
            monthlyRecurringPaymentSavingsTotal: recurringPaymentUseCase.monthlySavingsTotal(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            categoryRecurringPaymentSavings: recurringPaymentUseCase.categorySavings(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            recurringPaymentSavingsCalculations: recurringPaymentUseCase.calculations(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
            recurringPaymentSavingsEntries: recurringPaymentUseCase.entries(
                snapshot: snapshot,
                year: year,
                month: month,
            ),
        )
    }

    @MainActor
    private func applyCalculationResult(_ result: BudgetCalculationResult) {
        monthlyBudgets = result.monthlyBudgets
        selectableCategories = result.selectableCategories
        monthlyBudgetCalculation = result.monthlyBudgetCalculation
        categoryBudgetEntries = result.categoryBudgetEntries
        overallBudgetEntry = result.overallBudgetEntry
        annualBudgetConfig = result.annualBudgetConfig
        annualBudgetUsage = result.annualBudgetUsage
        annualOverallBudgetEntry = result.annualOverallBudgetEntry
        annualCategoryBudgetEntries = result.annualCategoryBudgetEntries
        monthlyRecurringPaymentSavingsTotal = result.monthlyRecurringPaymentSavingsTotal
        categoryRecurringPaymentSavings = result.categoryRecurringPaymentSavings
        recurringPaymentSavingsCalculations = result.recurringPaymentSavingsCalculations
        recurringPaymentSavingsEntries = result.recurringPaymentSavingsEntries
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

    func updateBudget(budget: Budget, input: BudgetInput) async throws {
        try await mutationUseCase.updateBudget(budget, input: input)
        await reloadSnapshot()
    }

    func deleteBudget(_ budget: Budget) async throws {
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
        let targetYear = currentYear
        let repository = self.repository

        let snapshotTask = Task.detached(priority: .userInitiated) { () -> BudgetSnapshot? in
            do {
                return try await repository.fetchSnapshot(for: targetYear)
            } catch {
                return nil
            }
        }

        let newSnapshot = await snapshotTask.value
        guard !Task.isCancelled else { return }
        let task = applySnapshot(newSnapshot)
        await task.value
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

    @MainActor
    private func applySnapshot(_ newSnapshot: BudgetSnapshot?) -> Task<Void, Never> {
        snapshot = newSnapshot
        refreshToken = UUID()
        return scheduleRecalculation()
    }
}

// MARK: - Derived State

private struct BudgetCalculationResult {
    let year: Int
    let month: Int
    let monthlyBudgets: [Budget]
    let selectableCategories: [Category]
    let monthlyBudgetCalculation: MonthlyBudgetCalculation
    let categoryBudgetEntries: [MonthlyBudgetEntry]
    let overallBudgetEntry: MonthlyBudgetEntry?
    let annualBudgetConfig: AnnualBudgetConfig?
    let annualBudgetUsage: AnnualBudgetUsage?
    let annualOverallBudgetEntry: AnnualBudgetEntry?
    let annualCategoryBudgetEntries: [AnnualBudgetEntry]
    let monthlyRecurringPaymentSavingsTotal: Decimal
    let categoryRecurringPaymentSavings: [UUID: Decimal]
    let recurringPaymentSavingsCalculations: [RecurringPaymentSavingsCalculation]
    let recurringPaymentSavingsEntries: [RecurringPaymentSavingsEntry]
}

// MARK: - Error

internal enum BudgetStoreError: Error {
    case categoryNotFound
    case duplicateAnnualAllocationCategory
    case invalidPeriod
}
