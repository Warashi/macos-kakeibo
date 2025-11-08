import Foundation
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentScheduleService Tests")
internal struct SpecialPaymentScheduleServiceTests {
    private let service = SpecialPaymentScheduleService()

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
}
