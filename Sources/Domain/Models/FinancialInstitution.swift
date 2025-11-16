import Foundation

/// ドメイン層で扱う金融機関モデル
internal struct FinancialInstitution: Sendable {
    internal let id: UUID
    internal let name: String
    internal let displayOrder: Int
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    internal init(from entity: FinancialInstitutionEntity) {
        self.id = entity.id
        self.name = entity.name
        self.displayOrder = entity.displayOrder
        self.createdAt = entity.createdAt
        self.updatedAt = entity.updatedAt
    }
}
