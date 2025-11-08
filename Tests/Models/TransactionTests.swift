import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("Transaction Initialization Tests")
internal struct TransactionInitializationTests {
    @Test("取引を初期化できる")
    internal func 取引初期化() {
        let date = Date()
        let transaction = Transaction(
            date: date,
            title: "コンビニ",
            amount: -680,
        )

        #expect(transaction.title == "コンビニ")
        #expect(transaction.amount == -680)
        #expect(transaction.date == date)
        #expect(transaction.memo == "")
        #expect(transaction.isIncludedInCalculation == true)
        #expect(transaction.isTransfer == false)
        #expect(transaction.financialInstitution == nil)
        #expect(transaction.majorCategory == nil)
        #expect(transaction.minorCategory == nil)
    }

    @Test("すべてのパラメータ付きで取引を初期化できる")
    internal func フルパラメータ取引初期化() {
        let date = Date()
        let institution = FinancialInstitution(name: "三菱UFJ")
        let majorCategory = Category(name: "食費")
        let minorCategory = Category(name: "外食", parent: majorCategory)

        let transaction = Transaction(
            date: date,
            title: "ランチ",
            amount: -1200,
            memo: "同僚とランチ",
            isIncludedInCalculation: true,
            isTransfer: false,
            financialInstitution: institution,
            majorCategory: majorCategory,
            minorCategory: minorCategory,
        )

        #expect(transaction.title == "ランチ")
        #expect(transaction.amount == -1200)
        #expect(transaction.memo == "同僚とランチ")
        #expect(transaction.isIncludedInCalculation == true)
        #expect(transaction.isTransfer == false)
        #expect(transaction.financialInstitution === institution)
        #expect(transaction.majorCategory === majorCategory)
        #expect(transaction.minorCategory === minorCategory)
    }
}

@Suite("Transaction Computed Property Tests")
internal struct TransactionComputedPropertyTests {
    @Test("isExpenseはマイナス金額の場合にtrueを返す")
    internal func 支出判定() {
        let transaction = Transaction(
            date: Date(),
            title: "買い物",
            amount: -1000,
        )
        #expect(transaction.isExpense == true)
        #expect(transaction.isIncome == false)
    }

    @Test("isIncomeはプラス金額の場合にtrueを返す")
    internal func 収入判定() {
        let transaction = Transaction(
            date: Date(),
            title: "給料",
            amount: 300_000,
        )
        #expect(transaction.isIncome == true)
        #expect(transaction.isExpense == false)
    }

    @Test("ゼロ金額の場合、isExpenseとisIncomeは両方falseを返す")
    internal func ゼロ金額判定() {
        let transaction = Transaction(
            date: Date(),
            title: "テスト",
            amount: 0,
        )
        #expect(transaction.isExpense == false)
        #expect(transaction.isIncome == false)
    }

    @Test("absoluteAmountは絶対値を返す")
    internal func 絶対値金額() {
        let transaction1 = Transaction(date: Date(), title: "支出", amount: -1000)
        let transaction2 = Transaction(date: Date(), title: "収入", amount: 5000)

        #expect(transaction1.absoluteAmount == 1000)
        #expect(transaction2.absoluteAmount == 5000)
    }

    @Test("categoryFullNameは中項目がある場合フルパスを返す")
    internal func カテゴリフルパス名_中項目あり() {
        let major = Category(name: "食費")
        let minor = Category(name: "外食", parent: major)

        let transaction = Transaction(
            date: Date(),
            title: "ランチ",
            amount: -1000,
            majorCategory: major,
            minorCategory: minor,
        )

        #expect(transaction.categoryFullName == "食費 / 外食")
    }

    @Test("categoryFullNameは大項目のみの場合その名前を返す")
    internal func カテゴリフルパス名_大項目のみ() {
        let major = Category(name: "食費")

        let transaction = Transaction(
            date: Date(),
            title: "買い物",
            amount: -1000,
            majorCategory: major,
        )

        #expect(transaction.categoryFullName == "食費")
    }

    @Test("categoryFullNameはカテゴリ未設定の場合「未分類」を返す")
    internal func カテゴリフルパス名_未分類() {
        let transaction = Transaction(
            date: Date(),
            title: "買い物",
            amount: -1000,
        )

        #expect(transaction.categoryFullName == "未分類")
    }
}

