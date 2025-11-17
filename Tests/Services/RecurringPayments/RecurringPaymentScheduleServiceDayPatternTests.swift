import Foundation
import Testing

@testable import Kakeibo

@Suite("RecurringPaymentScheduleService DayPattern Tests")
internal struct ScheduleServiceDayPatternTests {
    private let service: RecurringPaymentScheduleService = RecurringPaymentScheduleService()

    // MARK: - recurrenceDayPattern Integration Tests

    @Test("月末パターンでのスケジュール生成")
    internal func scheduleTargets_withEndOfMonthPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "月末支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .endOfMonth,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 4,
        )

        #expect(targets.count == 4)
        // 1月31日 → 2月28日 → 3月31日 → 4月30日（月末維持）
        #expect(targets[0].scheduledDate.day == 31)
        #expect(targets[1].scheduledDate.day == 28)
        #expect(targets[2].scheduledDate.day == 31)
        #expect(targets[3].scheduledDate.day == 30)
    }

    @Test("最終営業日パターンでのスケジュール生成")
    internal func scheduleTargets_withLastBusinessDayPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "月末営業日支払い",
            amount: 300_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .lastBusinessDay,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 3)
        // 1月: 31(金)、2月: 28(金)、3月: 31(月)
        #expect(targets[0].scheduledDate.day == 31)
        #expect(targets[1].scheduledDate.day == 28)
        #expect(targets[2].scheduledDate.day == 31)
    }

    @Test("第2水曜日パターンでのスケジュール生成")
    internal func scheduleTargets_withNthWeekdayPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 8))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "第2水曜日支払い",
            amount: 5000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .nthWeekday(week: 2, weekday: .wednesday),
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 3)
        // 1月: 8(水)、2月: 12(水)、3月: 12(水)
        #expect(targets[0].scheduledDate.day == 8)
        #expect(targets[1].scheduledDate.day == 12)
        #expect(targets[2].scheduledDate.day == 12)
    }

    @Test("最終金曜日パターンでのスケジュール生成")
    internal func scheduleTargets_withLastWeekdayPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "最終金曜日支払い",
            amount: 250_000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .lastWeekday(.friday),
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 3)
        // 1月: 31(金)、2月: 28(金)、3月: 28(金)
        #expect(targets[0].scheduledDate.day == 31)
        #expect(targets[1].scheduledDate.day == 28)
        #expect(targets[2].scheduledDate.day == 28)
    }

    @Test("5営業日目パターンでのスケジュール生成")
    internal func scheduleTargets_withNthBusinessDayPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 7))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "5営業日目支払い",
            amount: 15000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .nthBusinessDay(5),
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 3)
        // 1月: 7(火)、2月: 7(金)、3月: 7(金)
        #expect(targets[0].scheduledDate.day == 7)
        #expect(targets[1].scheduledDate.day == 7)
        #expect(targets[2].scheduledDate.day == 7)
    }

    @Test("最終営業日3営業日前パターンでのスケジュール生成")
    internal func scheduleTargets_withLastBusinessDayMinusPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 28))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "最終営業日3営業日前支払い",
            amount: 20000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: .lastBusinessDayMinus(days: 3),
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 3)
        // 1月: 28(火)、2月: 25(火)、3月: 26(水)
        #expect(targets[0].scheduledDate.day == 28)
        #expect(targets[1].scheduledDate.day == 25)
        #expect(targets[2].scheduledDate.day == 26)
    }

    @Test("パターンなし（nil）の場合は標準カレンダー計算")
    internal func scheduleTargets_withoutPattern() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = RecurringPaymentDefinitionEntity(
            name: "標準計算",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
            recurrenceDayPattern: nil,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 4,
        )

        #expect(targets.count == 4)
        // 1月31日 → 2月28日 → 3月28日 → 4月28日（標準のカレンダー計算）
        #expect(targets[0].scheduledDate.day == 31)
        #expect(targets[1].scheduledDate.day == 28)
        #expect(targets[2].scheduledDate.day == 28)
        #expect(targets[3].scheduledDate.day == 28)
    }
}
