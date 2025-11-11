import Foundation

/// カテゴリのDTO（Sendable）
internal struct CategoryDTO: Sendable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let allowsAnnualBudget: Bool
    internal let parentId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        name: String,
        displayOrder: Int,
        allowsAnnualBudget: Bool,
        parentId: UUID?,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.allowsAnnualBudget = allowsAnnualBudget
        self.parentId = parentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.displayOrder = category.displayOrder
        self.allowsAnnualBudget = category.allowsAnnualBudget
        self.parentId = category.parent?.id
        self.createdAt = category.createdAt
        self.updatedAt = category.updatedAt
    }

    internal var isMajor: Bool {
        parentId == nil
    }

    internal var isMinor: Bool {
        parentId != nil
    }
}