@Suite("Transaction Validation Tests")
internal struct TransactionValidationTests {
    @Test("有効な取引データの場合、バリデーションエラーがない")
    internal func 有効な取引バリデーション() {
        let major = Category(name: "食費")
        let minor = Category(name: "外食", parent: major)

        let transaction = Transaction(
            date: Date(),
            title: "ランチ",
            amount: -1000,
            majorCategory: major,
            minorCategory: minor,
        )

        let errors = transaction.validate()
        #expect(errors.isEmpty)
        #expect(transaction.isValid == true)
    }

    @Test("内容が空の場合、バリデーションエラーが発生する")
    internal func 内容空バリデーション() {
        let transaction = Transaction(
            date: Date(),
            title: "",
            amount: -1000,
        )

        let errors = transaction.validate()
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("内容が空") })
        #expect(transaction.isValid == false)
    }

    @Test("金額が0の場合、バリデーションエラーが発生する")
    internal func 金額ゼロバリデーション() {
        let transaction = Transaction(
            date: Date(),
            title: "テスト",
            amount: 0,
        )

        let errors = transaction.validate()
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("金額が0") })
        #expect(transaction.isValid == false)
    }

    @Test("中項目のみ設定されている場合、バリデーションエラーが発生する")
    internal func 中項目のみバリデーション() {
        let minor = Category(name: "外食")

        let transaction = Transaction(
            date: Date(),
            title: "ランチ",
            amount: -1000,
            minorCategory: minor,
        )

        let errors = transaction.validate()
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("大項目が未設定") })
        #expect(transaction.isValid == false)
    }

    @Test("中項目の親と大項目が一致しない場合、バリデーションエラーが発生する")
    internal func カテゴリ不整合バリデーション() {
        let major1 = Category(name: "食費")
        let major2 = Category(name: "日用品")
        let minor = Category(name: "外食", parent: major1)

        let transaction = Transaction(
            date: Date(),
            title: "ランチ",
            amount: -1000,
            majorCategory: major2, // 中項目の親と異なる大項目
            minorCategory: minor,
        )

        let errors = transaction.validate()
        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("親カテゴリと大項目が一致しません") })
        #expect(transaction.isValid == false)
    }

    @Test("複数のバリデーションエラーがある場合、すべて検出される")
    internal func 複数バリデーションエラー() {
        let transaction = Transaction(
            date: Date(),
            title: "",
            amount: 0,
        )

        let errors = transaction.validate()
        #expect(errors.count == 2)
        #expect(errors.contains { $0.contains("内容が空") })
        #expect(errors.contains { $0.contains("金額が0") })
    }
}

@Suite("Transaction Flag Tests")
internal struct TransactionFlagTests {
    @Test("計算対象フラグを設定できる")
    internal func 計算対象フラグ() {
        let transaction1 = Transaction(
            date: Date(),
            title: "テスト1",
            amount: -1000,
            isIncludedInCalculation: true,
        )
        let transaction2 = Transaction(
            date: Date(),
            title: "テスト2",
            amount: -1000,
            isIncludedInCalculation: false,
        )

        #expect(transaction1.isIncludedInCalculation == true)
        #expect(transaction2.isIncludedInCalculation == false)
    }

    @Test("振替フラグを設定できる")
    internal func 振替フラグ() {
        let transaction1 = Transaction(
            date: Date(),
            title: "振替",
            amount: -10000,
            isTransfer: true,
        )
        let transaction2 = Transaction(
            date: Date(),
            title: "買い物",
            amount: -1000,
            isTransfer: false,
        )

        #expect(transaction1.isTransfer == true)
        #expect(transaction2.isTransfer == false)
    }
}

@Suite("Transaction Timestamp Tests")
internal struct TransactionTimestampTests {
    @Test("作成日時と更新日時が設定される")
    internal func 作成更新日時設定() {
        let before = Date()
        let transaction = Transaction(
            date: Date(),
            title: "テスト",
            amount: -1000,
        )
        let after = Date()

        #expect(transaction.createdAt >= before)
        #expect(transaction.createdAt <= after)
        #expect(transaction.updatedAt >= before)
        #expect(transaction.updatedAt <= after)
        #expect(transaction.createdAt == transaction.updatedAt)
    }
}
