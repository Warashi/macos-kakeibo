import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("Budget Tests")
internal struct BudgetTests {
    // MARK: - 初期化テスト

    @Test("予算を初期化できる")
    internal func 予算初期化() {
        let budget = Budget(
            amount: 50000,
            year: 2025,
            month: 11,
        )

        #expect(budget.amount == 50000)
        #expect(budget.year == 2025)
        #expect(budget.month == 11)
        #expect(budget.category == nil)
    }

    @Test("カテゴリ付きで予算を初期化できる")
    internal func カテゴリ付き予算初期化() {
        let category = Category(name: "食費")
        let budget = Budget(
            amount: 30000,
            category: category,
            year: 2025,
            month: 11,
        )

        #expect(budget.amount == 30000)
        #expect(budget.category === category)
        #expect(budget.year == 2025)
        #expect(budget.month == 11)
    }

    // MARK: - Computed Properties テスト

    @Test("yearMonthStringは正しいフォーマットを返す")
    internal func 年月文字列() {
        let budget = Budget(amount: 50000, year: 2025, month: 11)
        #expect(budget.yearMonthString == "2025-11")

        let budget2 = Budget(amount: 30000, year: 2025, month: 3)
        #expect(budget2.yearMonthString == "2025-03")
    }

    @Test("targetDateは正しい日付を返す")
    internal func 対象日付() {
        let budget = Budget(amount: 50000, year: 2025, month: 11)
        let date = budget.targetDate

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        #expect(components.year == 2025)
        #expect(components.month == 11)
        #expect(components.day == 1)
    }

    // MARK: - バリデーションテスト

    @Test("有効な予算データの場合、バリデーションエラーがない")
    internal func 有効な予算バリデーション() {
        let budget = Budget(
            amount: 50000,
            year: 2025,
            month: 11,
        )

        let errors = budget.validate()
        #expect(errors.isEmpty)
        #expect(budget.isValid == true)
    }

    @Test("予算額が0以下の場合、バリデーションエラーが発生する")
    internal func 予算額ゼロ以下バリデーション() {
        let budget1 = Budget(amount: 0, year: 2025, month: 11)
        let budget2 = Budget(amount: -1000, year: 2025, month: 11)

        let errors1 = budget1.validate()
        let errors2 = budget2.validate()

        #expect(!errors1.isEmpty)
        #expect(errors1.contains { $0.contains("予算額は0より大きい") })
        #expect(budget1.isValid == false)

        #expect(!errors2.isEmpty)
        #expect(budget2.isValid == false)
    }

    @Test("年が不正な場合、バリデーションエラーが発生する")
    internal func 年不正バリデーション() {
        let budget1 = Budget(amount: 50000, year: 1999, month: 11)
        let budget2 = Budget(amount: 50000, year: 2101, month: 11)

        let errors1 = budget1.validate()
        let errors2 = budget2.validate()

        #expect(!errors1.isEmpty)
        #expect(errors1.contains { $0.contains("年が不正") })
        #expect(budget1.isValid == false)

        #expect(!errors2.isEmpty)
        #expect(budget2.isValid == false)
    }

    @Test("月が不正な場合、バリデーションエラーが発生する")
    internal func 月不正バリデーション() {
        let budget1 = Budget(amount: 50000, year: 2025, month: 0)
        let budget2 = Budget(amount: 50000, year: 2025, month: 13)

        let errors1 = budget1.validate()
        let errors2 = budget2.validate()

        #expect(!errors1.isEmpty)
        #expect(errors1.contains { $0.contains("月が不正") })
        #expect(budget1.isValid == false)

        #expect(!errors2.isEmpty)
        #expect(budget2.isValid == false)
    }

    @Test("複数のバリデーションエラーがある場合、すべて検出される")
    internal func 複数バリデーションエラー() {
        let budget = Budget(amount: -1000, year: 1999, month: 13)

        let errors = budget.validate()
        #expect(errors.count == 3)
        #expect(errors.contains { $0.contains("予算額") })
        #expect(errors.contains { $0.contains("年が不正") })
        #expect(errors.contains { $0.contains("月が不正") })
    }

    // MARK: - 日時テスト

    @Test("作成日時と更新日時が設定される")
    internal func 作成更新日時設定() {
        let before = Date()
        let budget = Budget(amount: 50000, year: 2025, month: 11)
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
    internal func 年次特別枠初期化() {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
        )

        #expect(config.year == 2025)
        #expect(config.totalAmount == 200_000)
        #expect(config.policy == .automatic)
    }

    @Test("充当ポリシー付きで年次特別枠設定を初期化できる")
    internal func ポリシー付き年次特別枠初期化() {
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
    internal func ポリシー変更() {
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
    internal func 有効な年次特別枠バリデーション() {
        let config = AnnualBudgetConfig(
            year: 2025,
            totalAmount: 200_000,
        )

        let errors = config.validate()
        #expect(errors.isEmpty)
        #expect(config.isValid == true)
    }

    @Test("総額が0以下の場合、バリデーションエラーが発生する")
    internal func 総額ゼロ以下バリデーション() {
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
    internal func 年不正バリデーション() {
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
    internal func 作成更新日時設定() {
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
