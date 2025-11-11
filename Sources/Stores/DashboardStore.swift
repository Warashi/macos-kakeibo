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
@MainActor
internal final class DashboardStore {
    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let aggregator: TransactionAggregator
    private let budgetCalculator: BudgetCalculator
    private let annualBudgetAllocator: AnnualBudgetAllocator
    private let annualBudgetProgressCalculator: AnnualBudgetProgressCalculator

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

    /// 年次予算進捗計算結果
    private var annualBudgetProgressResult: AnnualBudgetProgressResult?

    /// 年次予算進捗（全体）
    internal var annualBudgetProgressCalculation: BudgetCalculation?

    /// 年次カテゴリ別予算進捗
    internal var annualBudgetCategoryEntries: [AnnualBudgetEntry]

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter modelContext: SwiftDataのモデルコンテキスト
    internal init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.aggregator = TransactionAggregator()
        self.budgetCalculator = BudgetCalculator()
        self.annualBudgetAllocator = AnnualBudgetAllocator()
        self.annualBudgetProgressCalculator = AnnualBudgetProgressCalculator()

        // 現在の年月で初期化
        let now = Date()
        self.currentYear = now.year
        self.currentMonth = now.month

        // 初期値を設定（refresh で上書きされる）
        self.monthlySummary = MonthlySummary(
            year: currentYear,
            month: currentMonth,
            totalIncome: 0,
            totalExpense: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
        )
        self.annualSummary = AnnualSummary(
            year: currentYear,
            totalIncome: 0,
            totalExpense: 0,
            net: 0,
            transactionCount: 0,
            categorySummaries: [],
            monthlySummaries: [],
        )
        self.monthlyBudgetCalculation = MonthlyBudgetCalculation(
            year: currentYear,
            month: currentMonth,
            overallCalculation: nil,
            categoryCalculations: [],
        )
        self.annualBudgetUsage = nil
        self.monthlyAllocation = nil
        self.categoryHighlights = []
        self.annualBudgetProgressResult = nil
        self.annualBudgetProgressCalculation = nil
        self.annualBudgetCategoryEntries = []

        if getAnnualBudgetConfig(year: currentYear) == nil,
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
        let monthlyTransactions: [Transaction]
        let annualTransactions: [Transaction]
        let budgets: [Budget]
        let categories: [Category]
        let config: AnnualBudgetConfig?
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
            monthlyTransactions: monthlyTransactions,
            annualTransactions: annualTransactions,
            budgets: budgets,
            categories: categories,
            config: config,
        )
    }

    // MARK: - Refresh

    /// データを再読み込みして計算結果を更新
    internal func refresh() {
        let data = fetchAllData()

        // 除外カテゴリIDを計算
        let excludedCategoryIds = data.config?.fullCoverageCategoryIDs(
            includingChildrenFrom: data.categories,
        ) ?? []

        // 月次集計
        monthlySummary = aggregator.aggregateMonthly(
            transactions: data.monthlyTransactions,
            year: currentYear,
            month: currentMonth,
            filter: .default,
        )

        // 年次集計
        annualSummary = aggregator.aggregateAnnually(
            transactions: data.annualTransactions,
            year: currentYear,
            filter: .default,
        )

        // 月次予算計算
        monthlyBudgetCalculation = budgetCalculator.calculateMonthlyBudget(
            transactions: data.monthlyTransactions,
            budgets: data.budgets,
            year: currentYear,
            month: currentMonth,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )

        // 年次特別枠使用状況
        if let config = data.config {
            let params = AllocationCalculationParams(
                transactions: data.annualTransactions,
                budgets: data.budgets,
                annualBudgetConfig: config,
                filter: .default,
            )
            annualBudgetUsage = annualBudgetAllocator.calculateAnnualBudgetUsage(
                params: params,
                upToMonth: currentMonth,
            )
            monthlyAllocation = annualBudgetAllocator.calculateMonthlyAllocation(
                params: params,
                year: currentYear,
                month: currentMonth,
            )
        } else {
            annualBudgetUsage = nil
            monthlyAllocation = nil
        }

        // カテゴリ別ハイライト
        let summaries = displayMode == .monthly
            ? monthlySummary.categorySummaries
            : annualSummary.categorySummaries
        categoryHighlights = Array(summaries.prefix(10))

        // 年次予算進捗
        let progressResult = annualBudgetProgressCalculator.calculate(
            budgets: data.budgets,
            transactions: data.annualTransactions,
            year: currentYear,
            filter: .default,
            excludedCategoryIds: excludedCategoryIds,
        )
        if progressResult.overallEntry == nil, progressResult.categoryEntries.isEmpty {
            annualBudgetProgressResult = nil
            annualBudgetProgressCalculation = nil
            annualBudgetCategoryEntries = []
        } else {
            annualBudgetProgressResult = progressResult
            annualBudgetProgressCalculation = progressResult.aggregateCalculation
            annualBudgetCategoryEntries = progressResult.categoryEntries
        }
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
