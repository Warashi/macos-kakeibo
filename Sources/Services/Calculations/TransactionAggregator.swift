import Foundation

// MARK: - 集計結果型

/// カテゴリ別集計結果
public struct CategorySummary: Sendable {
    /// カテゴリ名
    public let categoryName: String

    /// カテゴリID
    public let categoryId: UUID?

    /// 収入合計
    public let totalIncome: Decimal

    /// 支出合計
    public let totalExpense: Decimal

    /// 差引（収入 - 支出）
    public let net: Decimal

    /// 取引件数
    public let transactionCount: Int

    public init(
        categoryName: String,
        categoryId: UUID? = nil,
        totalIncome: Decimal,
        totalExpense: Decimal,
        net: Decimal,
        transactionCount: Int,
    ) {
        self.categoryName = categoryName
        self.categoryId = categoryId
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.net = net
        self.transactionCount = transactionCount
    }
}

/// 月次集計結果
public struct MonthlySummary: Sendable {
    /// 対象年
    public let year: Int

    /// 対象月
    public let month: Int

    /// 収入合計
    public let totalIncome: Decimal

    /// 支出合計
    public let totalExpense: Decimal

    /// 差引（収入 - 支出）
    public let net: Decimal

    /// 取引件数
    public let transactionCount: Int

    /// カテゴリ別集計
    public let categorySummaries: [CategorySummary]

    public init(
        year: Int,
        month: Int,
        totalIncome: Decimal,
        totalExpense: Decimal,
        net: Decimal,
        transactionCount: Int,
        categorySummaries: [CategorySummary],
    ) {
        self.year = year
        self.month = month
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.net = net
        self.transactionCount = transactionCount
        self.categorySummaries = categorySummaries
    }
}

/// 年次集計結果
public struct AnnualSummary: Sendable {
    /// 対象年
    public let year: Int

    /// 収入合計
    public let totalIncome: Decimal

    /// 支出合計
    public let totalExpense: Decimal

    /// 差引（収入 - 支出）
    public let net: Decimal

    /// 取引件数
    public let transactionCount: Int

    /// カテゴリ別集計
    public let categorySummaries: [CategorySummary]

    /// 月別集計
    public let monthlySummaries: [MonthlySummary]

    public init(
        year: Int,
        totalIncome: Decimal,
        totalExpense: Decimal,
        net: Decimal,
        transactionCount: Int,
        categorySummaries: [CategorySummary],
        monthlySummaries: [MonthlySummary],
    ) {
        self.year = year
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.net = net
        self.transactionCount = transactionCount
        self.categorySummaries = categorySummaries
        self.monthlySummaries = monthlySummaries
    }
}

// MARK: - フィルタオプション

/// 集計フィルタオプション
public struct AggregationFilter: Sendable {
    /// 計算対象のみを含める
    public let includeOnlyCalculationTarget: Bool

    /// 振替を除外する
    public let excludeTransfers: Bool

    /// 金融機関IDでフィルタ（nilの場合はすべて）
    public let financialInstitutionId: UUID?

    /// カテゴリIDでフィルタ（nilの場合はすべて）
    public let categoryId: UUID?

    public init(
        includeOnlyCalculationTarget: Bool = true,
        excludeTransfers: Bool = true,
        financialInstitutionId: UUID? = nil,
        categoryId: UUID? = nil,
    ) {
        self.includeOnlyCalculationTarget = includeOnlyCalculationTarget
        self.excludeTransfers = excludeTransfers
        self.financialInstitutionId = financialInstitutionId
        self.categoryId = categoryId
    }

    /// デフォルトフィルタ（計算対象のみ、振替除外）
    public static let `default`: AggregationFilter = AggregationFilter()
}

// MARK: - TransactionAggregator

/// 取引集計サービス
///
/// 取引データの集計処理を行います。
/// - 期間別集計（月次、年次）
/// - カテゴリ別集計
/// - 計算対象フィルタリング
/// - 振替除外処理
public struct TransactionAggregator: Sendable {
    public init() {}

