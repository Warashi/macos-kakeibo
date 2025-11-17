import Foundation
@testable import Kakeibo
import SwiftData
import Testing

@Suite("SwiftDataCategory Tests")
internal struct SwiftDataCategoryTests {
    // MARK: - 初期化テスト

    @Test("カテゴリを初期化できる")
    internal func initializeSwiftDataCategory() {
        let category = SwiftDataCategory(name: "食費")

        #expect(category.name == "食費")
        #expect(category.parent == nil)
        #expect(category.children.isEmpty)
        #expect(category.allowsAnnualBudget == false)
        #expect(category.displayOrder == 0)
    }

    @Test("パラメータ付きでカテゴリを初期化できる")
    internal func initializeCategoryWithParameters() {
        let category = SwiftDataCategory(
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
    internal func setParentChildRelationship() {
        let parent = SwiftDataCategory(name: "食費")
        let child = SwiftDataCategory(name: "外食", parent: parent)

        #expect(child.parent === parent)
    }

    @Test("addChildメソッドで子カテゴリを追加できる")
    internal func addChildSwiftDataCategory() {
        let parent = SwiftDataCategory(name: "食費")
        let child = SwiftDataCategory(name: "外食")

        parent.addChild(child)

        #expect(parent.children.count == 1)
        #expect(parent.children.first === child)
        #expect(child.parent === parent)
    }

    @Test("複数の子カテゴリを追加できる")
    internal func addMultipleChildCategories() {
        let parent = SwiftDataCategory(name: "食費")
        let child1 = SwiftDataCategory(name: "外食")
        let child2 = SwiftDataCategory(name: "自炊")

        parent.addChild(child1)
        parent.addChild(child2)

        #expect(parent.children.count == 2)
        #expect(parent.children.contains { $0 === child1 })
        #expect(parent.children.contains { $0 === child2 })
    }

    // MARK: - Computed Properties テスト

    @Test("isMajorは親がnilの場合にtrueを返す")
    internal func checkIsMajor() {
        let category = SwiftDataCategory(name: "食費")
        #expect(category.isMajor == true)
        #expect(category.isMinor == false)
    }

    @Test("isMinorは親がある場合にtrueを返す")
    internal func checkIsMinor() {
        let parent = SwiftDataCategory(name: "食費")
        let child = SwiftDataCategory(name: "外食", parent: parent)

        #expect(child.isMajor == false)
        #expect(child.isMinor == true)
    }

    @Test("fullNameは大項目の場合、名前のみを返す")
    internal func fullNameForMajorSwiftDataCategory() {
        let category = SwiftDataCategory(name: "食費")
        #expect(category.fullName == "食費")
    }

    @Test("fullNameは中項目の場合、親/子の形式を返す")
    internal func fullNameForMinorSwiftDataCategory() {
        let parent = SwiftDataCategory(name: "食費")
        let child = SwiftDataCategory(name: "外食", parent: parent)

        #expect(child.fullName == "食費 / 外食")
    }

    // MARK: - Convenience メソッドテスト

    @Test("childメソッドで名前から子カテゴリを取得できる")
    internal func getChildCategoryByName() {
        let parent = SwiftDataCategory(name: "食費")
        let child1 = SwiftDataCategory(name: "外食")
        let child2 = SwiftDataCategory(name: "自炊")

        parent.addChild(child1)
        parent.addChild(child2)

        let found = parent.child(named: "外食")
        #expect(found === child1)
    }

    @Test("childメソッドで存在しない名前を指定するとnilを返す")
    internal func getChildCategoryByNonexistentName() {
        let parent = SwiftDataCategory(name: "食費")
        let child = SwiftDataCategory(name: "外食")

        parent.addChild(child)

        let found = parent.child(named: "旅行")
        #expect(found == nil)
    }

    // MARK: - 年次特別枠テスト

    @Test("年次特別枠の使用可否を設定できる")
    internal func setAllowsAnnualBudget() {
        let category = SwiftDataCategory(name: "特別", allowsAnnualBudget: true)
        #expect(category.allowsAnnualBudget == true)
    }

    // MARK: - 表示順序テスト

    @Test("表示順序を設定できる")
    internal func setDisplayOrder() {
        let category1 = SwiftDataCategory(name: "食費", displayOrder: 1)
        let category2 = SwiftDataCategory(name: "日用品", displayOrder: 2)

        #expect(category1.displayOrder == 1)
        #expect(category2.displayOrder == 2)
    }

    // MARK: - 日時テスト

    @Test("作成日時と更新日時が設定される")
    internal func setCreatedAndUpdatedDates() {
        let before = Date()
        let category = SwiftDataCategory(name: "食費")
        let after = Date()

        #expect(category.createdAt >= before)
        #expect(category.createdAt <= after)
        #expect(category.updatedAt >= before)
        #expect(category.updatedAt <= after)
        #expect(category.createdAt == category.updatedAt)
    }
}
