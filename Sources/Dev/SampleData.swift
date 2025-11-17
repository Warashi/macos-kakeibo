#if DEBUG
import Foundation

/// 開発・デバッグ用のサンプルデータ定義
internal enum SampleData {
    // MARK: - SwiftDataFinancialInstitution

    /// サンプル金融機関データ
    internal static func financialInstitutions() -> [SwiftDataFinancialInstitution] {
        [
            SwiftDataFinancialInstitution(name: "三菱UFJ銀行", displayOrder: 1),
            SwiftDataFinancialInstitution(name: "三井住友銀行", displayOrder: 2),
            SwiftDataFinancialInstitution(name: "楽天銀行", displayOrder: 3),
            SwiftDataFinancialInstitution(name: "PayPay銀行", displayOrder: 4),
            SwiftDataFinancialInstitution(name: "三井住友カード", displayOrder: 5),
            SwiftDataFinancialInstitution(name: "楽天カード", displayOrder: 6),
            SwiftDataFinancialInstitution(name: "現金", displayOrder: 7),
        ]
    }

    // MARK: - Category

    /// サンプルカテゴリデータ（階層構造）
    internal static func createSampleCategories() -> [SwiftDataCategory] {
        var categories: [SwiftDataCategory] = []

        // 食費
        let food = SwiftDataCategory(name: "食費", allowsAnnualBudget: false, displayOrder: 1)
        food.addChild(SwiftDataCategory(name: "外食", displayOrder: 1))
        food.addChild(SwiftDataCategory(name: "自炊", displayOrder: 2))
        food.addChild(SwiftDataCategory(name: "カフェ", displayOrder: 3))
        categories.append(food)
        categories.append(contentsOf: food.children)

        // 日用品
        let daily = SwiftDataCategory(name: "日用品", allowsAnnualBudget: false, displayOrder: 2)
        daily.addChild(SwiftDataCategory(name: "消耗品", displayOrder: 1))
        daily.addChild(SwiftDataCategory(name: "衛生用品", displayOrder: 2))
        categories.append(daily)
        categories.append(contentsOf: daily.children)

        // 交通費
        let transport = SwiftDataCategory(name: "交通費", allowsAnnualBudget: false, displayOrder: 3)
        transport.addChild(SwiftDataCategory(name: "電車", displayOrder: 1))
        transport.addChild(SwiftDataCategory(name: "バス", displayOrder: 2))
        transport.addChild(SwiftDataCategory(name: "タクシー", displayOrder: 3))
        categories.append(transport)
        categories.append(contentsOf: transport.children)

        // 趣味・娯楽
        let hobby = SwiftDataCategory(name: "趣味・娯楽", allowsAnnualBudget: true, displayOrder: 4)
        hobby.addChild(SwiftDataCategory(name: "書籍", displayOrder: 1))
        hobby.addChild(SwiftDataCategory(name: "映画・動画", displayOrder: 2))
        hobby.addChild(SwiftDataCategory(name: "ゲーム", displayOrder: 3))
        categories.append(hobby)
        categories.append(contentsOf: hobby.children)

        // 特別費
        let special = SwiftDataCategory(name: "特別費", allowsAnnualBudget: true, displayOrder: 5)
        special.addChild(SwiftDataCategory(name: "旅行", displayOrder: 1))
        special.addChild(SwiftDataCategory(name: "冠婚葬祭", displayOrder: 2))
        special.addChild(SwiftDataCategory(name: "家電", displayOrder: 3))
        categories.append(special)
        categories.append(contentsOf: special.children)

        // 収入
        let income = SwiftDataCategory(name: "収入", allowsAnnualBudget: false, displayOrder: 6)
        income.addChild(SwiftDataCategory(name: "給与", displayOrder: 1))
        income.addChild(SwiftDataCategory(name: "賞与", displayOrder: 2))
        income.addChild(SwiftDataCategory(name: "その他", displayOrder: 3))
        categories.append(income)
        categories.append(contentsOf: income.children)

        return categories
    }

    // MARK: - SwiftDataTransaction

    /// サンプル取引データ
    internal static func createSampleTransactions(
        categories: [SwiftDataCategory],
        institutions: [SwiftDataFinancialInstitution],
    ) -> [SwiftDataTransaction] {
        let refs = findCategoriesAndInstitutions(categories: categories, institutions: institutions)
        let calendar = Calendar.current
        let now = Date()

        var transactions: [SwiftDataTransaction] = []
        transactions.append(contentsOf: createIncomeTransactions(calendar: calendar, now: now, refs: refs))
        transactions.append(contentsOf: createExpenseTransactions(calendar: calendar, now: now, refs: refs))

        return transactions
    }

    // MARK: - Budget

    /// サンプル予算データ
    internal static func createSampleBudgets(categories: [SwiftDataCategory]) -> [SwiftDataBudget] {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let year = components.year, let month = components.month else {
            return []
        }

        var budgets: [SwiftDataBudget] = []

        // 全体予算
        budgets.append(SwiftDataBudget(amount: 200_000, year: year, month: month))

        // カテゴリ別予算
        if let food = categories.first(where: { $0.name == "食費" && $0.isMajor }) {
            budgets.append(SwiftDataBudget(amount: 50000, category: food, year: year, month: month))
        }

        if let transport = categories.first(where: { $0.name == "交通費" && $0.isMajor }) {
            budgets.append(SwiftDataBudget(amount: 15000, category: transport, year: year, month: month))
        }

        if let hobby = categories.first(where: { $0.name == "趣味・娯楽" && $0.isMajor }) {
            budgets.append(SwiftDataBudget(amount: 30000, category: hobby, year: year, month: month))
        }

        return budgets
    }

