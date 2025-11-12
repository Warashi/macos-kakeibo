import Foundation
import Observation
import SwiftData

@Observable
@MainActor
internal final class SpecialPaymentReconciliationStore {
    internal typealias OccurrenceRow = SpecialPaymentReconciliationPresenter.OccurrenceRow
    internal typealias TransactionCandidate = SpecialPaymentReconciliationPresenter.TransactionCandidate
    internal typealias TransactionCandidateScore = SpecialPaymentReconciliationPresenter.TransactionCandidateScore

    // MARK: - Nested Types

    internal enum OccurrenceFilter: String, CaseIterable, Identifiable {
        case needsAttention = "要対応"
        case upcoming = "今後"
        case completed = "完了済み"
        case all = "すべて"

        internal var id: Self { self }

        fileprivate func matches(row: OccurrenceRow) -> Bool {
            switch self {
            case .needsAttention:
                row.needsAttention
            case .upcoming:
                row.isUpcoming
            case .completed:
                row.isCompleted
            case .all:
                true
            }
        }
    }

    // MARK: - Dependencies

    private let repository: SpecialPaymentRepository
    private let transactionRepository: TransactionRepository
    private let occurrencesService: SpecialPaymentOccurrencesService
    private let presenter: SpecialPaymentReconciliationPresenter
    private let currentDateProvider: () -> Date
    private let candidateSearchWindowDays: Int
    private let candidateLimit: Int
    private let horizonMonths: Int

    // MARK: - State

    internal private(set) var isLoading: Bool = false
    internal private(set) var isSaving: Bool = false
    internal private(set) var errorMessage: String?
    internal private(set) var statusMessage: String?

    internal var searchText: String = "" {
        didSet { applyFilters() }
    }

    internal var filter: OccurrenceFilter = .needsAttention {
        didSet { applyFilters() }
    }

    internal private(set) var rows: [OccurrenceRow] = []
    internal private(set) var filteredRows: [OccurrenceRow] = []

    internal var selectedOccurrenceId: UUID? {
        didSet {
            guard selectedOccurrenceId != oldValue else { return }
            updateEditorState()
        }
    }

    internal var actualAmountText: String = ""
    internal var actualDate: Date = Date()
    internal var selectedTransactionId: UUID?
    internal private(set) var candidateTransactions: [TransactionCandidate] = []

    // MARK: - Caches

    private var occurrenceLookup: [UUID: SpecialPaymentOccurrenceDTO] = [:]
    private var definitionsLookup: [UUID: SpecialPaymentDefinitionDTO] = [:]
    private var linkedTransactionLookup: [UUID: UUID] = [:]
    private var transactions: [TransactionDTO] = []

    // MARK: - Initialization

    internal init(
        repository: SpecialPaymentRepository,
        transactionRepository: TransactionRepository,
        occurrencesService: SpecialPaymentOccurrencesService? = nil,
        candidateSearchWindowDays: Int = 60,
        candidateLimit: Int = 12,
        horizonMonths: Int = SpecialPaymentScheduleService.defaultHorizonMonths,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
        self.occurrencesService = occurrencesService ?? DefaultSpecialPaymentOccurrencesService(repository: repository)
        self.presenter = SpecialPaymentReconciliationPresenter()
        self.candidateSearchWindowDays = candidateSearchWindowDays
        self.candidateLimit = candidateLimit
        self.currentDateProvider = currentDateProvider
        self.horizonMonths = horizonMonths
    }

    // MARK: - Accessors

    internal var selectedRow: OccurrenceRow? {
        guard let id = selectedOccurrenceId else { return nil }
        return filteredRows.first(where: { $0.id == id }) ?? rows.first(where: { $0.id == id })
    }
}

// MARK: - Actions

internal extension SpecialPaymentReconciliationStore {
    func refresh() async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            transactions = try await transactionRepository.fetchAllTransactions()

            let definitionDTOs = try await repository.definitions(filter: nil)
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            let referenceDate = currentDateProvider()

            let occurrenceDTOs = try await repository.occurrences(query: nil)

            definitionsLookup = Dictionary(uniqueKeysWithValues: definitionDTOs.map { ($0.id, $0) })

            var categoriesDict: [UUID: String] = [:]
            for def in definitionDTOs {
                if let categoryId = def.categoryId {
                    if categoriesDict[categoryId] == nil {
                        categoriesDict[categoryId] = def.name
                    }
                }
            }

