import Foundation
import HolidayJp

/// 日本の祝日を提供するプロバイダー（holiday-jp ライブラリ使用）
internal struct JapaneseHolidayProvider: HolidayProvider {
    private let calendar: Calendar

    internal init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    internal func holidays(for year: Int) -> Set<Date> {
        // ymd文字列（"YYYY-MM-DD"）をパースするためのフォーマッター
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        // 対象年の1月1日から12月31日までの期間を作成
        guard let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endDate = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else {
            return []
        }

        // holiday-jp ライブラリで祝日を取得
        let holidays = HolidayJp.between(startDate, and: endDate)

        // Date型のSetに変換
        var holidayDates = Set<Date>()
        for holiday in holidays {
            // ymd文字列（"YYYY-MM-DD"）をDateに変換
            if let date = dateFormatter.date(from: holiday.ymd) {
                let normalizedDate = calendar.startOfDay(for: date)
                holidayDates.insert(normalizedDate)
            }
        }

        return holidayDates
    }
}
