import Foundation

internal protocol CustomHolidayRepository: Sendable {
    /// 指定された年の祝日を取得
    /// - Parameter year: 取得対象の年
    /// - Returns: 祝日の日付セット
    func holidays(for year: Int) async throws -> Set<Date>
}
