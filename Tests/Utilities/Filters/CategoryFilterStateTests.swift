import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct CategoryFilterStateTests {
    private let major = Kakeibo.Category(name: "生活費", displayOrder: 1)
    private let minorFood: Kakeibo.Category
    private let minorDaily: Kakeibo.Category
    private let anotherMajor = Kakeibo.Category(name: "趣味", displayOrder: 2)

    internal init() {
        let food = Kakeibo.Category(name: "食費", parent: major, displayOrder: 1)
        let daily = Kakeibo.Category(name: "日用品", parent: major, displayOrder: 2)
        self.minorFood = food
        self.minorDaily = daily
    }

    @Test("大項目がnilになると中項目もクリアされる")
    internal func clearsMinorWhenMajorBecomesNil() {
        var state = CategoryFilterState(categories: [major, minorFood])
        state.selectedMajorCategoryId = major.id
        state.selectedMinorCategoryId = minorFood.id

        state.selectedMajorCategoryId = nil

        #expect(state.selectedMinorCategoryId == nil)
    }

    @Test("大項目変更で無効な中項目を自動的にクリアする")
    internal func clearsMinorWhenMajorChanges() {
        var state = CategoryFilterState(categories: [major, minorFood, anotherMajor])
        state.selectedMajorCategoryId = major.id
        state.selectedMinorCategoryId = minorFood.id

        state.selectedMajorCategoryId = anotherMajor.id

        #expect(state.selectedMinorCategoryId == nil)
    }

    @Test("カテゴリ一覧更新で存在しない中項目がクリアされる")
    internal func clearsMinorWhenCategoriesUpdated() {
        var state = CategoryFilterState(categories: [major, minorFood])
        state.selectedMajorCategoryId = major.id
        state.selectedMinorCategoryId = minorFood.id

        state.updateCategories([major, minorDaily])

        #expect(state.selectedMinorCategoryId == nil)
    }

    @Test("Selection.matches は大項目→中項目の判定を共通化する")
    internal func selectionMatchesUsesHierarchy() {
        let selectionMinor = CategoryFilterState.Selection(
            majorCategoryId: major.id,
            minorCategoryId: minorFood.id
        )
        #expect(selectionMinor.matches(category: minorFood))
        #expect(!selectionMinor.matches(category: minorDaily))

        let selectionMajor = CategoryFilterState.Selection(
            majorCategoryId: major.id,
            minorCategoryId: nil
        )
        #expect(selectionMajor.matches(category: minorFood))
        #expect(selectionMajor.matches(category: major))
        #expect(!selectionMajor.matches(category: anotherMajor))
    }
}
