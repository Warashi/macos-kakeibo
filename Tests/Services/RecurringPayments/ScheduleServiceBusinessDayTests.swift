import Foundation
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentScheduleService BusinessDay Tests")
internal struct ScheduleServiceBusinessDayTests {
    private let service: RecurringPaymentScheduleService = RecurringPaymentScheduleService()

    @Test("土曜日を前営業日に調整できる")
    internal func adjustDateForBusinessDay_moveSaturdayToPreviousBusinessDay() throws {
        // 2025年1月4日は土曜日
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let adjusted = service.adjustDateForBusinessDay(saturday, policy: .moveToPreviousBusinessDay)

        // 金曜日の2025年1月3日になることを期待
        let expected = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(adjusted == expected)
    }

    @Test("日曜日を前営業日に調整できる")
    internal func adjustDateForBusinessDay_moveSundayToPreviousBusinessDay() throws {
        // 2025年1月5日は日曜日
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let adjusted = service.adjustDateForBusinessDay(sunday, policy: .moveToPreviousBusinessDay)

        // 金曜日の2025年1月3日になることを期待
        let expected = try #require(Date.from(year: 2025, month: 1, day: 3))
        #expect(adjusted == expected)
    }

    @Test("土曜日を次営業日に調整できる")
    internal func adjustDateForBusinessDay_moveSaturdayToNextBusinessDay() throws {
        // 2025年1月4日は土曜日
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let adjusted = service.adjustDateForBusinessDay(saturday, policy: .moveToNextBusinessDay)

        // 月曜日の2025年1月6日になることを期待
        let expected = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(adjusted == expected)
    }

    @Test("日曜日を次営業日に調整できる")
    internal func adjustDateForBusinessDay_moveSundayToNextBusinessDay() throws {
        // 2025年1月5日は日曜日
        let sunday = try #require(Date.from(year: 2025, month: 1, day: 5))
        let adjusted = service.adjustDateForBusinessDay(sunday, policy: .moveToNextBusinessDay)

        // 月曜日の2025年1月6日になることを期待
        let expected = try #require(Date.from(year: 2025, month: 1, day: 6))
        #expect(adjusted == expected)
    }

    @Test("調整なしポリシーでは日付が変わらない")
    internal func adjustDateForBusinessDay_nonePolicy() throws {
        // 2025年1月4日は土曜日
        let saturday = try #require(Date.from(year: 2025, month: 1, day: 4))
        let adjusted = service.adjustDateForBusinessDay(saturday, policy: .none)

        // 変更されないことを期待
        #expect(adjusted == saturday)
    }

    @Test("平日は調整されない")
    internal func adjustDateForBusinessDay_weekdayNotAdjusted() throws {
        // 2025年1月6日は月曜日
        let monday = try #require(Date.from(year: 2025, month: 1, day: 6))
        let adjustedPrevious = service.adjustDateForBusinessDay(monday, policy: .moveToPreviousBusinessDay)
        let adjustedNext = service.adjustDateForBusinessDay(monday, policy: .moveToNextBusinessDay)

        #expect(adjustedPrevious == monday)
        #expect(adjustedNext == monday)
    }

    @Test("スケジュール生成で日付調整が適用される_前営業日")
    internal func scheduleTargets_appliesDateAdjustment_moveToPrevious() throws {
        // 2025年2月1日は土曜日
        let firstDate = try #require(Date.from(year: 2025, month: 2, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            dateAdjustmentPolicy: .moveToPreviousBusinessDay,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 1,
        )

        let firstTarget = try #require(targets.first)
        // 2025年1月31日（金曜日）に調整されることを期待
        let expected = try #require(Date.from(year: 2025, month: 1, day: 31))
        #expect(firstTarget.scheduledDate == expected)
    }

    @Test("スケジュール生成で日付調整が適用される_次営業日")
    internal func scheduleTargets_appliesDateAdjustment_moveToNext() throws {
        // 2025年2月1日は土曜日
        let firstDate = try #require(Date.from(year: 2025, month: 2, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            dateAdjustmentPolicy: .moveToNextBusinessDay,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 1,
        )

        let firstTarget = try #require(targets.first)
        // 2025年2月3日（月曜日）に調整されることを期待
        let expected = try #require(Date.from(year: 2025, month: 2, day: 3))
        #expect(firstTarget.scheduledDate == expected)
    }
}