            let transactionsDict = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0.title) })

            let presentation = presenter.makePresentation(
                input: SpecialPaymentReconciliationPresenter.PresentationInput(
                    occurrences: occurrenceDTOs,
                    definitions: definitionsLookup,
                    categories: categoriesDict,
                    transactions: transactionsDict,
                    referenceDate: referenceDate,
                ),
            )

            rows = presentation.rows
            occurrenceLookup = presentation.occurrenceLookup
            linkedTransactionLookup = presentation.linkedTransactionLookup
            applyFilters()

            if let selectedOccurrenceId,
               occurrenceLookup[selectedOccurrenceId] != nil,
               filteredRows.contains(where: { $0.id == selectedOccurrenceId }) {
                updateEditorState()
            } else {
                selectedOccurrenceId = filteredRows.first?.id
            }
        } catch {
            rows = []
            filteredRows = []
            occurrenceLookup = [:]
            linkedTransactionLookup = [:]
            candidateTransactions = []
            errorMessage = "特別支払い情報の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    func selectCandidate(_ candidateId: UUID?) {
        selectedTransactionId = candidateId
        guard let candidateId,
              let candidate = candidateTransactions.first(where: { $0.id == candidateId }) else {
            return
        }

        actualAmountText = candidate.transaction.absoluteAmount.plainString
        actualDate = candidate.transaction.date
    }

    func saveSelectedOccurrence() async {
        guard let occurrenceId = selectedOccurrenceId else {
            errorMessage = "保存対象の特別支払いを選択してください。"
            return
        }

        guard let amount = decimalAmount(from: actualAmountText), amount > 0 else {
            errorMessage = "実績金額を正しく入力してください。"
            return
        }

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        let transaction = selectedTransactionId.flatMap(transactionById)

        do {
            let input = OccurrenceCompletionInput(
                actualDate: actualDate,
                actualAmount: amount,
                transaction: transaction,
            )
            try await repository.markOccurrenceCompleted(
                occurrenceId: occurrenceId,
                input: input,
                horizonMonths: horizonMonths,
            )
            statusMessage = "実績を保存しました。"
            await refresh()
            selectedOccurrenceId = occurrenceId
        } catch let storeError as SpecialPaymentDomainError {
            switch storeError {
            case let .validationFailed(messages):
                errorMessage = messages.joined(separator: "\n")
            default:
                errorMessage = "実績の保存に失敗しました: \(storeError)"
            }
        } catch {
            errorMessage = "実績の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    func unlinkSelectedOccurrence() async {
        guard let occurrenceId = selectedOccurrenceId else {
            errorMessage = "解除対象の特別支払いを選択してください。"
            return
        }

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            try await repository.updateOccurrence(
                occurrenceId: occurrenceId,
                input: OccurrenceUpdateInput(
                    status: .planned,
                    actualDate: nil,
                    actualAmount: nil,
                    transaction: nil,
                ),
                horizonMonths: horizonMonths,
            )
            statusMessage = "取引リンクを解除しました。"
            await refresh()
            selectedOccurrenceId = occurrenceId
        } catch {
            errorMessage = "リンク解除に失敗しました: \(error.localizedDescription)"
        }
    }

    func resetFormToExpectedValues() {
        guard let occurrence = selectedOccurrence else { return }
        actualAmountText = occurrence.expectedAmount.plainString
        actualDate = occurrence.scheduledDate
        selectedTransactionId = occurrence.transactionId
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Private Helpers

private extension SpecialPaymentReconciliationStore {
    var selectedOccurrence: SpecialPaymentOccurrenceDTO? {
        guard let id = selectedOccurrenceId else { return nil }
        return occurrenceLookup[id]
    }

    private func applyFilters() {
        let normalizedSearch = SearchText(searchText)
        filteredRows = rows.filter { row in
            filter.matches(row: row)
                && row.matches(searchText: normalizedSearch)
        }

        let containsSelected = selectedOccurrenceId.flatMap { id in
            filteredRows.contains(where: { $0.id == id })
        } ?? false

        if filteredRows.isEmpty {
            selectedOccurrenceId = nil
        } else if selectedOccurrenceId == nil || !containsSelected {
            selectedOccurrenceId = filteredRows.first?.id
        }
    }

    private func updateEditorState() {
        guard let occurrence = selectedOccurrence else {
            candidateTransactions = []
            actualAmountText = ""
            actualDate = currentDateProvider()
            selectedTransactionId = nil
            return
        }

        actualAmountText = (occurrence.actualAmount ?? occurrence.expectedAmount).plainString
        actualDate = occurrence.actualDate ?? occurrence.scheduledDate
        selectedTransactionId = occurrence.transactionId
        recomputeCandidates(for: occurrence)
    }

    private func recomputeCandidates(for occurrence: SpecialPaymentOccurrenceDTO) {
        guard let definition = definitionsLookup[occurrence.definitionId] else {
            candidateTransactions = []
            return
        }

        let context = SpecialPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: transactions,
            linkedTransactionLookup: linkedTransactionLookup,
            windowDays: candidateSearchWindowDays,
            limit: candidateLimit,
        )
        candidateTransactions = presenter.transactionCandidates(
            for: occurrence,
            definition: definition,
            context: context,
        )
    }

    private func decimalAmount(from text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalized)
    }

    private func transactionById(_ id: UUID) -> TransactionDTO? {
        transactions.first { $0.id == id }
    }
}
