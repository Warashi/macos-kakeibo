import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SampleData Tests")
internal struct SampleDataTests {
    // MARK: - FinancialInstitution Tests

    @Test("サンプル金融機関データが定義されている")
    internal func sampleFinancialInstitutionsData() {
        let institutions = SampleData.financialInstitutions()

        #expect(!institutions.isEmpty)
        #expect(institutions.count == 7)
        #expect(institutions.contains { $0.name == "三菱UFJ銀行" })
        #expect(institutions.contains { $0.name == "楽天銀行" })
        #expect(institutions.contains { $0.name == "現金" })
    }

    @Test("金融機関は表示順序が設定されている")
    internal func financialInstitutionsDisplayOrder() {
        let institutions = SampleData.financialInstitutions()

        for institution in institutions {
            #expect(institution.displayOrder > 0)
        }
    }

    // MARK: - Category Tests

    @Test("サンプルカテゴリデータが生成できる")
    internal func sampleCategoriesData() {
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
    internal func categoryHierarchyStructure() {
        let categories = SampleData.createSampleCategories()

        let food = categories.first { $0.name == "食費" && $0.isMajor }
        #expect(food != nil)
        #expect(food?.children.count ?? 0 >= 3)
        #expect(food?.children.contains { $0.name == "外食" } == true)
        #expect(food?.children.contains { $0.name == "自炊" } == true)
        #expect(food?.children.contains { $0.name == "カフェ" } == true)
    }

    @Test("カテゴリは年次特別枠フラグが適切に設定されている")
    internal func categoryAnnualBudgetFlag() {
        let categories = SampleData.createSampleCategories()

        let hobby = categories.first { $0.name == "趣味・娯楽" && $0.isMajor }
        #expect(hobby?.allowsAnnualBudget == true)

        let special = categories.first { $0.name == "特別費" && $0.isMajor }
        #expect(special?.allowsAnnualBudget == true)

        let food = categories.first { $0.name == "食費" && $0.isMajor }
        #expect(food?.allowsAnnualBudget == false)
    }

    // MARK: - SwiftDataTransaction Tests

    @Test("サンプル取引データが生成できる")
    internal func sampleTransactionsData() {
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
    internal func transactionsIncomeAndExpense() {
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
    internal func transactionsValidation() {
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
    internal func sampleBudgetsData() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        #expect(!budgets.isEmpty)
    }

    @Test("予算データには全体予算が含まれる")
    internal func overallBudget() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        let overallBudget = budgets.first { $0.category == nil }
        #expect(overallBudget != nil)
        #expect(overallBudget?.amount ?? 0 > 0)
    }

    @Test("予算データは有効なデータである")
    internal func budgetsValidation() {
        let categories = SampleData.createSampleCategories()
        let budgets = SampleData.createSampleBudgets(categories: categories)

        for budget in budgets {
            #expect(budget.isValid)
        }
    }

    // MARK: - SwiftDataAnnualBudgetConfig Tests

    @Test("サンプル年次特別枠設定が生成できる")
    internal func sampleAnnualBudgetConfig() {
        let config = SampleData.createSampleAnnualBudgetConfig()

        #expect(config.totalAmount > 0)
        #expect(config.policy == .automatic)
    }

    @Test("年次特別枠設定は有効なデータである")
    internal func annualBudgetConfigValidation() {
        let config = SampleData.createSampleAnnualBudgetConfig()

        #expect(config.isValid)
    }
}
