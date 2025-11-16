import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("BudgetEntity Tests")
internal struct BudgetEntityTests {
    // MARK: - 初期化テスト

    @Test("予算を初期化できる")
    internal func initializeBudget() {
        let budget = BudgetEntity(
            amount: 50000,
            startYear: 2025,
            startMonth: 11,
            endYear: 2025,
            endMonth: 12,
        )

        #expect(budget.startYear == 2025)
        #expect(budget.startMonth == 11)
        #expect(budget.endYear == 2025)
        #expect(budget.endMonth == 12)
        #expect(budget.category == nil)
    }

    @Test("カテゴリ付きで予算を初期化できる")
    internal func initializeBudgetWithCategoryEntity() {
        let category = CategoryEntity(name: "食費")
        let budget = BudgetEntity(
            amount: 30000,
            category: category,
            startYear: 2025,
            startMonth: 10,
            endYear: 2026,
            endMonth: 3,
        )

        #expect(budget.category === category)
        #expect(budget.startYear == 2025)
        #expect(budget.endYear == 2026)
    }

    // MARK: - Computed Properties

    @Test("yearMonthStringは開始年月を返す")
    internal func yearMonthString() {
        let budget = BudgetEntity(amount: 50000, year: 2025, month: 11)
        #expect(budget.yearMonthString == "2025-11")
    }

    @Test("ターゲット日付と終了日付を取得できる")
    internal func targetAndEndDate() {
        let budget = BudgetEntity(
            amount: 50000,
            startYear: 2025,
            startMonth: 11,
            endYear: 2026,
            endMonth: 3,
        )
        let calendar = Calendar.current

        let startComponents = calendar.dateComponents([.year, .month, .day], from: budget.targetDate)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: budget.endDate)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 11)
        #expect(startComponents.day == 1)
        #expect(endComponents.year == 2026)
        #expect(endComponents.month == 3)
        #expect(endComponents.day == 1)
    }

    @Test("期間内判定ができる")
    internal func containsYearMonth() {
        let budget = BudgetEntity(amount: 10000, startYear: 2025, startMonth: 4, endYear: 2025, endMonth: 6)
        #expect(budget.contains(year: 2025, month: 4))
        #expect(budget.contains(year: 2025, month: 5))
        #expect(budget.contains(year: 2025, month: 6))
        #expect(!budget.contains(year: 2025, month: 7))
    }

    // MARK: - バリデーション

    @Test("有効な予算データの場合、バリデーションエラーがない")
    internal func validateValidBudget() {
        let budget = BudgetEntity(amount: 50000, year: 2025, month: 11)
        #expect(budget.validate().isEmpty)
        #expect(budget.isValid)
    }

    @Test("予算額が0以下の場合、バリデーションエラーになる")
    internal func validateBudgetAmountZeroOrNegative() {
        let zeroBudget = BudgetEntity(amount: 0, year: 2025, month: 11)
        let negativeBudget = BudgetEntity(amount: -1, year: 2025, month: 11)

        #expect(!zeroBudget.validate().isEmpty)
        #expect(!negativeBudget.validate().isEmpty)
        #expect(!zeroBudget.isValid)
        #expect(!negativeBudget.isValid)
    }

    @Test("年が不正な場合、バリデーションエラーになる")
    internal func validateInvalidYear() {
        let invalidStart = BudgetEntity(amount: 50000, startYear: 1999, startMonth: 11, endYear: 2000, endMonth: 1)
        let invalidEnd = BudgetEntity(amount: 50000, startYear: 2025, startMonth: 1, endYear: 2101, endMonth: 1)

        #expect(invalidStart.validate().contains { $0.contains("開始年が不正") })
        #expect(invalidEnd.validate().contains { $0.contains("終了年が不正") })
    }

    @Test("月が不正な場合、バリデーションエラーになる")
    internal func validateInvalidMonth() {
        let invalidStart = BudgetEntity(amount: 50000, startYear: 2025, startMonth: 0, endYear: 2025, endMonth: 1)
        let invalidEnd = BudgetEntity(amount: 50000, startYear: 2025, startMonth: 1, endYear: 2025, endMonth: 13)

        #expect(invalidStart.validate().contains { $0.contains("開始月が不正") })
        #expect(invalidEnd.validate().contains { $0.contains("終了月が不正") })
    }

    @Test("終了月が開始月より前の場合エラーになる")
    internal func validateEndBeforeStart() {
        let budget = BudgetEntity(amount: 50000, startYear: 2025, startMonth: 5, endYear: 2025, endMonth: 4)
        #expect(budget.validate().contains { $0.contains("終了月は開始月以降を設定してください") })
    }

    @Test("複数のバリデーションエラーがある場合でも検出できる")
    internal func validateMultipleErrors() {
        let budget = BudgetEntity(amount: -1000, startYear: 1999, startMonth: 13, endYear: 1998, endMonth: 0)
        let errors = budget.validate()
        #expect(errors.contains { $0.contains("予算額") })
        #expect(errors.contains { $0.contains("開始年が不正") })
        #expect(errors.contains { $0.contains("終了年が不正") })
        #expect(errors.contains { $0.contains("開始月が不正") })
        #expect(errors.contains { $0.contains("終了月が不正") })
    }

    // MARK: - 日時

    @Test("作成日時と更新日時が設定される")
    internal func setCreatedAndUpdatedDates() {
        let before = Date()
        let budget = BudgetEntity(amount: 50000, year: 2025, month: 11)
        let after = Date()

        #expect(budget.createdAt >= before)
        #expect(budget.createdAt <= after)
        #expect(budget.updatedAt >= before)
        #expect(budget.updatedAt <= after)
        #expect(budget.createdAt == budget.updatedAt)
    }
}

