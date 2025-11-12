import Foundation
import Observation
import SwiftData

/// ダッシュボードストア
///
/// ダッシュボード画面の状態管理を行います。
/// - 月次/年次の総括計算
/// - カテゴリ別ハイライトの集計
/// - 年次特別枠の残額計算
@Observable
internal final class DashboardStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let dashboardService: DashboardService

    // MARK: - State

    /// 現在の表示対象年
    internal var currentYear: Int

    /// 現在の表示対象月
    internal var currentMonth: Int

    /// 表示モード（月次/年次）
    internal var displayMode: DisplayMode = .monthly {
        didSet {
            if displayMode != oldValue {
                refresh()
            }
        }
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
    ///   - modelContext: SwiftDataのモデルコンテキスト
    ///   - dashboardService: ダッシュボード計算サービス
    internal init(
        modelContext: ModelContext,
        dashboardService: DashboardService = DashboardService(),
    ) {
        self.modelContext = modelContext
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
        if getAnnualBudgetConfig(year: self.currentYear) == nil,
           let fallbackYear = latestAnnualBudgetConfigYear() {
            self.currentYear = fallbackYear
        }

        // 初回データ読み込み
        refresh()
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
    private func fetchTransactions(year: Int, month: Int? = nil) -> [Transaction] {
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
    private func fetchBudgets(overlapping year: Int) -> [Budget] {
        let descriptor = BudgetQueries.budgets(overlapping: year)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// カテゴリを取得
    private func fetchCategories() -> [Category] {
        let descriptor = CategoryQueries.sortedForDisplay()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 年次特別枠設定を取得
    private func getAnnualBudgetConfig(year: Int) -> AnnualBudgetConfig? {
        try? modelContext.fetch(BudgetQueries.annualConfig(for: year)).first
    }

    /// 最新の年次特別枠設定の年を取得
    private func latestAnnualBudgetConfigYear() -> Int? {
        try? modelContext.fetch(BudgetQueries.latestAnnualConfig()).first?.year
    }

    /// 必要なデータを一括取得
    private func fetchAllData() -> FetchedData {
        let monthlyTransactions = fetchTransactions(year: currentYear, month: currentMonth)
        let annualTransactions = fetchTransactions(year: currentYear)
        let budgets = fetchBudgets(overlapping: currentYear)
        let categories = fetchCategories()
        let config = getAnnualBudgetConfig(year: currentYear)

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
    internal func refresh() {
        let data = fetchAllData()

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
            year: currentYear,
            month: currentMonth,
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
        refresh()
    }

    /// 次月に移動
    internal func moveToNextMonth() {
        updateMonthNavigator { $0.moveToNextMonth() }
        refresh()
    }

    /// 今月に戻る
    internal func moveToCurrentMonth() {
        updateMonthNavigator { $0.moveToCurrentMonth() }
        refresh()
    }

    /// 前年に移動
    internal func moveToPreviousYear() {
        updateMonthNavigator { $0.moveToPreviousYear() }
        refresh()
    }

    /// 次年に移動
    internal func moveToNextYear() {
        updateMonthNavigator { $0.moveToNextYear() }
        refresh()
    }

    /// 今年に戻る
    internal func moveToCurrentYear() {
        updateMonthNavigator { $0.moveToCurrentYear() }
        refresh()
    }

    private func updateMonthNavigator(_ update: (inout MonthNavigator) -> Void) {
        var navigator = MonthNavigator(year: currentYear, month: currentMonth)
        update(&navigator)
        currentYear = navigator.year
        currentMonth = navigator.month
    }
}
