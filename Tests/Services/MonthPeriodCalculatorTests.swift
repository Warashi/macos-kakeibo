import Foundation
import Testing

@testable import Kakeibo

@Suite("MonthPeriodCalculator Tests")
internal struct MonthPeriodCalculatorTests {
    @Test("デフォルト設定 - 開始日1日、調整なし")
    internal func defaultSettings() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 1,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 2)
        #expect(endComponents.day == 1)
    }

    @Test("カスタム開始日 - 25日開始")
    internal func customStartDay() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 25,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 25)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 2)
        #expect(endComponents.day == 25)
    }

    @Test("休日調整 - 前営業日")
    internal func previousBusinessDayAdjustment() {
        // 2025年1月1日は元日（休日）
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }

        let businessDayService = BusinessDayService(holidays: holidays)
        let calculator = MonthPeriodCalculator(
            monthStartDay: 1,
            monthStartDayAdjustment: .previous,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 2024年12月31日（前営業日）に調整される
        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 12)
        #expect(startComponents.day == 31)
    }

    @Test("休日調整 - 次営業日")
    internal func nextBusinessDayAdjustment() {
        // 2025年1月1日は元日（休日）
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }

        let businessDayService = BusinessDayService(holidays: holidays)
        let calculator = MonthPeriodCalculator(
            monthStartDay: 1,
            monthStartDayAdjustment: .next,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, _) = period else { return }

        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)

        // 2025年1月2日（次営業日）に調整される
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 2)
    }

    @Test("複数月にわたる計算 - 連続性の確認")
    internal func consecutiveMonths() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 15,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService,
        )

        let period1 = calculator.calculatePeriod(for: 2025, month: 1)
        let period2 = calculator.calculatePeriod(for: 2025, month: 2)

        #expect(period1 != nil)
        #expect(period2 != nil)

        guard let (_, end1) = period1, let (start2, _) = period2 else { return }

        // 1月の終了日と2月の開始日が一致することを確認
        #expect(end1 == start2)
    }

    @Test("年をまたぐ計算 - 12月から1月")
    internal func yearBoundary() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 25,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2024, month: 12)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)

        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 12)
        #expect(startComponents.day == 25)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 1)
        #expect(endComponents.day == 25)
    }

    @Test("期間の長さ - 約1ヶ月であることを確認")
    internal func periodLength() {
        let businessDayService = BusinessDayService()
        let calculator = MonthPeriodCalculator(
            monthStartDay: 1,
            monthStartDayAdjustment: .none,
            businessDayService: businessDayService,
        )

        let period = calculator.calculatePeriod(for: 2025, month: 1)
        #expect(period != nil)

        guard let (start, end) = period else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)

        // 1月は31日あるので、31日間の期間になるはず
        #expect(components.day == 31)
    }
}
