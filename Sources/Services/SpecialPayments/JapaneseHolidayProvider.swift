import Foundation

/// 日本の祝日を提供するプロバイダー
internal struct JapaneseHolidayProvider: HolidayProvider {
    private let calendar: Calendar

    internal init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    internal func holidays(for year: Int) -> Set<Date> {
        var holidays = Set<Date>()

        // 固定祝日
        holidays.formUnion(fixedHolidays(for: year))

        // 移動祝日
        holidays.formUnion(movableHolidays(for: year))

        // 振替休日
        holidays.formUnion(substituteHolidays(for: year, baseHolidays: holidays))

        return holidays
    }

    // MARK: - 固定祝日

    private func fixedHolidays(for year: Int) -> Set<Date> {
        var holidays = Set<Date>()

        let fixedDates: [(month: Int, day: Int)] = [
            (1, 1), // 元日
            (2, 11), // 建国記念の日
            (4, 29), // 昭和の日
            (5, 3), // 憲法記念日
            (5, 4), // みどりの日
            (5, 5), // こどもの日
            (8, 11), // 山の日
            (11, 3), // 文化の日
            (11, 23), // 勤労感謝の日
        ]

        // 2020年以降は天皇誕生日が2/23
        if year >= 2020 {
            holidays.insert(makeDate(year: year, month: 2, day: 23))
        }
        // 1989-2018年は天皇誕生日が12/23
        else if year >= 1989 {
            holidays.insert(makeDate(year: year, month: 12, day: 23))
        }

        for (month, day) in fixedDates {
            holidays.insert(makeDate(year: year, month: month, day: day))
        }

        return holidays
    }

    // MARK: - 移動祝日

    private func movableHolidays(for year: Int) -> Set<Date> {
        var holidays = Set<Date>()

        if let comingOfAgeDay = comingOfAgeDay(for: year) {
            holidays.insert(comingOfAgeDay)
        }
        if let marineDay = marineDay(for: year) {
            holidays.insert(marineDay)
        }
        if let respectForAgedDay = respectForAgedDay(for: year) {
            holidays.insert(respectForAgedDay)
        }
        if let sportsDay = sportsDay(for: year) {
            holidays.insert(sportsDay)
        }

        return holidays
    }

    // 成人の日（1月第2月曜日） - 2000年以降
    private func comingOfAgeDay(for year: Int) -> Date? {
        if year >= 2000 {
            nthWeekday(year: year, month: 1, weekday: 2, nth: 2)
        } else {
            makeDate(year: year, month: 1, day: 15)
        }
    }

    // 海の日（7月第3月曜日） - 2003年以降
    private func marineDay(for year: Int) -> Date? {
        if year >= 2003 {
            return nthWeekday(year: year, month: 7, weekday: 2, nth: 3)
        } else if year >= 1996 {
            return makeDate(year: year, month: 7, day: 20)
        }
        return nil
    }

    // 敬老の日（9月第3月曜日） - 2003年以降
    private func respectForAgedDay(for year: Int) -> Date? {
        if year >= 2003 {
            nthWeekday(year: year, month: 9, weekday: 2, nth: 3)
        } else {
            makeDate(year: year, month: 9, day: 15)
        }
    }

    // スポーツの日（10月第2月曜日） - 2000年以降
    private func sportsDay(for year: Int) -> Date? {
        if year >= 2000 {
            return nthWeekday(year: year, month: 10, weekday: 2, nth: 2)
        } else if year >= 1966 {
            return makeDate(year: year, month: 10, day: 10)
        }
        return nil
    }

    // MARK: - 振替休日

    private func substituteHolidays(for year: Int, baseHolidays: Set<Date>) -> Set<Date> {
        var substitutes = Set<Date>()

        // 振替休日制度は1973年以降
        guard year >= 1973 else { return substitutes }

        for holiday in baseHolidays {
            // 日曜日の祝日の場合、次の非祝日まで振替
            let weekday = calendar.component(.weekday, from: holiday)
            if weekday == 1 { // 日曜日
                var current = holiday
                var daysToAdd = 1

                // 次の非祝日を見つける（最大7日間検索）
                while daysToAdd <= 7 {
                    guard let nextDay = calendar.date(byAdding: .day, value: daysToAdd, to: holiday) else {
                        break
                    }

                    // 既存の祝日でなければ振替休日として追加
                    if !baseHolidays.contains(nextDay), !substitutes.contains(nextDay) {
                        substitutes.insert(nextDay)
                        break
                    }

                    daysToAdd += 1
                }
            }
        }

        return substitutes
    }

    // MARK: - ヘルパーメソッド

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date()
    }

    private func nthWeekday(year: Int, month: Int, weekday: Int, nth: Int) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return nil
        }

        var current = firstDay
        var count = 0

        for dayOffset in 0 ..< 31 {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else {
                return nil
            }

            // 月が変わったら終了
            if calendar.component(.month, from: checkDate) != month {
                return nil
            }

            // 指定された曜日かチェック
            if calendar.component(.weekday, from: checkDate) == weekday {
                count += 1
                if count == nth {
                    return checkDate
                }
            }
        }

        return nil
    }
}
