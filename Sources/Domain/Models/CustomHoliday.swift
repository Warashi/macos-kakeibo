import Foundation

/// ドメイン層で扱うユーザー定義祝日
internal struct CustomHoliday: Identifiable, Sendable {
    internal let id: UUID
    internal let date: Date
    internal let name: String
    internal let isRecurring: Bool
    internal let createdAt: Date
    internal let updatedAt: Date
}
