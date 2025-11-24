import Foundation
import Testing

@testable import Kakeibo

@Suite("Date.customMonthRange Continuity Tests")
struct DateCustomMonthRangeContinuityTests {
    private let businessDayService: BusinessDayService

    init() {
        // 2025年1月1日（水）を元日として設定
        // 2025年2月25日（火）を休日として設定（テスト用）
        let calendar = Calendar(identifier: .gregorian)
        var holidays = Set<Date>()
        if let newYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) {
            holidays.insert(calendar.startOfDay(for: newYear))
        }
        if let feb25 = calendar.date(from: DateComponents(year: 2025, month: 2, day: 25)) {
            holidays.insert(calendar.startOfDay(for: feb25))
        }
        businessDayService = BusinessDayService(holidays: holidays)
    }

    @Test("連続する月の期間に隙間がないことを確認 - 調整なし")
    func testContinuityWithoutAdjustment() {
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService
        )
        let feb = Date.customMonthRange(
            year: 2025,
            month: 2,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService
        )

        #expect(jan != nil)
        #expect(feb != nil)

        guard let jan, let feb else { return }

        // 1月の終了日 = 2月の開始日であることを確認
        #expect(jan.end == feb.start)

        let calendar = Calendar.current
        let janEnd = calendar.dateComponents([.year, .month, .day], from: jan.end)
        let febStart = calendar.dateComponents([.year, .month, .day], from: feb.start)

        #expect(janEnd.year == 2025)
        #expect(janEnd.month == 2)
        #expect(janEnd.day == 25)

        #expect(febStart.year == 2025)
        #expect(febStart.month == 2)
        #expect(febStart.day == 25)
    }

    @Test("連続する月の期間に隙間がないことを確認 - 前営業日調整")
    func testContinuityWithPreviousBusinessDayAdjustment() {
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 1, // 元日（休日）→ 12/31に調整される
            adjustment: .previous,
            businessDayService: businessDayService
        )
        let feb = Date.customMonthRange(
            year: 2025,
            month: 2,
            startDay: 1,
            adjustment: .previous,
            businessDayService: businessDayService
        )

        #expect(jan != nil)
        #expect(feb != nil)

        guard let jan, let feb else { return }

        // 1月の終了日 = 2月の開始日であることを確認（調整前の日付）
        #expect(jan.end == feb.start)

        let calendar = Calendar.current
        let janStart = calendar.dateComponents([.year, .month, .day], from: jan.start)
        let janEnd = calendar.dateComponents([.year, .month, .day], from: jan.end)
        let febStart = calendar.dateComponents([.year, .month, .day], from: feb.start)

        // 1月の開始日は2024/12/31（前営業日に調整）
        #expect(janStart.year == 2024)
        #expect(janStart.month == 12)
        #expect(janStart.day == 31)

        // 1月の終了日は2025/2/1（調整なし）
        #expect(janEnd.year == 2025)
        #expect(janEnd.month == 2)
        #expect(janEnd.day == 1)

        // 2月の開始日は2025/2/1（調整なし、終了日と一致）
        #expect(febStart.year == 2025)
        #expect(febStart.month == 2)
        #expect(febStart.day == 1)
    }

    @Test("休日の25日開始で連続性を確認 - 前営業日調整")
    func testContinuityWith25thStartOnHoliday() {
        // 2月25日は休日として設定されている
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .previous,
            businessDayService: businessDayService
        )
        let feb = Date.customMonthRange(
            year: 2025,
            month: 2,
            startDay: 25, // 休日→前営業日に調整される
            adjustment: .previous,
            businessDayService: businessDayService
        )
        let mar = Date.customMonthRange(
            year: 2025,
            month: 3,
            startDay: 25,
            adjustment: .previous,
            businessDayService: businessDayService
        )

        #expect(jan != nil)
        #expect(feb != nil)
        #expect(mar != nil)

        guard let jan, let feb, let mar else { return }

        // 連続性を確認
        #expect(jan.end == feb.start)
        #expect(feb.end == mar.start)

        let calendar = Calendar.current

        // 1月: 1/25（平日） 〜 2/25（終了日は調整なし）
        let janStart = calendar.dateComponents([.year, .month, .day], from: jan.start)
        let janEnd = calendar.dateComponents([.year, .month, .day], from: jan.end)
        #expect(janStart.day == 25) // 1/25は平日なので調整されない
        #expect(janEnd.month == 2)
        #expect(janEnd.day == 25) // 終了日は調整されない

        // 2月: 2/25（調整なし） 〜 3/25（終了日は調整なし）
        let febStart = calendar.dateComponents([.year, .month, .day], from: feb.start)
        let febEnd = calendar.dateComponents([.year, .month, .day], from: feb.end)
        #expect(febStart.month == 2)
        #expect(febStart.day == 25) // 開始日は調整されない（終了日として使われるため）
        #expect(febEnd.month == 3)
        #expect(febEnd.day == 25) // 終了日は調整されない
    }

    @Test("重複がないことを確認 - 取引が二重にカウントされない")
    func testNoOverlap() {
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .previous,
            businessDayService: businessDayService
        )
        let feb = Date.customMonthRange(
            year: 2025,
            month: 2,
            startDay: 25,
            adjustment: .previous,
            businessDayService: businessDayService
        )

        #expect(jan != nil)
        #expect(feb != nil)

        guard let jan, let feb else { return }

        // 1月の期間に含まれる日付
        // date >= jan.start && date < jan.end

        // 2月の期間に含まれる日付
        // date >= feb.start && date < feb.end

        // jan.end == feb.start なので、境界の日付は2月に含まれる
        #expect(jan.end == feb.start)

        // 境界日が1月に含まれないことを確認（date < jan.end）
        let boundaryDate = jan.end
        let isInJan = boundaryDate >= jan.start && boundaryDate < jan.end
        #expect(isInJan == false)

        // 境界日が2月に含まれることを確認（date >= feb.start）
        let isInFeb = boundaryDate >= feb.start && boundaryDate < feb.end
        #expect(isInFeb == true)
    }

    @Test("期間の長さが約1ヶ月であることを確認 - 25日開始")
    func testPeriodLengthWith25thStart() {
        // 1月25日〜2月25日の期間
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService
        )

        #expect(jan != nil)
        guard let jan else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: jan.start, to: jan.end)

        // 1月25日〜2月25日は31日間
        #expect(components.day == 31)
    }

    @Test("年をまたぐ場合の連続性 - 12月から1月")
    func testContinuityAcrossYearBoundary() {
        let dec = Date.customMonthRange(
            year: 2024,
            month: 12,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService
        )
        let jan = Date.customMonthRange(
            year: 2025,
            month: 1,
            startDay: 25,
            adjustment: .none,
            businessDayService: businessDayService
        )

        #expect(dec != nil)
        #expect(jan != nil)

        guard let dec, let jan else { return }

        // 12月の終了日 = 1月の開始日
        #expect(dec.end == jan.start)

        let calendar = Calendar.current
        let decEnd = calendar.dateComponents([.year, .month, .day], from: dec.end)
        let janStart = calendar.dateComponents([.year, .month, .day], from: jan.start)

        #expect(decEnd.year == 2025)
        #expect(decEnd.month == 1)
        #expect(decEnd.day == 25)

        #expect(janStart.year == 2025)
        #expect(janStart.month == 1)
        #expect(janStart.day == 25)
    }
}
