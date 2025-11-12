import Foundation

// MARK: - 集計結果型

/// カテゴリ別集計結果
internal struct CategorySummary: Sendable {
    /// カテゴリ名
    internal let categoryName: String

    /// カテゴリID
    internal let categoryId: UUID?

    /// 収入合計
    internal let totalIncome: Decimal

    /// 支出合計
    internal let totalExpense: Decimal

    /// 差引（収入 - 支出）
    internal let net: Decimal

    /// 取引件数
    internal let transactionCount: Int

    internal init(
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
internal struct MonthlySummary: Sendable {
    /// 対象年
    internal let year: Int

    /// 対象月
    internal let month: Int

    /// 収入合計
    internal let totalIncome: Decimal

    /// 支出合計
    internal let totalExpense: Decimal

    /// 差引（収入 - 支出）
    internal let net: Decimal

    /// 取引件数
    internal let transactionCount: Int

    /// カテゴリ別集計
    internal let categorySummaries: [CategorySummary]
}

/// 年次集計結果
internal struct AnnualSummary: Sendable {
    /// 対象年
    internal let year: Int

    /// 収入合計
    internal let totalIncome: Decimal

    /// 支出合計
    internal let totalExpense: Decimal

    /// 差引（収入 - 支出）
    internal let net: Decimal

    /// 取引件数
    internal let transactionCount: Int

    /// カテゴリ別集計
    internal let categorySummaries: [CategorySummary]

    /// 月別集計
    internal let monthlySummaries: [MonthlySummary]
}

// MARK: - フィルタオプション

/// 集計フィルタオプション
internal struct AggregationFilter: Sendable {
    /// 計算対象のみを含める
    internal let includeOnlyCalculationTarget: Bool

    /// 振替を除外する
    internal let excludeTransfers: Bool

    /// 金融機関IDでフィルタ（nilの場合はすべて）
    internal let financialInstitutionId: UUID?

    /// カテゴリIDでフィルタ（nilの場合はすべて）
    internal let categoryId: UUID?

    internal init(
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
    internal static let `default`: AggregationFilter = AggregationFilter()
}

// MARK: - TransactionAggregator

/// 取引集計サービス
///
/// 取引データの集計処理を行います。
/// - 期間別集計（月次、年次）
/// - カテゴリ別集計
/// - 計算対象フィルタリング
/// - 振替除外処理
internal struct TransactionAggregator: Sendable {
    /// 月次集計を実行
    /// - Parameters:
    ///   - transactions: 集計対象の取引リスト
    ///   - categories: カテゴリリスト
    ///   - year: 対象年
    ///   - month: 対象月
    ///   - filter: フィルタオプション
    /// - Returns: 月次集計結果
    internal func aggregateMonthly(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
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
        let categorySummaries = aggregateByCategory(transactions: filteredTransactions, categories: categories)

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
    ///   - categories: カテゴリリスト
    ///   - year: 対象年
    ///   - filter: フィルタオプション
    /// - Returns: 年次集計結果
    internal func aggregateAnnually(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
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
        let categorySummaries = aggregateByCategory(transactions: filteredTransactions, categories: categories)

        // 月別に集計
        let monthlySummaries = (1 ... 12).map { month in
            aggregateMonthly(
                transactions: transactions,
                categories: categories,
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
    /// - Parameters:
    ///   - transactions: 集計対象の取引リスト
    ///   - categories: カテゴリリスト
    /// - Returns: カテゴリ別集計結果のリスト
    internal func aggregateByCategory(
        transactions: [TransactionDTO],
        categories: [CategoryDTO],
    ) -> [CategorySummary] {
        // カテゴリグループ化キー
        struct CategoryKey: Hashable {
            let name: String
            let id: UUID?
        }

        // カテゴリIDからカテゴリへのマップを作成
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        // カテゴリごとにグループ化
        let groupedByCategory = Dictionary(grouping: transactions) { transaction -> CategoryKey in
            // 中項目があれば中項目のフルネーム、なければ大項目の名前、それもなければ「未分類」
            if let minorCategoryId = transaction.minorCategoryId,
               let minorCategory = categoryMap[minorCategoryId] {
                // 親カテゴリ名を取得してフルネームを構築
                let parentName = minorCategory.parentId.flatMap { categoryMap[$0]?.name } ?? ""
                let fullName = parentName.isEmpty ? minorCategory.name : "\(parentName) > \(minorCategory.name)"
                return CategoryKey(name: fullName, id: minorCategoryId)
            } else if let majorCategoryId = transaction.majorCategoryId,
                      let majorCategory = categoryMap[majorCategoryId] {
                return CategoryKey(name: majorCategory.name, id: majorCategoryId)
            } else {
                return CategoryKey(name: "未分類", id: nil)
            }
        }

        // 各カテゴリの集計を計算
        return groupedByCategory.map { key, categoryTransactions in
            let totalIncome = categoryTransactions
                .filter(\.isIncome)
                .reduce(Decimal.zero) { $0 + $1.amount }

            let totalExpense = categoryTransactions
                .filter(\.isExpense)
                .reduce(Decimal.zero) { $0 + abs($1.amount) }

            return CategorySummary(
                categoryName: key.name,
                categoryId: key.id,
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
        transaction: TransactionDTO,
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
            guard transaction.financialInstitutionId == targetInstitutionId else {
                return false
            }
        }

        // カテゴリチェック
        if let targetCategoryId = filter.categoryId {
            let majorMatches = transaction.majorCategoryId == targetCategoryId
            let minorMatches = transaction.minorCategoryId == targetCategoryId
            guard majorMatches || minorMatches else {
                return false
            }
        }

        return true
    }
}
