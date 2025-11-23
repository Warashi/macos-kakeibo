import Foundation

/// ドメイン層で扱うユーザー定義祝日
internal struct CustomHoliday: Identifiable, Sendable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date

    internal init(
        id: UUID,
        date: Date,
        name: String,
        isRecurring: Bool,
        createdAt: Date,
        updatedAt: Date,
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.isRecurring = isRecurring
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
