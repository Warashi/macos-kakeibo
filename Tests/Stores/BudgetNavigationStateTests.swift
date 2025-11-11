import Foundation
import Testing

@testable import Kakeibo

@Suite("BudgetNavigationState")
internal struct BudgetNavigationStateTests {
    @Test("前月移動で年をまたぐ")
    internal func previousMonth_wrapsYear() throws {
        let referenceDate = Date.from(year: 2025, month: 4, day: 1) ?? Date()
        var state = BudgetNavigationState(
            year: 2025,
            month: 1,
            currentDateProvider: { referenceDate }
        )

        let changed = state.moveToPreviousMonth()

        #expect(changed)
        #expect(state.year == 2024)
        #expect(state.month == 12)
    }

    @Test("moveToPresentはmodeに応じて現在値を適用")
    internal func moveToPresent_respectsMode() throws {
        let referenceDate = Date.from(year: 2025, month: 4, day: 1) ?? Date()

        var monthlyState = BudgetNavigationState(
            year: 2000,
            month: 1,
            currentDateProvider: { referenceDate }
        )
        let monthlyChanged = monthlyState.moveToPresent(displayMode: .monthly)
        #expect(monthlyChanged)
        #expect(monthlyState.year == 2025)
        #expect(monthlyState.month == 4)

        var annualState = BudgetNavigationState(
            year: 1990,
            month: 8,
            currentDateProvider: { referenceDate }
        )
        let annualChanged = annualState.moveToPresent(displayMode: .annual)
        #expect(annualChanged)
        #expect(annualState.year == 2025)
        #expect(annualState.month == 8)

        var specialState = BudgetNavigationState(
            year: 2010,
            month: 3,
            currentDateProvider: { referenceDate }
        )
        let specialChanged = specialState.moveToPresent(displayMode: .specialPaymentsList)
        #expect(specialChanged == false)
        #expect(specialState.year == 2010)
        #expect(specialState.month == 3)
    }
}
