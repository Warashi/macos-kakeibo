import Foundation

/// カテゴリ一覧を大項目・中項目で分割した結果
internal struct CategoryHierarchyGrouping {
    internal let majorCategories: [Category]
    internal let minorCategories: [Category]

    internal init(categories: [Category]) {
        var majors: [Category] = []
        var minors: [Category] = []

        for category in categories {
            if category.isMajor {
                majors.append(category)
            } else {
                minors.append(category)
            }
        }

        self.majorCategories = majors
        self.minorCategories = minors
    }
}
