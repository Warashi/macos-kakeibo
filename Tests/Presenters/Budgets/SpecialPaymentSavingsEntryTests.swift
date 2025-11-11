import Foundation
import Testing

@testable import Kakeibo

@Suite("SpecialPaymentSavingsEntry")
internal struct SpecialPaymentSavingsEntryTests {
    @Test("progressPercentageは0-100スケールに変換される")
    internal func progressPercentage_convertsScale() throws {
        let calculation = SpecialPaymentSavingsCalculation(
            definitionId: UUID(),
            name: "自動車税",
            monthlySaving: 15000,
            totalSaved: 30000,
            totalPaid: 0,
            balance: 30000,
            nextOccurrence: Date.from(year: 2025, month: 5, day: 31)
        )

        let entry = SpecialPaymentSavingsEntry(
            calculation: calculation,
            progress: 0.75,
            hasAlert: false
        )

        #expect(entry.progressPercentage == 75)
    }

    @Test("計算結果の各値をそのまま公開する")
    internal func exposesCalculationValues() throws {
        let definitionId = UUID()
        let nextDate = Date.from(year: 2025, month: 12, day: 1)
        let calculation = SpecialPaymentSavingsCalculation(
            definitionId: definitionId,
            name: "ボーナス",
            monthlySaving: 50000,
            totalSaved: 200000,
            totalPaid: 0,
            balance: -10000,
            nextOccurrence: nextDate
        )

        let entry = SpecialPaymentSavingsEntry(
            calculation: calculation,
            progress: 0.25,
            hasAlert: true
        )

        #expect(entry.id == definitionId)
        #expect(entry.name == "ボーナス")
        #expect(entry.monthlySaving == 50000)
        #expect(entry.balance == -10000)
        #expect(entry.nextOccurrence == nextDate)
        #expect(entry.hasAlert)
    }
}
