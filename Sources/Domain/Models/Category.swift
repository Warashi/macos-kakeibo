import Foundation

/// ドメイン層で扱うカテゴリモデル
internal struct Category: Sendable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let allowsAnnualBudget: Bool
    internal let parentId: UUID?
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int = 0,
        allowsAnnualBudget: Bool = false,
        parentId: UUID? = nil,
        parent: Category? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.allowsAnnualBudget = allowsAnnualBudget
        self.parentId = parent?.id ?? parentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal var isMajor: Bool {
        parentId == nil
    }

    internal var isMinor: Bool {
        parentId != nil
    }
}
