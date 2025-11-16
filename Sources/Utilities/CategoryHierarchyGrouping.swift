import Foundation

/// SwiftDataのカテゴリを階層構造に分割した結果
internal struct CategoryEntityHierarchyGrouping {
    internal let majorCategories: [CategoryEntity]
    internal let minorCategories: [CategoryEntity]
    internal let minorCategoriesByParent: [UUID: [CategoryEntity]]

    internal init(categories: [CategoryEntity]) {
        var majors: [CategoryEntity] = []
        var minors: [CategoryEntity] = []
        var minorsByParent: [UUID: [CategoryEntity]] = [:]

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

    internal func minorCategories(forMajorId id: UUID?) -> [CategoryEntity] {
        guard let id else { return [] }
        return minorCategoriesByParent[id] ?? []
    }
}

/// ドメインモデル版カテゴリ階層グルーピング
internal struct CategoryHierarchyGrouping {
    internal let majorCategories: [Category]
    internal let minorCategories: [Category]
    internal let minorCategoriesByParent: [UUID: [Category]]

    internal init(categories: [Category]) {
        var majors: [Category] = []
        var minors: [Category] = []
        var minorsByParent: [UUID: [Category]] = [:]

        for category in categories {
            if category.isMajor {
                majors.append(category)
            } else {
                minors.append(category)
                if let parentId = category.parentId {
                    minorsByParent[parentId, default: []].append(category)
                }
            }
        }

        self.majorCategories = majors
        self.minorCategories = minors
        self.minorCategoriesByParent = minorsByParent
    }

    internal func minorCategories(forMajorId id: UUID?) -> [Category] {
        guard let id else { return [] }
        return minorCategoriesByParent[id] ?? []
    }
}
