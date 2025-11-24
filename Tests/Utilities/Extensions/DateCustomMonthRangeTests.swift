import Foundation
import Testing

@testable import Kakeibo

@Suite("Date.customMonthRange Tests")
internal struct DateCustomMonthRangeTests {
    private let businessDayService: BusinessDayService

    internal init() {
        // テスト用の祝日を設定（2025年1月1日は元日）
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }
        businessDayService = BusinessDayService(holidays: holidays)
    }

    @Test("基本的な月範囲計算 - 開始日1日")
    internal func basicMonthRange() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 2)
        #expect(endComponents.day == 1)
    }

    @Test("カスタム開始日 - 25日開始")
    internal func customStartDay25() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 25)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 2)
        #expect(endComponents.day == 25)
    }

    @Test("月をまたぐ範囲 - 12月25日開始")
    internal func monthWrapping() {
        let range = Date.customMonthRange(
            year: 2024,
            month: 12,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: range.end)

        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 12)
        #expect(startComponents.day == 25)

        #expect(endComponents.year == 2025)
        #expect(endComponents.month == 1)
        #expect(endComponents.day == 25)
    }

    @Test("境界値 - 最小値1日")
    internal func boundaryMinimum() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        #expect(startComponents.day == 1)
    }

    @Test("境界値 - 最大値28日")
    internal func boundaryMaximum() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 28,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        #expect(startComponents.day == 28)
    }

    @Test("境界値外 - 0日はクランプされて1日になる")
    internal func boundaryClampingZero() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 0,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        #expect(startComponents.day == 1)
    }

    @Test("境界値外 - 29日はクランプされて28日になる")
    internal func boundaryClampingOverflow() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 29,
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        #expect(startComponents.day == 28)
    }

    @Test("休日調整なし - 開始日が元日（休日）でも調整されない")
    internal func noAdjustmentOnHoliday() {
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1, // 2025年1月1日は元日
            adjustment: .none,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        // 調整なしなので、休日でも1日のまま
        #expect(startComponents.day == 1)
    }

    @Test("休日調整 - 前営業日に調整")
    internal func previousBusinessDayAdjustment() {
        // 2025年1月1日は元日（休日）なので、前営業日に調整されるはず
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1,
            adjustment: .previous,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        // 2024年12月31日（火曜日）に調整される
        #expect(startComponents.year == 2024)
        #expect(startComponents.month == 12)
        #expect(startComponents.day == 31)
    }

    @Test("休日調整 - 次営業日に調整")
    internal func nextBusinessDayAdjustment() {
        // 2025年1月1日は元日（休日）なので、次営業日に調整されるはず
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1,
            adjustment: .next,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        // 2025年1月2日（木曜日）に調整される
        #expect(startComponents.year == 2025)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 2)
    }

    @Test("平日の場合は調整されない")
    internal func noAdjustmentOnWeekday() {
        // 2025年1月6日は月曜日（営業日）
        let range = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 6,
            adjustment: .previous,
            businessDayService: businessDayService,
        )

        #expect(range != nil)
        guard let range else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day], from: range.start)

        // 営業日なので調整されない
        #expect(startComponents.day == 6)
    }
}
