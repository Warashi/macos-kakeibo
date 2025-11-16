import Foundation
import Observation
import SwiftData

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

    private let modelContainer: ModelContainer
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
        refreshTask = Task { [weak self] in
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

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameters:
    ///   - modelContainer: SwiftData の ModelContainer
    ///   - dashboardService: ダッシュボード計算サービス
    internal init(
        modelContainer: ModelContainer,
        dashboardService: DashboardService = DashboardService(),
    ) {
        self.modelContainer = modelContainer
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
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
        )
        self.annualSummary = AnnualSummary(
            year: initialYear,
            totalIncome: 0,
            totalExpense: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
            monthlySummaries: [],
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

        // すべての stored property の初期化が完了したので、年のフォールバックチェックが可能
        let bootstrapContext = ModelContext(modelContainer)
        if getAnnualBudgetConfig(year: self.currentYear, modelContext: bootstrapContext) == nil,
           let fallbackYear = latestAnnualBudgetConfigYear(modelContext: bootstrapContext) {
            self.currentYear = fallbackYear
        }

        // 初回データ読み込み
        scheduleRefresh()
    }

    // MARK: - Display Mode

    /// 表示モード
    internal enum DisplayMode: String, CaseIterable {
        case monthly = "月次"
        case annual = "年次"
    }

    // MARK: - Data Fetching

    /// 一括取得したデータ
    private struct FetchedData {
        let monthlyTransactions: [TransactionDTO]
        let annualTransactions: [TransactionDTO]
        let budgets: [BudgetDTO]
        let categories: [CategoryDTO]
        let config: AnnualBudgetConfigDTO?
    }

    /// 指定した期間の取引を取得
    private nonisolated func fetchTransactions(
        modelContext: ModelContext,
        year: Int,
        month: Int? = nil
    ) -> [Transaction] {
        guard let startDate = Date.from(year: year, month: month ?? 1) else {
            return []
        }

        let endDate: Date = {
            if let month {
                let nextMonth = month == 12 ? 1 : month + 1
                let nextYear = month == 12 ? year + 1 : year
                return Date.from(year: nextYear, month: nextMonth) ?? startDate
            } else {
                return Date.from(year: year + 1, month: 1) ?? startDate
            }
        }()

        let descriptor = TransactionQueries.between(startDate: startDate, endDate: endDate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 指定年に関係する予算を取得
    private nonisolated func fetchBudgets(modelContext: ModelContext, overlapping year: Int) -> [Budget] {
        let descriptor = BudgetQueries.budgets(overlapping: year)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// カテゴリを取得
    private nonisolated func fetchCategories(modelContext: ModelContext) -> [Category] {
        let descriptor = CategoryQueries.sortedForDisplay()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 年次特別枠設定を取得
    private nonisolated func getAnnualBudgetConfig(year: Int, modelContext: ModelContext) -> AnnualBudgetConfig? {
        try? modelContext.fetch(BudgetQueries.annualConfig(for: year)).first
    }

    /// 最新の年次特別枠設定の年を取得
    private nonisolated func latestAnnualBudgetConfigYear(modelContext: ModelContext) -> Int? {
        try? modelContext.fetch(BudgetQueries.latestAnnualConfig()).first?.year
    }

    /// 必要なデータを一括取得
    private nonisolated func fetchAllData(
        modelContext: ModelContext,
        year: Int,
        month: Int
    ) -> FetchedData {
        let monthlyTransactions = fetchTransactions(modelContext: modelContext, year: year, month: month)
        let annualTransactions = fetchTransactions(modelContext: modelContext, year: year)
        let budgets = fetchBudgets(modelContext: modelContext, overlapping: year)
        let categories = fetchCategories(modelContext: modelContext)
        let config = getAnnualBudgetConfig(year: year, modelContext: modelContext)

        return FetchedData(
            monthlyTransactions: monthlyTransactions.map { TransactionDTO(from: $0) },
            annualTransactions: annualTransactions.map { TransactionDTO(from: $0) },
            budgets: budgets.map { BudgetDTO(from: $0) },
            categories: categories.map { CategoryDTO(from: $0) },
            config: config.map { AnnualBudgetConfigDTO(from: $0) },
        )
    }

    // MARK: - Refresh

    /// データを再読み込みして計算結果を更新
    internal func refresh() async {
        let targetYear = currentYear
        let targetMonth = currentMonth
        let container = modelContainer
        let data = await Task { @DatabaseActor in
            let context = ModelContext(container)
            return fetchAllData(
                modelContext: context,
                year: targetYear,
                month: targetMonth
            )
        }.value

        guard !Task.isCancelled else { return }

        // Build input for dashboard service
        let input = DashboardInput(
            monthlyTransactions: data.monthlyTransactions,
            annualTransactions: data.annualTransactions,
            budgets: data.budgets,
            categories: data.categories,
            config: data.config,
        )

        // Calculate dashboard data via service
        let result = dashboardService.calculate(
            input: input,
            year: targetYear,
            month: targetMonth,
            displayMode: displayMode,
        )

        // Update state with calculation results
        monthlySummary = result.monthlySummary
        annualSummary = result.annualSummary
        monthlyBudgetCalculation = result.monthlyBudgetCalculation
        annualBudgetUsage = result.annualBudgetUsage
        monthlyAllocation = result.monthlyAllocation
        categoryHighlights = result.categoryHighlights
        annualBudgetProgressCalculation = result.annualBudgetProgressCalculation
        annualBudgetCategoryEntries = result.annualBudgetCategoryEntries
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
}
