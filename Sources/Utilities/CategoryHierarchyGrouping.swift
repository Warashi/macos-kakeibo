import Foundation

/// カテゴリ一覧を大項目・中項目で分割した結果
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
                if let parentId = category.parent?.id {
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

/// CategoryDTO版のカテゴリ階層グルーピング
internal struct CategoryDTOHierarchyGrouping {
    internal let majorCategories: [CategoryDTO]
    internal let minorCategories: [CategoryDTO]
    internal let minorCategoriesByParent: [UUID: [CategoryDTO]]

    internal init(categories: [CategoryDTO]) {
        var majors: [CategoryDTO] = []
        var minors: [CategoryDTO] = []
        var minorsByParent: [UUID: [CategoryDTO]] = [:]

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

    internal func minorCategories(forMajorId id: UUID?) -> [CategoryDTO] {
        guard let id else { return [] }
        return minorCategoriesByParent[id] ?? []
    }
}
