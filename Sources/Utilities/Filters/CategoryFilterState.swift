import Foundation

/// 大項目・中項目フィルタの共通状態。
internal struct CategoryFilterState: Equatable {
    internal struct Selection: Equatable, Sendable {
        internal let majorCategoryId: UUID?
        internal let minorCategoryId: UUID?

        internal func matches(category: Category?) -> Bool {
            guard let category else { return majorCategoryId == nil && minorCategoryId == nil }
            if let minorCategoryId {
                return category.id == minorCategoryId
            }

            guard let majorCategoryId else { return true }
            if category.isMajor {
                return category.id == majorCategoryId
            }
            return category.parent?.id == majorCategoryId
        }

        internal func matches(majorCategory: Category?, minorCategory: Category?) -> Bool {
            if let minorCategoryId {
                return minorCategory?.id == minorCategoryId
            }

            guard let majorCategoryId else { return true }
            if let majorCategory, majorCategory.id == majorCategoryId {
                return true
            }
            return minorCategory?.parent?.id == majorCategoryId
        }
    }

    internal private(set) var availableCategories: [Category]
    private var grouping: CategoryHierarchyGrouping
    private var categoriesVersion: UInt64

    internal var selectedMajorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMajorCategoryId else { return }
            ensureMinorConsistency()
        }
    }

    internal var selectedMinorCategoryId: UUID? {
        didSet {
            guard oldValue != selectedMinorCategoryId else { return }
            ensureMinorBelongsToMajor()
        }
    }

    internal init(categories: [Category] = []) {
        self.availableCategories = categories
        self.grouping = CategoryHierarchyGrouping(categories: categories)
        self.categoriesVersion = 0
        self.selectedMajorCategoryId = nil
        self.selectedMinorCategoryId = nil
    }

    internal mutating func updateCategories(_ categories: [Category]) {
        availableCategories = categories
        grouping = CategoryHierarchyGrouping(categories: categories)
        categoriesVersion &+= 1
        ensureMinorConsistency()
    }

    internal mutating func reset() {
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
    }

    internal var selection: Selection {
        Selection(
            majorCategoryId: selectedMajorCategoryId,
            minorCategoryId: selectedMinorCategoryId
        )
    }

    internal var majorCategories: [Category] {
        sortCategories(grouping.majorCategories)
    }

    internal func minorCategories(for majorId: UUID?) -> [Category] {
        sortCategories(grouping.minorCategories(forMajorId: majorId))
    }

    private mutating func ensureMinorConsistency() {
        guard let majorId = selectedMajorCategoryId else {
            selectedMinorCategoryId = nil
            return
        }
        guard let minorId = selectedMinorCategoryId else { return }
        let minors = grouping.minorCategories(forMajorId: majorId)
        if !minors.contains(where: { $0.id == minorId }) {
            selectedMinorCategoryId = nil
        }
    }

    private mutating func ensureMinorBelongsToMajor() {
        guard let minorId = selectedMinorCategoryId else { return }
        guard let majorId = selectedMajorCategoryId else {
            // 大項目未選択で中項目のみ指定された場合は無効化
            selectedMinorCategoryId = nil
            return
        }

        let minors = grouping.minorCategories(forMajorId: majorId)
        if !minors.contains(where: { $0.id == minorId }) {
            selectedMinorCategoryId = nil
        }
    }

    private func sortCategories(_ categories: [Category]) -> [Category] {
        categories.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.name < rhs.name
            }
            return lhs.displayOrder < rhs.displayOrder
        }
    }

    internal static func == (lhs: CategoryFilterState, rhs: CategoryFilterState) -> Bool {
        lhs.selectedMajorCategoryId == rhs.selectedMajorCategoryId
            && lhs.selectedMinorCategoryId == rhs.selectedMinorCategoryId
            && lhs.categoriesVersion == rhs.categoriesVersion
    }
}
