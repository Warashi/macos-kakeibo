import Foundation
import Testing

@testable import Kakeibo

@Suite
internal struct CategoryHierarchyGroupingTests {
    @Test("カテゴリを大項目と中項目で分ける")
    internal func splitsCategoriesByHierarchy() {
        let food = Category(name: "食費")
        let eatingOut = Category(name: "外食", parent: food)
        let transport = Category(name: "交通")
        let taxi = Category(name: "タクシー", parent: transport)

        let categories = [food, eatingOut, transport, taxi]
        let grouping = CategoryHierarchyGrouping(categories: categories)

        #expect(grouping.majorCategories.map(\.id) == [food.id, transport.id])
        #expect(grouping.minorCategories.map(\.id) == [eatingOut.id, taxi.id])
        #expect(grouping.minorCategories(forMajorId: food.id).map(\.id) == [eatingOut.id])
        #expect(grouping.minorCategories(forMajorId: transport.id).map(\.id) == [taxi.id])
        #expect(grouping.minorCategories(forMajorId: nil).isEmpty)
    }
}
