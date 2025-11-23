import Foundation

/// SwiftDataのカテゴリを階層構造に分割した結果
internal struct SwiftDataCategoryHierarchyGrouping {
    internal let majorCategories: [SwiftDataCategory]
    internal let minorCategories: [SwiftDataCategory]
    internal let minorCategoriesByParent: [UUID: [SwiftDataCategory]]

    internal init(categories: [SwiftDataCategory]) {
        var majors: [SwiftDataCategory] = []
        var minors: [SwiftDataCategory] = []
        var minorsByParent: [UUID: [SwiftDataCategory]] = [:]

        for category in categories {
            if category.isMajor {
                majors.append(category)
            } else {
                minors.append(category)
                if let parentId = category.parent?.id {
                    minorsByParent[parentId, default: []].append(category)
                }
            }
        }

        self.majorCategories = majors
        self.minorCategories = minors
        self.minorCategoriesByParent = minorsByParent
    }

    internal func minorCategories(forMajorId id: UUID?) -> [SwiftDataCategory] {
        guard let id else { return [] }
        return minorCategoriesByParent[id] ?? []
    }
}
