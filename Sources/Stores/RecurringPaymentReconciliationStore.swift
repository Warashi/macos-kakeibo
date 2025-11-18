import Foundation
import Observation

@MainActor
@Observable
internal final class RecurringPaymentReconciliationStore {
    internal typealias OccurrenceRow = RecurringPaymentReconciliationPresenter.OccurrenceRow
    internal typealias TransactionCandidate = RecurringPaymentReconciliationPresenter.TransactionCandidate
    internal typealias TransactionCandidateScore = RecurringPaymentReconciliationPresenter.TransactionCandidateScore
    private struct RefreshComputation {
        let transactions: [Transaction]
        let rows: [OccurrenceRow]
        let occurrenceLookup: [UUID: RecurringPaymentOccurrence]
        let definitionsLookup: [UUID: RecurringPaymentDefinition]
        let linkedTransactionLookup: [UUID: UUID]
    }

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

    private let repository: RecurringPaymentRepository
    private let transactionRepository: TransactionRepository
    private let occurrencesService: RecurringPaymentOccurrencesService
    private let presenter: RecurringPaymentReconciliationPresenter
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

    private var occurrenceLookup: [UUID: RecurringPaymentOccurrence] = [:]
    private var definitionsLookup: [UUID: RecurringPaymentDefinition] = [:]
    private var linkedTransactionLookup: [UUID: UUID] = [:]
    private var transactions: [Transaction] = []

    // MARK: - Initialization

    internal init(
        repository: RecurringPaymentRepository,
        transactionRepository: TransactionRepository,
        occurrencesService: RecurringPaymentOccurrencesService,
        candidateSearchWindowDays: Int = 60,
        candidateLimit: Int = 12,
        horizonMonths: Int = RecurringPaymentScheduleService.defaultHorizonMonths,
        currentDateProvider: @escaping () -> Date = { Date() },
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
        self.occurrencesService = occurrencesService
        self.presenter = RecurringPaymentReconciliationPresenter()
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

internal extension RecurringPaymentReconciliationStore {
    func refresh() async {
        errorMessage = nil
        statusMessage = nil
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await computeRefresh()
            applyRefreshResult(result)
        } catch {
            applyRefreshFailure(error)
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
            errorMessage = "保存対象の定期支払いを選択してください。"
            return
        }

        guard let amount = decimalAmount(from: actualAmountText), amount > 0 else {
            errorMessage = "実績金額を正しく入力してください。"
            return
        }

        let transaction = transactionById(selectedTransactionId)

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let input = OccurrenceCompletionInput(
                actualDate: actualDate,
                actualAmount: amount,
                transaction: transaction,
            )
            let service = occurrencesService
            let horizonMonths = horizonMonths
            try await Task.detached(priority: .userInitiated) {
                _ = try await service.markOccurrenceCompleted(
                    occurrenceId: occurrenceId,
                    input: input,
                    horizonMonths: horizonMonths
                )
            }.value
            statusMessage = "実績を保存しました。"
            await refresh()
            selectedOccurrenceId = occurrenceId
        } catch let storeError as RecurringPaymentDomainError {
            let message: String
            switch storeError {
            case let .validationFailed(messages):
                message = messages.joined(separator: "\n")
            default:
                message = "実績の保存に失敗しました: \(storeError)"
            }
            errorMessage = message
        } catch {
            errorMessage = "実績の保存に失敗しました: \(error.localizedDescription)"
        }
    }

    func unlinkSelectedOccurrence() async {
        guard let occurrenceId = selectedOccurrenceId else {
            errorMessage = "解除対象の定期支払いを選択してください。"
            return
        }

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let service = occurrencesService
            let horizonMonths = horizonMonths
            try await Task.detached(priority: .userInitiated) {
                _ = try await service.updateOccurrence(
                    occurrenceId: occurrenceId,
                    input: OccurrenceUpdateInput(
                        status: .planned,
                        actualDate: nil,
                        actualAmount: nil,
                        transaction: nil
                    ),
                    horizonMonths: horizonMonths
                )
            }.value
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

private extension RecurringPaymentReconciliationStore {
    private func computeRefresh() async throws -> RefreshComputation {
        let transactionRepository = self.transactionRepository
        let repository = self.repository
        let presenter = self.presenter
        let referenceDate = currentDateProvider()

        return try await Task.detached(priority: .userInitiated) {
            let transactions = try await transactionRepository.fetchAllTransactions()

            let definitions = try await repository
                .definitions(filter: nil)
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            let occurrences = try await repository.occurrences(query: nil)

            let definitionsLookup = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

            var categoriesDict: [UUID: String] = [:]
            for definition in definitions {
                if let categoryId = definition.categoryId, categoriesDict[categoryId] == nil {
                    categoriesDict[categoryId] = definition.name
                }
            }

            let transactionsDict = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0.title) })

            let presentation = presenter.makePresentation(
                input: RecurringPaymentReconciliationPresenter.PresentationInput(
                    occurrences: occurrences,
                    definitions: definitionsLookup,
                    categories: categoriesDict,
                    transactions: transactionsDict,
                    referenceDate: referenceDate
                )
            )

            return RefreshComputation(
                transactions: transactions,
                rows: presentation.rows,
                occurrenceLookup: presentation.occurrenceLookup,
                definitionsLookup: definitionsLookup,
                linkedTransactionLookup: presentation.linkedTransactionLookup
            )
        }.value
    }

    private func applyRefreshResult(_ result: RefreshComputation) {
        transactions = result.transactions
        definitionsLookup = result.definitionsLookup
        rows = result.rows
        occurrenceLookup = result.occurrenceLookup
        linkedTransactionLookup = result.linkedTransactionLookup
        candidateTransactions = []
        applyFilters()

        if let selectedOccurrenceId,
           occurrenceLookup[selectedOccurrenceId] != nil,
           filteredRows.contains(where: { $0.id == selectedOccurrenceId }) {
            updateEditorState()
        } else {
            selectedOccurrenceId = filteredRows.first?.id
        }
    }

    private func applyRefreshFailure(_ error: Error) {
        transactions = []
        rows = []
        filteredRows = []
        occurrenceLookup = [:]
        linkedTransactionLookup = [:]
        candidateTransactions = []
        errorMessage = "定期支払い情報の取得に失敗しました: \(error.localizedDescription)"
    }

    var selectedOccurrence: RecurringPaymentOccurrence? {
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

    private func recomputeCandidates(for occurrence: RecurringPaymentOccurrence) {
        guard let definition = definitionsLookup[occurrence.definitionId] else {
            candidateTransactions = []
            return
        }

        let context = RecurringPaymentReconciliationPresenter.TransactionCandidateSearchContext(
            transactions: transactions,
            linkedTransactionLookup: linkedTransactionLookup,
            windowDays: candidateSearchWindowDays,
            limit: candidateLimit,
            currentDate: currentDateProvider()
        )
        candidateTransactions = presenter.transactionCandidates(
            for: occurrence,
            definition: definition,
            context: context
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

    private func transactionById(_ id: UUID?) -> Transaction? {
        guard let id else { return nil }
        return transactions.first { $0.id == id }
    }
}
