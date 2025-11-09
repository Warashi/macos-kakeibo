import Foundation
import SwiftUI

// MARK: - Budget Editor Form State

internal struct BudgetEditorFormState {
    internal var amountText: String = ""
    internal var selectedMajorCategoryId: UUID?
    internal var selectedMinorCategoryId: UUID?
    internal var startDate: Date = Date()
    internal var endDate: Date = Date()

    internal var selectedCategoryId: UUID? {
        selectedMinorCategoryId ?? selectedMajorCategoryId
    }

    internal mutating func load(from budget: Budget) {
        amountText = budget.amount.plainString
        startDate = budget.targetDate
        endDate = budget.endDate
        if let category = budget.category {
            if category.isMajor {
                selectedMajorCategoryId = category.id
                selectedMinorCategoryId = nil
            } else {
                selectedMajorCategoryId = category.parent?.id
                selectedMinorCategoryId = category.id
            }
        } else {
            selectedMajorCategoryId = nil
            selectedMinorCategoryId = nil
        }
    }

    internal mutating func reset(defaultYear: Int, defaultMonth: Int) {
        amountText = ""
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
        if let defaultDate = Date.from(year: defaultYear, month: defaultMonth) {
            startDate = defaultDate
            endDate = defaultDate
        } else {
            startDate = Date()
            endDate = Date()
        }
    }

    private var normalizedAmountText: String {
        amountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

    internal var isValid: Bool {
        guard let amount = decimalAmount, amount > 0 else { return false }
        return normalizedStartDate <= normalizedEndDate
    }

    internal var normalizedStartDate: Date {
        startDate.startOfMonth
    }

    internal var normalizedEndDate: Date {
        endDate.startOfMonth
    }

    internal mutating func updateMajorSelection(to newValue: UUID?) {
        guard selectedMajorCategoryId != newValue else { return }
        selectedMajorCategoryId = newValue
        selectedMinorCategoryId = nil
    }
}

// MARK: - Annual Budget Form State

internal enum AnnualAllocationFinalizationError: Error, Equatable {
    case noAllocations
    case manualDoesNotMatchTotal
}

internal struct AnnualBudgetFormState {
    internal var totalAmountText: String = ""
    internal var policy: AnnualBudgetPolicy = .automatic
    internal var allocationRows: [AnnualBudgetAllocationRowState] = []

    internal mutating func load(from config: AnnualBudgetConfig) {
        totalAmountText = config.totalAmount.plainString
        policy = config.policy
        allocationRows = config.allocations.map { allocation in
            var row = AnnualBudgetAllocationRowState(
                id: allocation.id,
                amountText: allocation.amount.plainString,
                selectedPolicyOverride: allocation.policyOverride,
            )
            if allocation.category.isMajor {
                row.selectedMajorCategoryId = allocation.category.id
                row.selectedMinorCategoryId = nil
            } else {
                row.selectedMajorCategoryId = allocation.category.parent?.id
                row.selectedMinorCategoryId = allocation.category.id
            }
            return row
        }
        ensureInitialRow()
    }

    internal mutating func reset() {
        totalAmountText = ""
        policy = .automatic
        allocationRows = []
    }

    private var normalizedAmountText: String {
        totalAmountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

    internal var isValid: Bool {
        guard let amount = decimalAmount else { return false }
        return amount > 0
    }

    internal mutating func ensureInitialRow() {
        if allocationRows.isEmpty {
            allocationRows.append(.init())
        }
    }

    internal mutating func addAllocationRow() {
        allocationRows.append(.init())
    }

    internal mutating func removeAllocationRow(id: UUID) {
        if allocationRows.count <= 1 { return }
        allocationRows.removeAll { $0.id == id }
        ensureInitialRow()
    }

    internal func makeAllocationDrafts() -> [AnnualAllocationDraft]? {
        var drafts: [AnnualAllocationDraft] = []
        for row in allocationRows {
            guard let categoryId = row.selectedCategoryId,
                  let draft = makeDraft(for: row, categoryId: categoryId) else {
                return nil
            }
            drafts.append(draft)
        }
        return drafts
    }

    private func makeDraft(
        for row: AnnualBudgetAllocationRowState,
        categoryId: UUID,
    ) -> AnnualAllocationDraft? {
        guard let value = row.decimalAmount, value > 0 else {
            return nil
        }

        return AnnualAllocationDraft(
            categoryId: categoryId,
            amount: value,
            policyOverride: row.selectedPolicyOverride,
        )
    }

    internal func finalizeAllocations(totalAmount: Decimal)
    -> Result<[AnnualAllocationDraft], AnnualAllocationFinalizationError> {
        guard let drafts = makeAllocationDrafts(), !drafts.isEmpty else {
            return .failure(.noAllocations)
        }

        let totalAllocation = drafts.reduce(Decimal.zero) { partialResult, draft in
            partialResult.safeAdd(draft.amount)
        }

        guard totalAllocation == totalAmount else {
            return .failure(.manualDoesNotMatchTotal)
        }

        return .success(drafts)
    }
}

// MARK: - Annual Budget Allocation Row State

internal struct AnnualBudgetAllocationRowState: Identifiable {
    internal let id: UUID
    internal var selectedMajorCategoryId: UUID?
    internal var selectedMinorCategoryId: UUID?
    internal var amountText: String
    internal var selectedPolicyOverride: AnnualBudgetPolicy?

