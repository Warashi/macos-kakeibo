import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SampleData Tests")
internal struct SampleDataTests {
    // MARK: - FinancialInstitution Tests

    @Test("サンプル金融機関データが定義されている")
    internal func サンプル金融機関データ() {
        let institutions = SampleData.financialInstitutions()

        #expect(!institutions.isEmpty)
        #expect(institutions.count == 7)
        #expect(institutions.contains { $0.name == "三菱UFJ銀行" })
        #expect(institutions.contains { $0.name == "楽天銀行" })
        #expect(institutions.contains { $0.name == "現金" })
    }

    @Test("金融機関は表示順序が設定されている")
    internal func 金融機関表示順序() {
        let institutions = SampleData.financialInstitutions()

        for institution in institutions {
            #expect(institution.displayOrder > 0)
        }
    }

    // MARK: - Category Tests

    @Test("サンプルカテゴリデータが生成できる")
    internal func サンプルカテゴリデータ() {
        let categories = SampleData.createSampleCategories()

        #expect(!categories.isEmpty)

        // 大項目の確認
        let majorCategories = categories.filter(\.isMajor)
        #expect(majorCategories.count == 6)
        #expect(majorCategories.contains { $0.name == "食費" })
        #expect(majorCategories.contains { $0.name == "日用品" })
        #expect(majorCategories.contains { $0.name == "交通費" })
        #expect(majorCategories.contains { $0.name == "趣味・娯楽" })
        #expect(majorCategories.contains { $0.name == "特別費" })
        #expect(majorCategories.contains { $0.name == "収入" })
    }

    @Test("カテゴリは階層構造を持つ")
    internal func カテゴリ階層構造() {
        let categories = SampleData.createSampleCategories()

        let food = categories.first { $0.name == "食費" && $0.isMajor }
        #expect(food != nil)
        #expect(food?.children.count ?? 0 >= 3)
        #expect(food?.children.contains { $0.name == "外食" } == true)
        #expect(food?.children.contains { $0.name == "自炊" } == true)
        #expect(food?.children.contains { $0.name == "カフェ" } == true)
    }

    @Test("カテゴリは年次特別枠フラグが適切に設定されている")
    internal func カテゴリ年次特別枠フラグ() {
        let categories = SampleData.createSampleCategories()

        let hobby = categories.first { $0.name == "趣味・娯楽" && $0.isMajor }
        #expect(hobby?.allowsAnnualBudget == true)

        let special = categories.first { $0.name == "特別費" && $0.isMajor }
        #expect(special?.allowsAnnualBudget == true)

        let food = categories.first { $0.name == "食費" && $0.isMajor }
        #expect(food?.allowsAnnualBudget == false)
    }

    // MARK: - Transaction Tests

    @Test("サンプル取引データが生成できる")
    internal func サンプル取引データ() {
        let categories = SampleData.createSampleCategories()
        let institutions = SampleData.financialInstitutions()
        let transactions = SampleData.createSampleTransactions(
            categories: categories,
            institutions: institutions,
        )

        #expect(!transactions.isEmpty)
        #expect(transactions.count >= 5)
    }

    @Test("取引データに収入と支出が含まれる")
    internal func 取引データ収入支出() {
        let categories = SampleData.createSampleCategories()
        let institutions = SampleData.financialInstitutions()
        let transactions = SampleData.createSampleTransactions(
            categories: categories,
            institutions: institutions,
        )

        let income = transactions.filter(\.isIncome)
        let expense = transactions.filter(\.isExpense)

        #expect(!income.isEmpty)
        #expect(!expense.isEmpty)
    }

    @Test("取引データは有効なデータである")
    internal func 取引データバリデーション() {
        let categories = SampleData.createSampleCategories()
        let institutions = SampleData.financialInstitutions()
        let transactions = SampleData.createSampleTransactions(
            categories: categories,
            institutions: institutions,
        )

        for transaction in transactions {
            #expect(transaction.isValid)
        }
    }

    // MARK: - Budget Tests

    @Test("サンプル予算データが生成できる")
    internal func サンプル予算データ() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        #expect(!budgets.isEmpty)
    }

    @Test("予算データには全体予算が含まれる")
    internal func 全体予算() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        let overallBudget = budgets.first { $0.category == nil }
        #expect(overallBudget != nil)
        #expect(overallBudget?.amount ?? 0 > 0)
    }

    @Test("予算データは有効なデータである")
    internal func 予算データバリデーション() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        for budget in budgets {
            #expect(budget.isValid)
        }
    }

    // MARK: - AnnualBudgetConfig Tests

    @Test("サンプル年次特別枠設定が生成できる")
    internal func サンプル年次特別枠設定() {
        let config = SampleData.createSampleAnnualBudgetConfig()

        #expect(config.totalAmount > 0)
        #expect(config.policy == .automatic)
    }

    @Test("年次特別枠設定は有効なデータである")
    internal func 年次特別枠設定バリデーション() {
        let config = SampleData.createSampleAnnualBudgetConfig()

        #expect(config.isValid)
    }
}