@Suite("AnnualBudgetConfig Tests")
internal struct AnnualBudgetConfigTests {
    // MARK: - 初期化テスト

    @Test("年次特別枠設定を初期化できる")
    internal func initializeAnnualBudgetConfig() {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
        )

        #expect(config.year == 2025)
        #expect(config.totalAmount == 200_000)
        #expect(config.policy == .automatic)
    }

    @Test("充当ポリシー付きで年次特別枠設定を初期化できる")
    internal func initializeAnnualBudgetConfigWithPolicy() {
        let config1 = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
            policy: .automatic,
        )
        let config2 = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
            policy: .manual,
        )
        let config3 = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
            policy: .disabled,
        )

        #expect(config1.policy == .automatic)
        #expect(config2.policy == .manual)
        #expect(config3.policy == .disabled)
    }

    // MARK: - ポリシー変更テスト

    @Test("充当ポリシーを変更できる")
    internal func changePolicy() {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
            policy: .automatic,
        )

        #expect(config.policy == .automatic)

        config.policy = .manual
        #expect(config.policy == .manual)

        config.policy = .disabled
        #expect(config.policy == .disabled)
    }

    // MARK: - バリデーションテスト

    @Test("有効な年次特別枠設定の場合、バリデーションエラーがない")
    internal func validateValidAnnualBudgetConfig() {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
        )

        let errors = config.validate()
        #expect(errors.isEmpty)
        #expect(config.isValid == true)
    }

    @Test("総額が0以下の場合、バリデーションエラーが発生する")
    internal func validateTotalAmountZeroOrNegative() {
        let config1 = AnnualBudgetConfig(year: 2025, totalAmount: 0)
        let config2 = AnnualBudgetConfig(year: 2025, totalAmount: -10000)

        let errors1 = config1.validate()
        let errors2 = config2.validate()

        #expect(!errors1.isEmpty)
        #expect(errors1.contains { $0.contains("年次特別枠の総額は0より大きい") })
        #expect(config1.isValid == false)

        #expect(!errors2.isEmpty)
        #expect(config2.isValid == false)
    }

    @Test("年が不正な場合、バリデーションエラーが発生する")
    internal func validateInvalidYearForAnnualBudget() {
        let config1 = AnnualBudgetConfig(year: 1999, totalAmount: 200_000)
        let config2 = AnnualBudgetConfig(year: 2101, totalAmount: 200_000)

        let errors1 = config1.validate()
        let errors2 = config2.validate()

        #expect(!errors1.isEmpty)
        #expect(errors1.contains { $0.contains("年が不正") })
        #expect(config1.isValid == false)

        #expect(!errors2.isEmpty)
        #expect(config2.isValid == false)
    }

    // MARK: - 日時テスト

    @Test("作成日時と更新日時が設定される")
    internal func setCreatedAndUpdatedDatesForAnnualBudget() {
        let before = Date()
        let config = AnnualBudgetConfig(year: 2025, totalAmount: 200_000)
        let after = Date()

        #expect(config.createdAt >= before)
        #expect(config.createdAt <= after)
        #expect(config.updatedAt >= before)
        #expect(config.updatedAt <= after)
        #expect(config.createdAt == config.updatedAt)
    }
}
