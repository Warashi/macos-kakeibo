import Foundation

// MARK: - 年月操作

/// 年月操作の拡張
public extension Date {
    /// 年を取得
    var year: Int {
        Calendar.current.component(.year, from: self)
    }

    /// 月を取得
    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    /// 日を取得
    var day: Int {
        Calendar.current.component(.day, from: self)
    }

    /// 月の開始日（その月の1日の00:00:00）
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// 月の終了日（その月の最終日の23:59:59）
    var endOfMonth: Date {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth),
              let endOfMonth = Calendar.current.date(byAdding: .second, value: -1, to: nextMonth) else {
            return self
        }
        return endOfMonth
    }

    /// 指定した年月日のDateを生成
    /// - Parameters:
    ///   - year: 年
    ///   - month: 月
    ///   - day: 日（省略時は1日）
    /// - Returns: 指定した年月日のDate
    static func from(year: Int, month: Int, day: Int = 1) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }

    /// 前月の日付を取得
    var previousMonth: Date? {
        Calendar.current.date(byAdding: .month, value: -1, to: self)
    }

    /// 次月の日付を取得
    var nextMonth: Date? {
        Calendar.current.date(byAdding: .month, value: 1, to: self)
    }

    /// 指定した月数を加算した日付を取得
    /// - Parameter months: 加算する月数（負の値で減算）
    /// - Returns: 計算後の日付
    func adding(months: Int) -> Date? {
        Calendar.current.date(byAdding: .month, value: months, to: self)
    }

    /// 年月の文字列表現（例: "2025-11"）
    var yearMonthString: String {
        String(format: "%04d-%02d", year, month)
    }

    /// 年月が一致するか判定
    /// - Parameter other: 比較対象の日付
    /// - Returns: 年月が一致する場合true
    func isSameMonth(as other: Date) -> Bool {
        year == other.year && month == other.month
    }

    /// 年が一致するか判定
    /// - Parameter other: 比較対象の日付
    /// - Returns: 年が一致する場合true
    func isSameYear(as other: Date) -> Bool {
        year == other.year
    }
}

// MARK: - フォーマット

/// 日付フォーマットの拡張
public extension Date {
    /// 年月フォーマット（例: "2025年11月"）
    var yearMonthFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// 短い日付フォーマット（例: "2025/11/08"）
    var shortDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// 長い日付フォーマット（例: "2025年11月8日"）
    var longDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
}

// MARK: - 日付範囲

/// 日付範囲操作の拡張
public extension Date {
    /// 2つの日付の間の月数を計算
    /// - Parameter other: 比較対象の日付
    /// - Returns: 月数の差（正の値は未来、負の値は過去）
    func monthsBetween(_ other: Date) -> Int {
        let components = Calendar.current.dateComponents([.month], from: self, to: other)
        return components.month ?? 0
    }

    /// 指定した日付範囲に含まれるか判定
    /// - Parameters:
    ///   - start: 開始日
    ///   - end: 終了日
    /// - Returns: 範囲内の場合true
    func isInRange(from start: Date, to end: Date) -> Bool {
        self >= start && self <= end
    }
}

// MARK: - カスタム月範囲

/// カスタム月範囲の計算
internal extension Date {
    /// カスタム月範囲の結果
    struct CustomMonthRange: Sendable {
        internal let start: Date
        internal let end: Date
    }

    // swiftlint:disable function_parameter_count
    /// カスタム月範囲を計算
    /// - Parameters:
    ///   - year: 年
    ///   - month: 月
    ///   - startDay: 開始日（1-28）
    ///   - adjustment: 休日調整方法
    ///   - businessDayService: 営業日判定サービス
    /// - Returns: 月範囲（開始日と終了日）
    static func customMonthRange(
        year: Int,
        month: Int,
        startDay: Int,
        adjustment: BusinessDayAdjustment,
        businessDayService: BusinessDayService,
    ) -> CustomMonthRange? {
        // 開始日は1-28の範囲に制限
        let clampedStartDay = max(1, min(28, startDay))

        // 指定月の開始日を計算
        guard var monthStart = Date.from(year: year, month: month, day: clampedStartDay) else {
            return nil
        }

        // 休日調整を適用
        monthStart = applyBusinessDayAdjustment(
            to: monthStart,
            adjustment: adjustment,
            businessDayService: businessDayService,
        )

        // 次の月の開始日を計算（調整なし）
        // 元の年月から計算することで、調整で月がずれた場合でも正しい次月を計算できる
        let (nextYear, nextMonth) = if month == 12 {
            (year + 1, 1)
        } else {
            (year, month + 1)
        }

        guard let nextMonthStart = Date.from(year: nextYear, month: nextMonth, day: clampedStartDay) else {
            return nil
        }

        return CustomMonthRange(start: monthStart, end: nextMonthStart)
    }

    /// 休日調整を適用
    private static func applyBusinessDayAdjustment(
        to date: Date,
        adjustment: BusinessDayAdjustment,
        businessDayService: BusinessDayService,
    ) -> Date {
        switch adjustment {
        case .none:
            date
        case .previous:
            if businessDayService.isBusinessDay(date) {
                date
            } else {
                businessDayService.previousBusinessDay(from: date) ?? date
            }
        case .next:
            if businessDayService.isBusinessDay(date) {
                date
            } else {
                businessDayService.nextBusinessDay(from: date) ?? date
            }
        }
    }
    // swiftlint:enable function_parameter_count
}
