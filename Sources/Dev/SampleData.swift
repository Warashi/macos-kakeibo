#if DEBUG
import Foundation

/// 開発・デバッグ用のサンプルデータ定義
internal enum SampleData {
    // MARK: - FinancialInstitution

    /// サンプル金融機関データ
    internal static func financialInstitutions() -> [FinancialInstitution] {
        [
            FinancialInstitution(name: "三菱UFJ銀行", displayOrder: 1),
            FinancialInstitution(name: "三井住友銀行", displayOrder: 2),
            FinancialInstitution(name: "楽天銀行", displayOrder: 3),
            FinancialInstitution(name: "PayPay銀行", displayOrder: 4),
            FinancialInstitution(name: "三井住友カード", displayOrder: 5),
            FinancialInstitution(name: "楽天カード", displayOrder: 6),
            FinancialInstitution(name: "現金", displayOrder: 7),
        ]
    }

    // MARK: - Category

    /// サンプルカテゴリデータ（階層構造）
    internal static func createSampleCategories() -> [Category] {
        var categories: [Category] = []

        // 食費
        let food = Category(name: "食費", allowsAnnualBudget: false, displayOrder: 1)
        food.addChild(Category(name: "外食", displayOrder: 1))
        food.addChild(Category(name: "自炊", displayOrder: 2))
        food.addChild(Category(name: "カフェ", displayOrder: 3))
        categories.append(food)
        categories.append(contentsOf: food.children)

        // 日用品
        let daily = Category(name: "日用品", allowsAnnualBudget: false, displayOrder: 2)
        daily.addChild(Category(name: "消耗品", displayOrder: 1))
        daily.addChild(Category(name: "衛生用品", displayOrder: 2))
        categories.append(daily)
        categories.append(contentsOf: daily.children)

        // 交通費
        let transport = Category(name: "交通費", allowsAnnualBudget: false, displayOrder: 3)
        transport.addChild(Category(name: "電車", displayOrder: 1))
        transport.addChild(Category(name: "バス", displayOrder: 2))
        transport.addChild(Category(name: "タクシー", displayOrder: 3))
        categories.append(transport)
        categories.append(contentsOf: transport.children)

        // 趣味・娯楽
        let hobby = Category(name: "趣味・娯楽", allowsAnnualBudget: true, displayOrder: 4)
        hobby.addChild(Category(name: "書籍", displayOrder: 1))
        hobby.addChild(Category(name: "映画・動画", displayOrder: 2))
        hobby.addChild(Category(name: "ゲーム", displayOrder: 3))
        categories.append(hobby)
        categories.append(contentsOf: hobby.children)

        // 特別費
        let special = Category(name: "特別費", allowsAnnualBudget: true, displayOrder: 5)
        special.addChild(Category(name: "旅行", displayOrder: 1))
        special.addChild(Category(name: "冠婚葬祭", displayOrder: 2))
        special.addChild(Category(name: "家電", displayOrder: 3))
        categories.append(special)
        categories.append(contentsOf: special.children)

        // 収入
        let income = Category(name: "収入", allowsAnnualBudget: false, displayOrder: 6)
        income.addChild(Category(name: "給与", displayOrder: 1))
        income.addChild(Category(name: "賞与", displayOrder: 2))
        income.addChild(Category(name: "その他", displayOrder: 3))
        categories.append(income)
        categories.append(contentsOf: income.children)

        return categories
    }

    // MARK: - Transaction

    /// サンプル取引データ
    internal static func createSampleTransactions(
        categories: [Category],
        institutions: [FinancialInstitution],
    ) -> [Transaction] {
        let refs = findCategoriesAndInstitutions(categories: categories, institutions: institutions)
        let calendar = Calendar.current
        let now = Date()

        var transactions: [Transaction] = []
        transactions.append(contentsOf: createIncomeTransactions(calendar: calendar, now: now, refs: refs))
        transactions.append(contentsOf: createExpenseTransactions(calendar: calendar, now: now, refs: refs))

        return transactions
    }

    // MARK: - Budget

    /// サンプル予算データ
    internal static func createSampleBudgets(categories: [Category]) -> [Budget] {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let year = components.year, let month = components.month else {
            return []
        }

        var budgets: [Budget] = []

        // 全体予算
        budgets.append(Budget(amount: 200_000, year: year, month: month))

        // カテゴリ別予算
        if let food = categories.first(where: { $0.name == "食費" && $0.isMajor }) {
            budgets.append(Budget(amount: 50000, category: food, year: year, month: month))
        }

        if let transport = categories.first(where: { $0.name == "交通費" && $0.isMajor }) {
            budgets.append(Budget(amount: 15000, category: transport, year: year, month: month))
        }

        if let hobby = categories.first(where: { $0.name == "趣味・娯楽" && $0.isMajor }) {
            budgets.append(Budget(amount: 30000, category: hobby, year: year, month: month))
        }

        return budgets
    }

    // MARK: - AnnualBudgetConfig

    /// サンプル年次特別枠設定
    internal static func createSampleAnnualBudgetConfig() -> AnnualBudgetConfig {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)

        return AnnualBudgetConfig(
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
) -> [Transaction] {
    [
        Transaction(
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
) -> [Transaction] {
    var transactions: [Transaction] = []
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
) -> [Transaction] {
    [
        Transaction(
            date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            title: "ランチ",
            amount: -1200,
            memo: "同僚とランチ",
            financialInstitution: refs.card,
            majorCategory: refs.food,
            minorCategory: refs.eating,
        ),
        Transaction(
            date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            title: "居酒屋",
            amount: -4500,
            memo: "会社の飲み会",
            financialInstitution: refs.card,
            majorCategory: refs.food,
            minorCategory: refs.eating,
        ),
        Transaction(
            date: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            title: "スターバックス",
            amount: -680,
            financialInstitution: refs.cash,
            majorCategory: refs.food,
            minorCategory: refs.cafe,
        ),
        Transaction(
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
) -> [Transaction] {
    [
        Transaction(
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
) -> [Transaction] {
    [
        Transaction(
            date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            title: "技術書",
            amount: -3800,
            memo: "Swift入門書",
            financialInstitution: refs.card,
            majorCategory: refs.hobby,
            minorCategory: refs.book,
        ),
        Transaction(
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
    categories: [Category],
    institutions: [FinancialInstitution],
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
    internal let food: Category?
    internal let eating: Category?
    internal let cooking: Category?
    internal let cafe: Category?
    internal let hobby: Category?
    internal let book: Category?
    internal let movie: Category?
    internal let transport: Category?
    internal let train: Category?
    internal let incomeCategory: Category?
    internal let salary: Category?
    internal let card: FinancialInstitution?
    internal let cash: FinancialInstitution?
    internal let bank: FinancialInstitution?
}

#endif
