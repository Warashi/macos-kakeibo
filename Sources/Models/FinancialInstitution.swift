import Foundation
import SwiftData

@Model
final class FinancialInstitution {
    var id: UUID
    var name: String

    // 表示順序
    var displayOrder: Int

    // 作成・更新日時
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}