    internal init(
        id: UUID = UUID(),
        selectedMajorCategoryId: UUID? = nil,
        selectedMinorCategoryId: UUID? = nil,
        amountText: String = "",
        selectedPolicyOverride: AnnualBudgetPolicy? = nil,
    ) {
        self.id = id
        self.selectedMajorCategoryId = selectedMajorCategoryId
        self.selectedMinorCategoryId = selectedMinorCategoryId
        self.amountText = amountText
        self.selectedPolicyOverride = selectedPolicyOverride
    }

    internal var selectedCategoryId: UUID? {
        selectedMinorCategoryId ?? selectedMajorCategoryId
    }

    private var normalizedAmountText: String {
        amountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

}

// MARK: - Budget Editor Mode

internal enum BudgetEditorMode {
    case create
    case edit(Budget)

    internal var title: String {
        switch self {
        case .create:
            "予算を追加"
        case .edit:
            "予算を編集"
        }
    }
}

// MARK: - Special Payment Form State

internal struct SpecialPaymentFormState {
    internal var nameText: String = ""
    internal var notesText: String = ""
    internal var amountText: String = ""
    internal var recurrenceYears: Int = 0
    internal var recurrenceMonths: Int = 1
    internal var firstOccurrenceDate: Date = Date()
    internal var leadTimeMonths: Int = 0
    internal var selectedMajorCategoryId: UUID?
    internal var selectedMinorCategoryId: UUID?
    internal var savingStrategy: SpecialPaymentSavingStrategy = .evenlyDistributed
    internal var customMonthlySavingAmountText: String = ""
    internal var dateAdjustmentPolicy: DateAdjustmentPolicy = .none
    internal var recurrenceDayPattern: DayOfMonthPattern?

    internal var selectedCategoryId: UUID? {
        selectedMinorCategoryId ?? selectedMajorCategoryId
    }

    internal mutating func load(from definition: SpecialPaymentDefinition) {
        nameText = definition.name
        notesText = definition.notes
        amountText = definition.amount.plainString
        recurrenceYears = definition.recurrenceIntervalMonths / 12
        recurrenceMonths = definition.recurrenceIntervalMonths % 12
        firstOccurrenceDate = definition.firstOccurrenceDate
        leadTimeMonths = definition.leadTimeMonths
        if let category = definition.category {
            if category.isMajor {
                selectedMajorCategoryId = category.id
                selectedMinorCategoryId = nil
            } else {
                selectedMajorCategoryId = category.parent?.id
                selectedMinorCategoryId = category.id
            }
        } else {
            selectedMajorCategoryId = nil
            selectedMinorCategoryId = nil
        }
        savingStrategy = definition.savingStrategy
        customMonthlySavingAmountText = definition.customMonthlySavingAmount?.plainString ?? ""
        dateAdjustmentPolicy = definition.dateAdjustmentPolicy
        recurrenceDayPattern = definition.recurrenceDayPattern
    }

    internal mutating func reset() {
        nameText = ""
        notesText = ""
        amountText = ""
        recurrenceYears = 0
        recurrenceMonths = 1
        firstOccurrenceDate = Date()
        leadTimeMonths = 0
        selectedMajorCategoryId = nil
        selectedMinorCategoryId = nil
        savingStrategy = .evenlyDistributed
        customMonthlySavingAmountText = ""
        dateAdjustmentPolicy = .none
        recurrenceDayPattern = nil
    }

    private var normalizedAmountText: String {
        amountText.replacingOccurrences(of: ",", with: "")
    }

    internal var decimalAmount: Decimal? {
        Decimal(string: normalizedAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedAmountText)
    }

    private var normalizedCustomAmountText: String {
        customMonthlySavingAmountText.replacingOccurrences(of: ",", with: "")
    }

    internal var customMonthlySavingAmount: Decimal? {
        guard !normalizedCustomAmountText.isEmpty else { return nil }
        return Decimal(string: normalizedCustomAmountText, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalizedCustomAmountText)
    }

    internal var recurrenceIntervalMonths: Int {
        recurrenceYears * 12 + recurrenceMonths
    }

    internal var monthlySavingAmountPreview: Decimal {
        guard let amount = decimalAmount else { return 0 }
        switch savingStrategy {
        case .disabled:
            return 0
        case .evenlyDistributed:
            guard recurrenceIntervalMonths > 0 else { return 0 }
            return amount.safeDivide(Decimal(recurrenceIntervalMonths))
        case .customMonthly:
            return customMonthlySavingAmount ?? 0
        }
    }

    internal var isValid: Bool {
        guard !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let amount = decimalAmount, amount > 0 else { return false }
        guard recurrenceIntervalMonths > 0 else { return false }
        guard leadTimeMonths >= 0 else { return false }

        if savingStrategy == .customMonthly {
            guard let customAmount = customMonthlySavingAmount, customAmount > 0 else { return false }
        }

        return true
    }
}

// MARK: - Special Payment Editor Mode

internal enum SpecialPaymentEditorMode {
    case create
    case edit(SpecialPaymentDefinition)

    internal var title: String {
        switch self {
        case .create:
            "特別支払いを追加"
        case .edit:
            "特別支払いを編集"
        }
    }
}
