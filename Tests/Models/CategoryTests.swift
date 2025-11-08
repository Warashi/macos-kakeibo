import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("Category Tests")
internal struct CategoryTests {
    // MARK: - 初期化テスト

    @Test("カテゴリを初期化できる")
    internal func カテゴリ初期化() {
        let category = Category(name: "食費")

        #expect(category.name == "食費")
        #expect(category.parent == nil)
        #expect(category.children.isEmpty)
        #expect(category.allowsAnnualBudget == false)
        #expect(category.displayOrder == 0)
    }

    @Test("パラメータ付きでカテゴリを初期化できる")
    internal func パラメータ付きカテゴリ初期化() {
        let category = Category(
            name: "外食",
            allowsAnnualBudget: true,
            displayOrder: 10,
        )

        #expect(category.name == "外食")
        #expect(category.allowsAnnualBudget == true)
        #expect(category.displayOrder == 10)
    }

    // MARK: - 階層構造テスト

    @Test("親子関係を設定できる")
    internal func 親子関係設定() {
        let parent = Category(name: "食費")
        let child = Category(name: "外食", parent: parent)

        #expect(child.parent === parent)
    }

    @Test("addChildメソッドで子カテゴリを追加できる")
    internal func 子カテゴリ追加() {
        let parent = Category(name: "食費")
        let child = Category(name: "外食")

        parent.addChild(child)

        #expect(parent.children.count == 1)
        #expect(parent.children.first === child)
        #expect(child.parent === parent)
    }

    @Test("複数の子カテゴリを追加できる")
    internal func 複数子カテゴリ追加() {
        let parent = Category(name: "食費")
        let child1 = Category(name: "外食")
        let child2 = Category(name: "自炊")

        parent.addChild(child1)
        parent.addChild(child2)

        #expect(parent.children.count == 2)
        #expect(parent.children.contains { $0 === child1 })
        #expect(parent.children.contains { $0 === child2 })
    }

    // MARK: - Computed Properties テスト

    @Test("isMajorは親がnilの場合にtrueを返す")
    internal func 大項目判定() {
        let category = Category(name: "食費")
        #expect(category.isMajor == true)
        #expect(category.isMinor == false)
    }

    @Test("isMinorは親がある場合にtrueを返す")
    internal func 中項目判定() {
        let parent = Category(name: "食費")
        let child = Category(name: "外食", parent: parent)

        #expect(child.isMajor == false)
        #expect(child.isMinor == true)
    }

    @Test("fullNameは大項目の場合、名前のみを返す")
    internal func 大項目フルパス名() {
        let category = Category(name: "食費")
        #expect(category.fullName == "食費")
    }

    @Test("fullNameは中項目の場合、親/子の形式を返す")
    internal func 中項目フルパス名() {
        let parent = Category(name: "食費")
        let child = Category(name: "外食", parent: parent)

        #expect(child.fullName == "食費 / 外食")
    }

    // MARK: - Convenience メソッドテスト

    @Test("childメソッドで名前から子カテゴリを取得できる")
    internal func 名前から子カテゴリ取得() {
        let parent = Category(name: "食費")
        let child1 = Category(name: "外食")
        let child2 = Category(name: "自炊")

        parent.addChild(child1)
        parent.addChild(child2)

        let found = parent.child(named: "外食")
        #expect(found === child1)
    }

    @Test("childメソッドで存在しない名前を指定するとnilを返す")
    internal func 存在しない子カテゴリ取得() {
        let parent = Category(name: "食費")
        let child = Category(name: "外食")

        parent.addChild(child)

        let found = parent.child(named: "旅行")
        #expect(found == nil)
    }

    // MARK: - 年次特別枠テスト

    @Test("年次特別枠の使用可否を設定できる")
    internal func 年次特別枠設定() {
        let category = Category(name: "特別", allowsAnnualBudget: true)
        #expect(category.allowsAnnualBudget == true)
    }

    // MARK: - 表示順序テスト

    @Test("表示順序を設定できる")
    internal func 表示順序設定() {
        let category1 = Category(name: "食費", displayOrder: 1)
        let category2 = Category(name: "日用品", displayOrder: 2)

        #expect(category1.displayOrder == 1)
        #expect(category2.displayOrder == 2)
    }

    // MARK: - 日時テスト

    @Test("作成日時と更新日時が設定される")
    internal func 作成更新日時設定() {
        let before = Date()
        let category = Category(name: "食費")
        let after = Date()

        #expect(category.createdAt >= before)
        #expect(category.createdAt <= after)
        #expect(category.updatedAt >= before)
        #expect(category.updatedAt <= after)
        #expect(category.createdAt == category.updatedAt)
    }
}
