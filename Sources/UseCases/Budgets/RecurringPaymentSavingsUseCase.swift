import Foundation

internal protocol RecurringPaymentSavingsUseCaseProtocol {
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
    ) -> [RecurringPaymentSavingsCalculation]

    func entries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [RecurringPaymentSavingsEntry]
}

internal final class DefaultRecurringPaymentSavingsUseCase: RecurringPaymentSavingsUseCaseProtocol {
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
            definitions: snapshot.recurringPaymentDefinitions,
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
            definitions: snapshot.recurringPaymentDefinitions,
            year: year,
            month: month,
        )
    }

    internal func calculations(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [RecurringPaymentSavingsCalculation] {
        calculator.calculateRecurringPaymentSavings(
            RecurringPaymentSavingsCalculationInput(
                definitions: snapshot.recurringPaymentDefinitions,
                balances: snapshot.recurringPaymentBalances,
                occurrences: snapshot.recurringPaymentOccurrences,
                year: year,
                month: month,
            ),
        )
    }

    internal func entries(
        snapshot: BudgetSnapshot,
        year: Int,
        month: Int,
    ) -> [RecurringPaymentSavingsEntry] {
        calculations(snapshot: snapshot, year: year, month: month).map { calc in
            RecurringPaymentSavingsEntry(
                calculation: calc,
                progress: progress(for: calc, definitions: snapshot.recurringPaymentDefinitions),
                hasAlert: calc.balance < 0,
            )
        }
    }
}

private extension DefaultRecurringPaymentSavingsUseCase {
    func progress(
        for calculation: RecurringPaymentSavingsCalculation,
        definitions: [RecurringPaymentDefinition],
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
