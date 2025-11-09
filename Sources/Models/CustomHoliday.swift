import Foundation
import SwiftData

/// ユーザー定義の祝日
@Model
internal final class CustomHoliday {
    internal var id: UUID

    /// 祝日の日付（時刻は00:00:00に正規化）
    internal var date: Date

    /// 祝日の名前
    internal var name: String

    /// 毎年繰り返すかどうか
    /// trueの場合、年に関係なく月日が一致すれば祝日として扱う
    internal var isRecurring: Bool

    /// 作成・更新日時
    internal var createdAt: Date
    internal var updatedAt: Date

    internal init(
        id: UUID = UUID(),
        date: Date,
        name: String,
        isRecurring: Bool = false,
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.isRecurring = isRecurring

        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    /// 指定された日付がこの祝日と一致するか判定
    /// - Parameter checkDate: チェックする日付
    /// - Returns: 一致する場合はtrue
    internal func matches(_ checkDate: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let holidayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let checkComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)

        if isRecurring {
            // 繰り返しの場合は月日のみで比較
            return holidayComponents.month == checkComponents.month &&
                holidayComponents.day == checkComponents.day
        } else {
            // 繰り返しでない場合は完全一致
            return holidayComponents.year == checkComponents.year &&
                holidayComponents.month == checkComponents.month &&
                holidayComponents.day == checkComponents.day
        }
    }
}
