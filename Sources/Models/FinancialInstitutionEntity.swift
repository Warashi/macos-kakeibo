import Foundation
import SwiftData

@Model
internal final class FinancialInstitutionEntity {
    internal var id: UUID
    internal var name: String

    /// 表示順序
    internal var displayOrder: Int

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int = 0,
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
