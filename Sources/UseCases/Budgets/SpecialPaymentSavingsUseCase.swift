import Foundation

internal protocol SpecialPaymentSavingsUseCaseProtocol {
    func monthlySavingsTotal(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> Decimal

    func categorySavings(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [UUID: Decimal]

    func calculations(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [SpecialPaymentSavingsCalculation]

    func entries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [SpecialPaymentSavingsEntry]
}

internal final class DefaultSpecialPaymentSavingsUseCase: SpecialPaymentSavingsUseCaseProtocol {
    private let calculator: BudgetCalculator

    internal init(calculator: BudgetCalculator = BudgetCalculator()) {
        self.calculator = calculator
    }

    internal func monthlySavingsTotal(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> Decimal {
        calculator.calculateMonthlySavingsAllocation(
            definitions: snapshot.specialPaymentDefinitions,
            year: year,
            month: month,
        )
    }

    internal func categorySavings(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [UUID: Decimal] {
        calculator.calculateCategorySavingsAllocation(
            definitions: snapshot.specialPaymentDefinitions,
            year: year,
            month: month,
        )
    }

    internal func calculations(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [SpecialPaymentSavingsCalculation] {
        calculator.calculateSpecialPaymentSavings(
            definitions: snapshot.specialPaymentDefinitions,
            balances: snapshot.specialPaymentBalances,
            year: year,
            month: month,
        )
    }

    internal func entries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [SpecialPaymentSavingsEntry] {
        calculations(snapshot: snapshot, year: year, month: month).map { calc in
            SpecialPaymentSavingsEntry(
                calculation: calc,
                progress: progress(for: calc, definitions: snapshot.specialPaymentDefinitions),
                hasAlert: calc.balance < 0,
            )
        }
    }
}

private extension DefaultSpecialPaymentSavingsUseCase {
    func progress(
        for calculation: SpecialPaymentSavingsCalculation,
        definitions: [SpecialPaymentDefinition],
    ) -> Double {
        guard let definition = definitions.first(where: { $0.id == calculation.definitionId }) else {
            return 0
        }

        guard definition.amount > 0 else { return 0 }
        let balance = NSDecimalNumber(decimal: calculation.balance).doubleValue
        let target = NSDecimalNumber(decimal: definition.amount).doubleValue
        guard target > 0 else { return 0 }
        return min(1.0, balance / target)
    }
}
