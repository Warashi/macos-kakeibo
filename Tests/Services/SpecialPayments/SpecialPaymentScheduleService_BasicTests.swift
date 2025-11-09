import Foundation
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentScheduleService Basic Tests")
internal struct SpecialPaymentScheduleService_BasicTests {
    private let service: SpecialPaymentScheduleService = SpecialPaymentScheduleService()

    @Test("年を跨ぐスケジュールを生成できる")
    internal func scheduleTargets_spansMultipleYears() throws {
        let firstDate = try #require(Date.from(year: 2024, month: 11, day: 30))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 10))

        let definition = SpecialPaymentDefinition(
            name: "家電買い替え",
            amount: 180_000,
            recurrenceIntervalMonths: 6,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 18,
        )

        #expect(targets.count == 3)
        let scheduledMonths = targets.map { ($0.scheduledDate.year, $0.scheduledDate.month) }
        let expectedMonths: [(Int, Int)] = [
            (2025, 5),
            (2025, 11),
            (2026, 5),
        ]
        #expect(scheduledMonths.count == expectedMonths.count)
        for (index, expected) in expectedMonths.enumerated() {
            let actual = scheduledMonths[index]
            #expect(actual.0 == expected.0 && actual.1 == expected.1)
        }
    }

    @Test("参照日より後の初回予定日を保持する")
    internal func scheduleTargets_keepsFutureSeedWhenReferenceEarlier() throws {
        let firstDate = try #require(Date.from(year: 2026, month: 3, day: 15))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "車検",
            amount: 120_000,
            recurrenceIntervalMonths: 24,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 12,
        )

        let firstTarget = try #require(targets.first)
        #expect(firstTarget.scheduledDate.year == 2026)
        #expect(firstTarget.scheduledDate.month == 3)
    }

    @Test("リードタイム内でステータスがsavingに切り替わる")
    internal func defaultStatus_switchesWithinLeadTime() throws {
        let scheduledDate = try #require(Date.from(year: 2025, month: 4, day: 20))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let savingStatus = service.defaultStatus(
            for: scheduledDate,
            referenceDate: referenceDate,
            leadTimeMonths: 3,
        )
        #expect(savingStatus == .saving)

        let plannedStatus = service.defaultStatus(
            for: scheduledDate,
            referenceDate: referenceDate,
            leadTimeMonths: 0,
        )
        #expect(plannedStatus == .planned)
    }

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

        let definition = SpecialPaymentDefinition(
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

        let definition = SpecialPaymentDefinition(
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

    @Test("極端に古い開始日でもmaxIterationsで保護される")
    internal func scheduleTargets_protectedByMaxIterations() throws {
        // 50年前から開始（maxIterations 600 × 1ヶ月 = 50年で到達できる範囲）
        let veryOldDate = try #require(Date.from(year: 1975, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 1,
            firstOccurrenceDate: veryOldDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 12,
        )

        // maxIterations (600) に到達しても結果が返されることを確認
        #expect(!targets.isEmpty)
        // 最初のターゲットは参照日の月初以降であることを確認
        let firstTarget = try #require(targets.first)
        #expect(firstTarget.scheduledDate >= referenceDate.startOfMonth)
    }

    @Test("極端に大きな周期でもmaxIterationsで保護される")
    internal func scheduleTargets_largeIntervalProtectedByMaxIterations() throws {
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 1))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        // 10年周期
        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 120,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 6000,
        )

        // maxIterations (600) を超えない範囲で生成される
        // 10年周期 × 600回 = 6000年分 = 600件のはず
        #expect(targets.count <= 600)
        #expect(!targets.isEmpty)
    }

    @Test("月末の日付計算が正しく処理される（1月31日→2月28日）")
    internal func scheduleTargets_handlesMonthEndDates() throws {
        // 1月31日開始、1ヶ月周期
        let firstDate = try #require(Date.from(year: 2025, month: 1, day: 31))
        let referenceDate = try #require(Date.from(year: 2025, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
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

        #expect(targets.count >= 2)
        let first = targets[0]
        let second = targets[1]

        // 1月31日
        #expect(first.scheduledDate.month == 1)
        #expect(first.scheduledDate.day == 31)

        // 2月28日（2025年は閏年ではない）
        #expect(second.scheduledDate.month == 2)
        #expect(second.scheduledDate.day == 28)
    }

    @Test("閏年の2月29日が正しく処理される")
    internal func scheduleTargets_handlesLeapYearDates() throws {
        // 2024年2月29日開始（閏年）、12ヶ月周期
        let firstDate = try #require(Date.from(year: 2024, month: 2, day: 29))
        let referenceDate = try #require(Date.from(year: 2024, month: 1, day: 1))

        let definition = SpecialPaymentDefinition(
            name: "テスト支払い",
            amount: 10000,
            recurrenceIntervalMonths: 12,
            firstOccurrenceDate: firstDate,
        )

        let targets = service.scheduleTargets(
            for: definition,
            seedDate: definition.firstOccurrenceDate,
            referenceDate: referenceDate,
            horizonMonths: 24,
        )

        #expect(targets.count >= 2)
        let first = targets[0]
        let second = targets[1]

        // 2024年2月29日
        #expect(first.scheduledDate.year == 2024)
        #expect(first.scheduledDate.month == 2)
        #expect(first.scheduledDate.day == 29)

        // 2025年2月28日（2025年は閏年ではない）
        #expect(second.scheduledDate.year == 2025)
        #expect(second.scheduledDate.month == 2)
        #expect(second.scheduledDate.day == 28)
    }
}