    /// 月次集計を実行
    /// - Parameters:
    ///   - transactions: 集計対象の取引リスト
    ///   - year: 対象年
    ///   - month: 対象月
    ///   - filter: フィルタオプション
    /// - Returns: 月次集計結果
    public func aggregateMonthly(
        transactions: [Transaction],
        year: Int,
        month: Int,
        filter: AggregationFilter = .default,
    ) -> MonthlySummary {
        // 対象月の取引をフィルタ
        let filteredTransactions = transactions.filter { transaction in
            // 年月でフィルタ
            guard transaction.date.year == year,
                  transaction.date.month == month else {
                return false
            }

            return applyFilter(transaction: transaction, filter: filter)
        }

        // カテゴリ別に集計
        let categorySummaries = aggregateByCategory(transactions: filteredTransactions)

        // 全体の集計
        let totalIncome = filteredTransactions
            .filter(\.isIncome)
            .reduce(Decimal.zero) { $0 + $1.amount }

        let totalExpense = filteredTransactions
            .filter(\.isExpense)
            .reduce(Decimal.zero) { $0 + abs($1.amount) }

        return MonthlySummary(
            year: year,
            month: month,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            net: totalIncome - totalExpense,
            transactionCount: filteredTransactions.count,
            categorySummaries: categorySummaries,
        )
    }

    /// 年次集計を実行
    /// - Parameters:
    ///   - transactions: 集計対象の取引リスト
    ///   - year: 対象年
    ///   - filter: フィルタオプション
    /// - Returns: 年次集計結果
    public func aggregateAnnually(
        transactions: [Transaction],
        year: Int,
        filter: AggregationFilter = .default,
    ) -> AnnualSummary {
        // 対象年の取引をフィルタ
        let filteredTransactions = transactions.filter { transaction in
            // 年でフィルタ
            guard transaction.date.year == year else {
                return false
            }

            return applyFilter(transaction: transaction, filter: filter)
        }

        // カテゴリ別に集計
        let categorySummaries = aggregateByCategory(transactions: filteredTransactions)

        // 月別に集計
        let monthlySummaries = (1 ... 12).map { month in
            aggregateMonthly(
                transactions: transactions,
                year: year,
                month: month,
                filter: filter,
            )
        }

        // 全体の集計
        let totalIncome = filteredTransactions
            .filter(\.isIncome)
            .reduce(Decimal.zero) { $0 + $1.amount }

        let totalExpense = filteredTransactions
            .filter(\.isExpense)
            .reduce(Decimal.zero) { $0 + abs($1.amount) }

        return AnnualSummary(
            year: year,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            net: totalIncome - totalExpense,
            transactionCount: filteredTransactions.count,
            categorySummaries: categorySummaries,
            monthlySummaries: monthlySummaries,
        )
    }

    /// カテゴリ別集計を実行
    /// - Parameter transactions: 集計対象の取引リスト
    /// - Returns: カテゴリ別集計結果のリスト
    public func aggregateByCategory(
        transactions: [Transaction],
    ) -> [CategorySummary] {
        // カテゴリごとにグループ化
        let groupedByCategory = Dictionary(grouping: transactions) { transaction -> String in
            // 中項目があれば中項目のフルネーム、なければ大項目の名前、それもなければ「未分類」
            if let minorCategory = transaction.minorCategory {
                return minorCategory.fullName
            } else if let majorCategory = transaction.majorCategory {
                return majorCategory.name
            } else {
                return "未分類"
            }
        }

        // 各カテゴリの集計を計算
        return groupedByCategory.map { categoryName, categoryTransactions in
            let totalIncome = categoryTransactions
                .filter(\.isIncome)
                .reduce(Decimal.zero) { $0 + $1.amount }

            let totalExpense = categoryTransactions
                .filter(\.isExpense)
                .reduce(Decimal.zero) { $0 + abs($1.amount) }

            // カテゴリIDを取得（中項目 > 大項目の優先順位）
            let categoryId = categoryTransactions.first?.minorCategory?.id
                ?? categoryTransactions.first?.majorCategory?.id

            return CategorySummary(
                categoryName: categoryName,
                categoryId: categoryId,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                net: totalIncome - totalExpense,
                transactionCount: categoryTransactions.count,
            )
        }
        .sorted { $0.totalExpense > $1.totalExpense } // 支出額の降順でソート
    }

    // MARK: - Private Methods

    /// フィルタを適用
    private func applyFilter(
        transaction: Transaction,
        filter: AggregationFilter,
    ) -> Bool {
        // 計算対象チェック
        if filter.includeOnlyCalculationTarget, !transaction.isIncludedInCalculation {
            return false
        }

        // 振替チェック
        if filter.excludeTransfers, transaction.isTransfer {
            return false
        }

        // 金融機関チェック
        if let targetInstitutionId = filter.financialInstitutionId {
            guard transaction.financialInstitution?.id == targetInstitutionId else {
                return false
            }
        }

        // カテゴリチェック
        if let targetCategoryId = filter.categoryId {
            let majorMatches = transaction.majorCategory?.id == targetCategoryId
            let minorMatches = transaction.minorCategory?.id == targetCategoryId
            guard majorMatches || minorMatches else {
                return false
            }
        }

        return true
    }
}
