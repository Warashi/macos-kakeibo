import Foundation

/// 祝日データを提供するプロトコル
internal protocol HolidayProvider {
    /// 指定された年の祝日を取得
    /// - Parameter year: 対象年
    /// - Returns: 祝日のSet（日付は時刻を00:00:00に正規化）
    func holidays(for year: Int) -> Set<Date>

    /// 指定された期間の祝日を取得
    /// - Parameters:
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    /// - Returns: 期間内の祝日のSet
    func holidays(from startDate: Date, to endDate: Date) -> Set<Date>
}

/// HolidayProviderの期間指定祝日取得メソッドのデフォルト実装
public extension HolidayProvider {
    /// 指定された期間の祝日を取得（デフォルト実装）
    /// - Parameters:
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    /// - Returns: 期間内の祝日のSet
    func holidays(from startDate: Date, to endDate: Date) -> Set<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        var allHolidays = Set<Date>()
        for year in startYear ... endYear {
            allHolidays.formUnion(holidays(for: year))
        }

        // 期間内の祝日のみをフィルタ
        return allHolidays.filter { holiday in
            holiday >= calendar.startOfDay(for: startDate) &&
                holiday <= calendar.startOfDay(for: endDate)
        }
    }
}
