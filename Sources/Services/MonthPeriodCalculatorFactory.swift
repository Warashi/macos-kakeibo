import Foundation

/// MonthPeriodCalculatorのファクトリー
internal enum MonthPeriodCalculatorFactory {
    /// UserDefaultsから設定を読み取ってMonthPeriodCalculatorを作成
    /// - Parameter userDefaults: UserDefaultsインスタンス（デフォルトは.standard）
    /// - Returns: 設定値で初期化されたMonthPeriodCalculator
    internal static func make(userDefaults: UserDefaults = .standard) -> MonthPeriodCalculator {
        let monthStartDay = userDefaults.object(forKey: "settings.monthStartDay") as? Int ?? 1
        let adjustmentRawValue = userDefaults.string(forKey: "settings.monthStartDayAdjustment") ?? "none"
        let adjustment = BusinessDayAdjustment(rawValue: adjustmentRawValue) ?? .none

        let holidayProvider = JapaneseHolidayProvider()
        let businessDayService = BusinessDayService(holidayProvider: holidayProvider)

        return MonthPeriodCalculator(
            monthStartDay: monthStartDay,
            monthStartDayAdjustment: adjustment,
            businessDayService: businessDayService,
        )
    }
}
