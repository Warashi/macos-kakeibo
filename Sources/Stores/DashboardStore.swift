import Foundation
import Observation

/// ダッシュボードストア
///
/// ダッシュボード画面の状態管理を行います。
/// - 月次/年次の総括計算
/// - カテゴリ別ハイライトの集計
/// - 年次特別枠の残額計算
@MainActor
@Observable
internal final class DashboardStore {
    // MARK: - Dependencies

    private let repository: DashboardRepository
    private let dashboardService: DashboardService
    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    // MARK: - State

    /// 現在の表示対象年
    internal var currentYear: Int

    /// 現在の表示対象月
    internal var currentMonth: Int

    /// 表示モード（月次/年次）
    internal var displayMode: DisplayMode = .monthly {
        didSet {
            if displayMode != oldValue {
                scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Cached Data

    /// 月次集計結果
    internal var monthlySummary: MonthlySummary

    /// 年次集計結果
    internal var annualSummary: AnnualSummary

    /// 月次予算計算結果
    internal var monthlyBudgetCalculation: MonthlyBudgetCalculation

    /// 年次特別枠使用状況
    internal var annualBudgetUsage: AnnualBudgetUsage?

    /// 月次充当結果
    internal var monthlyAllocation: MonthlyAllocation?

    /// カテゴリ別ハイライト（支出額上位）
    internal var categoryHighlights: [CategorySummary]

    /// 年次予算進捗（全体）
    internal var annualBudgetProgressCalculation: BudgetCalculation?

    /// 年次カテゴリ別予算進捗
    internal var annualBudgetCategoryEntries: [AnnualBudgetEntry]

    /// 貯蓄サマリ
    internal var savingsSummary: SavingsSummary

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameters:
    ///   - dashboardService: ダッシュボード計算サービス
    internal init(
        repository: DashboardRepository,
        dashboardService: DashboardService = DashboardService(),
    ) {
        self.repository = repository
        self.dashboardService = dashboardService

        // 現在の年月で初期化
        let now = Date()
        let initialYear = now.year
        let initialMonth = now.month

        // すべての stored property を初期化
        self.currentYear = initialYear
        self.currentMonth = initialMonth

        self.monthlySummary = MonthlySummary(
            year: initialYear,
            month: initialMonth,
            totalIncome: 0,
            totalExpense: 0,
            totalSavings: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: []
        )
        self.annualSummary = AnnualSummary(
            year: initialYear,
            totalIncome: 0,
            totalExpense: 0,
            totalSavings: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
            monthlySummaries: []
        )
        self.monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: initialYear,
            month: initialMonth,
            overallCalculation: nil,
            categoryCalculations: [],
        )
        self.annualBudgetUsage = nil
        self.monthlyAllocation = nil
        self.categoryHighlights = []
        self.annualBudgetProgressCalculation = nil
        self.annualBudgetCategoryEntries = []
        self.savingsSummary = SavingsSummary(
            totalMonthlySavings: 0,
            goalSummaries: []
        )

        // すべての stored property の初期化が完了したので、年のフォールバックチェックが可能
        Task { @MainActor [weak self] in
            await self?.bootstrapInitialState()
        }
    }

    // MARK: - Display Mode

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
    }

    // MARK: - Refresh

    /// データを再読み込みして計算結果を更新
    internal func refresh() async {
        let context = RefreshContext(
            year: currentYear,
            month: currentMonth,
            displayMode: displayMode,
        )
        do {
            let snapshot = try await repository.fetchSnapshot(year: context.year, month: context.month)

            guard !Task.isCancelled else { return }

            let result = dashboardService.calculate(
                snapshot: snapshot,
                year: context.year,
                month: context.month,
                displayMode: context.displayMode,
            )

            guard currentYear == context.year,
                  currentMonth == context.month,
                  displayMode == context.displayMode else { return }
            applyRefreshResult(result)
        } catch {
            // Keep previous state if fetching fails
        }
    }

    @MainActor
    private func applyRefreshResult(_ result: DashboardResult) {
        monthlySummary = result.monthlySummary
        annualSummary = result.annualSummary
        monthlyBudgetCalculation = result.monthlyBudgetCalculation
        annualBudgetUsage = result.annualBudgetUsage
        monthlyAllocation = result.monthlyAllocation
        categoryHighlights = result.categoryHighlights
        annualBudgetProgressCalculation = result.annualBudgetProgressCalculation
        annualBudgetCategoryEntries = result.annualBudgetCategoryEntries
        savingsSummary = result.savingsSummary
    }

    // MARK: - Actions

    /// 前月に移動
    internal func moveToPreviousMonth() {
        updateMonthNavigator { $0.moveToPreviousMonth() }
        scheduleRefresh()
    }

    /// 次月に移動
    internal func moveToNextMonth() {
        updateMonthNavigator { $0.moveToNextMonth() }
        scheduleRefresh()
    }

    /// 今月に戻る
    internal func moveToCurrentMonth() {
        updateMonthNavigator { $0.moveToCurrentMonth() }
        scheduleRefresh()
    }

    /// 前年に移動
    internal func moveToPreviousYear() {
        updateMonthNavigator { $0.moveToPreviousYear() }
        scheduleRefresh()
    }

    /// 次年に移動
    internal func moveToNextYear() {
        updateMonthNavigator { $0.moveToNextYear() }
        scheduleRefresh()
    }

    /// 今年に戻る
    internal func moveToCurrentYear() {
        updateMonthNavigator { $0.moveToCurrentYear() }
        scheduleRefresh()
    }

    private func updateMonthNavigator(_ update: (inout MonthNavigator) -> Void) {
        var navigator = MonthNavigator(year: currentYear, month: currentMonth)
        update(&navigator)
        currentYear = navigator.year
        currentMonth = navigator.month
    }

    private func bootstrapInitialState() async {
        let defaultYear = currentYear
        let resolvedYear = await (try? repository.resolveInitialYear(defaultYear: defaultYear)) ?? defaultYear
        if currentYear != resolvedYear {
            currentYear = resolvedYear
        }
        await refresh()
    }
}

private struct RefreshContext {
    let year: Int
    let month: Int
    let displayMode: DashboardStore.DisplayMode
}
