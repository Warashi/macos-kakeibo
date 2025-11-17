import Foundation

internal enum DayOfMonthPattern: Codable, Equatable, Hashable, Sendable {
    // カレンダー日ベース
    case fixed(Int) // 固定日（例：15日）
    case endOfMonth // 月末
    case endOfMonthMinus(days: Int) // 月末前N日（例：月末3日前）
    case nthWeekday(week: Int, weekday: Weekday) // 第N週のM曜日（例：第2水曜日）
    case lastWeekday(Weekday) // 最終M曜日（例：最終金曜日）

    // 営業日ベース
    case firstBusinessDay // 最初の営業日
    case lastBusinessDay // 最終営業日
    case nthBusinessDay(Int) // N番目の営業日（例：5営業日目）
    case lastBusinessDayMinus(days: Int) // 最終営業日前N営業日
}