    // MARK: - SwiftDataAnnualBudgetConfig

    /// サンプル年次特別枠設定
    internal static func createSampleAnnualBudgetConfig() -> SwiftDataAnnualBudgetConfig {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)

        return SwiftDataAnnualBudgetConfig(
            year: year,
            totalAmount: 500_000,
            policy: .automatic,
        )
    }
}

// MARK: - Private Helper Functions

/// 収入取引を作成
private func createIncomeTransactions(
    calendar: Calendar,
    now: Date,
    refs: CategoryAndInstitutionRefs,
) -> [SwiftDataTransaction] {
    [
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -25, to: now) ?? now,
            title: "給与",
            amount: 300_000,
            memo: "11月分給与",
            financialInstitution: refs.bank,
            majorCategory: refs.incomeCategory,
            minorCategory: refs.salary,
        ),
    ]
}

/// 支出取引を作成
private func createExpenseTransactions(
    calendar: Calendar,
    now: Date,
    refs: CategoryAndInstitutionRefs,
) -> [SwiftDataTransaction] {
    var transactions: [SwiftDataTransaction] = []
    transactions.append(contentsOf: createFoodTransactions(calendar: calendar, now: now, refs: refs))
    transactions.append(contentsOf: createTransportTransactions(calendar: calendar, now: now, refs: refs))
    transactions.append(contentsOf: createHobbyTransactions(calendar: calendar, now: now, refs: refs))
    return transactions
}

/// 食費取引を作成
private func createFoodTransactions(
    calendar: Calendar,
    now: Date,
    refs: CategoryAndInstitutionRefs,
) -> [SwiftDataTransaction] {
    [
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            title: "ランチ",
            amount: -1200,
            memo: "同僚とランチ",
            financialInstitution: refs.card,
            majorCategory: refs.food,
            minorCategory: refs.eating,
        ),
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            title: "居酒屋",
            amount: -4500,
            memo: "会社の飲み会",
            financialInstitution: refs.card,
            majorCategory: refs.food,
            minorCategory: refs.eating,
        ),
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            title: "スターバックス",
            amount: -680,
            financialInstitution: refs.cash,
            majorCategory: refs.food,
            minorCategory: refs.cafe,
        ),
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            title: "スーパー",
            amount: -3200,
            memo: "週末の食材",
            financialInstitution: refs.card,
            majorCategory: refs.food,
            minorCategory: refs.cooking,
        ),
    ]
}

/// 交通費取引を作成
private func createTransportTransactions(
    calendar: Calendar,
    now: Date,
    refs: CategoryAndInstitutionRefs,
) -> [SwiftDataTransaction] {
    [
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            title: "Suicaチャージ",
            amount: -3000,
            financialInstitution: refs.cash,
            majorCategory: refs.transport,
            minorCategory: refs.train,
        ),
    ]
}

/// 趣味・娯楽取引を作成
private func createHobbyTransactions(
    calendar: Calendar,
    now: Date,
    refs: CategoryAndInstitutionRefs,
) -> [SwiftDataTransaction] {
    [
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            title: "技術書",
            amount: -3800,
            memo: "Swift入門書",
            financialInstitution: refs.card,
            majorCategory: refs.hobby,
            minorCategory: refs.book,
        ),
        SwiftDataTransaction(
            date: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
            title: "Netflix",
            amount: -1490,
            memo: "月額料金",
            financialInstitution: refs.card,
            majorCategory: refs.hobby,
            minorCategory: refs.movie,
        ),
    ]
}

/// カテゴリと金融機関の参照をまとめて検索
private func findCategoriesAndInstitutions(
    categories: [SwiftDataCategory],
    institutions: [SwiftDataFinancialInstitution],
) -> CategoryAndInstitutionRefs {
    CategoryAndInstitutionRefs(
        food: categories.first { $0.name == "食費" },
        eating: categories.first { $0.name == "外食" },
        cooking: categories.first { $0.name == "自炊" },
        cafe: categories.first { $0.name == "カフェ" },
        hobby: categories.first { $0.name == "趣味・娯楽" },
        book: categories.first { $0.name == "書籍" },
        movie: categories.first { $0.name == "映画・動画" },
        transport: categories.first { $0.name == "交通費" },
        train: categories.first { $0.name == "電車" },
        incomeCategory: categories.first { $0.name == "収入" },
        salary: categories.first { $0.name == "給与" },
        card: institutions.first { $0.name == "楽天カード" },
        cash: institutions.first { $0.name == "現金" },
        bank: institutions.first { $0.name == "三菱UFJ銀行" },
    )
}

/// カテゴリと金融機関の参照を保持する構造体
private struct CategoryAndInstitutionRefs {
    internal let food: SwiftDataCategory?
    internal let eating: SwiftDataCategory?
    internal let cooking: SwiftDataCategory?
    internal let cafe: SwiftDataCategory?
    internal let hobby: SwiftDataCategory?
    internal let book: SwiftDataCategory?
    internal let movie: SwiftDataCategory?
    internal let transport: SwiftDataCategory?
    internal let train: SwiftDataCategory?
    internal let incomeCategory: SwiftDataCategory?
    internal let salary: SwiftDataCategory?
    internal let card: SwiftDataFinancialInstitution?
    internal let cash: SwiftDataFinancialInstitution?
    internal let bank: SwiftDataFinancialInstitution?
}

#endif
