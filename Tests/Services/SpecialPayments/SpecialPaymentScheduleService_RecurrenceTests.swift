import Foundation
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentScheduleService Recurrence Tests")
internal struct SpecialPaymentScheduleService_RecurrenceTests {
    private let service: SpecialPaymentScheduleService = SpecialPaymentScheduleService()

    // MARK: - 周期バリエーションテスト

    @Test("3ヶ月周期のスケジュール生成")
    internal func scheduleTargets_quarterly() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 15))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "四半期支払い",
            amount: 30000,
            recurrenceIntervalMonths: 3,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 12,
        )

        #expect(targets.count == 4)
        #expect(targets[0].scheduledDate.month == 1)
        #expect(targets[1].scheduledDate.month == 4)
        #expect(targets[2].scheduledDate.month == 7)
        #expect(targets[3].scheduledDate.month == 10)
    }

    @Test("18ヶ月周期のスケジュール生成")
    internal func scheduleTargets_eighteenMonths() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "1.5年周期支払い",
            amount: 100_000,
            recurrenceIntervalMonths: 18,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 36,
        )

        #expect(targets.count == 3)
        #expect(targets[0].scheduledDate.year == 2025)
        #expect(targets[0].scheduledDate.month == 1)
        #expect(targets[1].scheduledDate.year == 2026)
        #expect(targets[1].scheduledDate.month == 7)
        if targets.count >= 3 {
            #expect(targets[2].scheduledDate.year == 2028)
            #expect(targets[2].scheduledDate.month == 1)
        }
    }

    @Test("3年周期のスケジュール生成")
    internal func scheduleTargets_threeYears() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 6, day: 15))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "3年周期支払い",
            amount: 500_000,
            recurrenceIntervalMonths: 36,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 72,
        )

        #expect(targets.count == 2)
        #expect(targets[0].scheduledDate.year == 2025)
        #expect(targets[1].scheduledDate.year == 2028)
    }

    // MARK: - 開始日バリエーションテスト

    @Test("月初開始のスケジュール生成")
    internal func scheduleTargets_startsOnFirstDayOfMonth() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "月初支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 3,
        )

        #expect(targets.count == 4)
        #expect(targets.allSatisfy { $0.scheduledDate.day == 1 })
    }

    @Test("月末開始のスケジュール生成（31日）")
    internal func scheduleTargets_startsOnLastDayOfMonth() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "月末支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 4,
        )

        #expect(targets.count == 4)
        // 1月31日 → 2月28日 → 3月28日 → 4月28日（月末は維持されない）
        #expect(targets[0].scheduledDate.day == 31)
        #expect(targets[1].scheduledDate.day == 28)
        #expect(targets[2].scheduledDate.day == 28)
        #expect(targets[3].scheduledDate.day == 28)
    }

    // MARK: - 長期間テスト

    @Test("5年間のスケジュール生成（年次支払い）")
    internal func scheduleTargets_fiveYearsAnnual() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 4, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "年次支払い",
            amount: 120_000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 60,
        )

        #expect(targets.count == 5)
        for index in 0 ..< 5 {
            #expect(targets[index].scheduledDate.year == 2025 + index)
            #expect(targets[index].scheduledDate.month == 4)
            #expect(targets[index].scheduledDate.day == 1)
        }
    }

    @Test("10年間のスケジュール生成（隔年支払い）")
    internal func scheduleTargets_tenYearsBiannual() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "隔年支払い",
            amount: 200_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 120,
        )

        // 120ヶ月（10年）先まで、24ヶ月（2年）周期 → 6件
        #expect(targets.count == 6)
        for index in 0 ..< 6 {
            #expect(targets[index].scheduledDate.year == 2025 + (index * 2))
        }
    }

    // MARK: - horizonMonthsエッジケーステスト

    @Test("horizonMonths = 0の場合")
    internal func scheduleTargets_horizonMonthsZero() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 3, day: 15))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 0,
        )

        // horizonMonths = 0でも少なくとも1件は生成される
        #expect(!targets.isEmpty)
        #expect(targets[0].scheduledDate.month == 3)
    }

    @Test("未来の開始日でのスケジュール生成")
    internal func scheduleTargets_futureStartDate() throws {
        let futureDate = try #require(Date.from(year: 2026, month: 6, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "未来の支払い",
            amount: 50000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: futureDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 24,
        )

        #expect(!targets.isEmpty)
        let firstTarget = try #require(targets.first)
        #expect(firstTarget.scheduledDate.year == 2026)
        #expect(firstTarget.scheduledDate.month == 6)
    }
}
