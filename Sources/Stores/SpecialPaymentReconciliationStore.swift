import Foundation
import Observation
import SwiftData

@Observable
@MainActor
internal final class SpecialPaymentReconciliationStore {
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

    internal struct OccurrenceRow: Identifiable, Hashable {
        internal let id: UUID
        internal let definitionName: String
        internal let categoryName: String?
        internal let scheduledDate: Date
        internal let expectedAmount: Decimal
        internal let status: SpecialPaymentStatus
        internal let recurrenceDescription: String
        internal let transactionTitle: String?
        internal let actualAmount: Decimal?
        internal let isOverdue: Bool

        internal init(
            occurrence: SpecialPaymentOccurrence,
            definition: SpecialPaymentDefinition,
            referenceDate: Date,
        ) {
            self.id = occurrence.id
            self.definitionName = definition.name
            self.categoryName = definition.category?.fullName
            self.scheduledDate = occurrence.scheduledDate
            self.expectedAmount = occurrence.expectedAmount
            self.status = occurrence.status
            self.recurrenceDescription = definition.recurrenceDescription
            self.transactionTitle = occurrence.transaction?.title
            self.actualAmount = occurrence.actualAmount
            self.isOverdue = occurrence.scheduledDate < referenceDate && !occurrence.isCompleted
        }

        internal var needsAttention: Bool {
            switch status {
            case .planned, .saving:
                true
            case .completed, .cancelled:
                false
            }
        }

        internal var isUpcoming: Bool {
            !isCompleted && !isOverdue
        }

        internal var isCompleted: Bool {
            status == .completed
        }

        internal var statusLabel: String {
            switch status {
            case .planned:
                "予定"
            case .saving:
                "積立中"
            case .completed:
                "完了"
            case .cancelled:
                "中止"
            }
        }

        internal var differenceAmount: Decimal? {
            guard let actualAmount else { return nil }
            return actualAmount.safeSubtract(expectedAmount)
        }

        internal func matches(searchText: String) -> Bool {
            guard !searchText.isEmpty else { return true }
            let lowered = searchText.lowercased()
            let haystacks: [String] = [
                definitionName,
                categoryName ?? "",
                recurrenceDescription,
                transactionTitle ?? "",
                scheduledDate.longDateFormatted,
            ]
            return haystacks.contains { $0.lowercased().contains(lowered) }
        }
    }

    internal struct TransactionCandidate: Identifiable, Hashable, Comparable {
        internal var id: UUID { transaction.id }
        internal let transaction: Transaction
        internal let score: TransactionCandidateScore
        internal let isCurrentLink: Bool

        internal static func < (lhs: TransactionCandidate, rhs: TransactionCandidate) -> Bool {
            if lhs.score.total == rhs.score.total {
                if lhs.score.amountDifference == rhs.score.amountDifference {
                    return lhs.score.dayDifference < rhs.score.dayDifference
                }
                return lhs.score.amountDifference < rhs.score.amountDifference
            }
            return lhs.score.total > rhs.score.total
        }
    }

    internal struct TransactionCandidateScore: Hashable {
        internal let total: Double
        internal let amountDifference: Decimal
        internal let dayDifference: Int
        internal let titleMatched: Bool

        internal var confidenceText: String {
            let percentage = Int((total * 100).rounded())
            return "\(percentage)%"
        }

        internal var detailDescription: String {
            let amountText: String = if amountDifference.isZero {
                "金額一致"
            } else {
                "差額 \(amountDifference.absoluteValue.currencyFormattedWithoutSymbol)"
            }

            let dayText: String = if dayDifference == 0 {
                "同日"
            } else {
                "±\(dayDifference)日"
            }

            if titleMatched {
                return "\(amountText) / \(dayText) / 名称一致"
            }
            return "\(amountText) / \(dayText)"
        }

        internal var isWithinBounds: Bool {
            let threshold = Decimal(5000)
            return total >= 0.2 || titleMatched || amountDifference <= threshold
        }
    }

    private struct TransactionCandidateScorer {
        private let calendar: Calendar = Calendar(identifier: .gregorian)
        private let windowDays: Int

        internal init(windowDays: Int) {
            self.windowDays = max(windowDays, 1)
        }

        internal func score(
            occurrence: SpecialPaymentOccurrence,
            transaction: Transaction,
        ) -> TransactionCandidateScore {
            let expectedAmount = occurrence.expectedAmount
            let actualAmount = transaction.absoluteAmount
            let amountDifference = abs(actualAmount.safeSubtract(expectedAmount))
            let normalizedAmountDiff: Double = if expectedAmount.isZero {
                1
            } else {
                min(
                    1,
                    amountDifference.safeDivide(expectedAmount).doubleValue,
                )
            }
            let amountScore = 1 - normalizedAmountDiff

            let dayDifference = abs(
                calendar.dateComponents(
                    [.day],
                    from: occurrence.scheduledDate,
                    to: transaction.date,
                ).day ?? 0,
            )
            let normalizedDays = min(
                1,
                Double(dayDifference) / Double(windowDays),
            )
            let dateScore = 1 - normalizedDays

            let normalizedDefinition = occurrence.definition.name.lowercased()
            let normalizedTitle = transaction.title.lowercased()
            let titleMatched = !normalizedDefinition.isEmpty && (
                normalizedTitle.contains(normalizedDefinition)
                    || normalizedDefinition.contains(normalizedTitle)
            )
            let titleScore = titleMatched ? 1.0 : 0.0

            let totalScore = max(
                0,
                min(
                    1,
                    (amountScore * 0.5) + (dateScore * 0.3) + (titleScore * 0.2),
                ),
            )

            return TransactionCandidateScore(
                total: totalScore,
                amountDifference: amountDifference,
                dayDifference: dayDifference,
                titleMatched: titleMatched,
            )
        }
    }

    // MARK: - Dependencies

    private let repository: SpecialPaymentRepository
    private let transactionRepository: TransactionRepository
    private let specialPaymentStore: SpecialPaymentStore
    private let currentDateProvider: () -> Date
    private let candidateSearchWindowDays: Int
    private let candidateLimit: Int

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

    private var occurrenceLookup: [UUID: SpecialPaymentOccurrence] = [:]
    private var linkedTransactionLookup: [UUID: UUID] = [:]
    private var transactions: [Transaction] = []
    private let calendar: Calendar = Calendar(identifier: .gregorian)

    // MARK: - Initialization

    internal init(
        repository: SpecialPaymentRepository,
        transactionRepository: TransactionRepository,
        candidateSearchWindowDays: Int = 60,
        candidateLimit: Int = 12,
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
        self.specialPaymentStore = SpecialPaymentStore(
            repository: repository,
            currentDateProvider: currentDateProvider
        )
        self.candidateSearchWindowDays = candidateSearchWindowDays
        self.candidateLimit = candidateLimit
        self.currentDateProvider = currentDateProvider
    }

    internal convenience init(
        modelContext: ModelContext,
        transactionRepository: TransactionRepository? = nil,
        candidateSearchWindowDays: Int = 60,
        candidateLimit: Int = 12,
        currentDateProvider: @escaping () -> Date = { Date() }
    ) {
        let repository = SpecialPaymentRepositoryFactory.make(
            modelContext: modelContext,
            currentDateProvider: currentDateProvider
        )
        let resolvedTransactionRepository = transactionRepository ?? SwiftDataTransactionRepository(modelContext: modelContext)
        self.init(
            repository: repository,
            transactionRepository: resolvedTransactionRepository,
            candidateSearchWindowDays: candidateSearchWindowDays,
            candidateLimit: candidateLimit,
            currentDateProvider: currentDateProvider
        )
    }

    // MARK: - Accessors

    internal var selectedRow: OccurrenceRow? {
        guard let id = selectedOccurrenceId else { return nil }
        return filteredRows.first(where: { $0.id == id }) ?? rows.first(where: { $0.id == id })
    }
}

// MARK: - Actions

internal extension SpecialPaymentReconciliationStore {
    func refresh() {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            transactions = try transactionRepository.fetchAllTransactions()

            let definitions = try repository.definitions(filter: nil)
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            let referenceDate = currentDateProvider()

            var newRows: [OccurrenceRow] = []
            var occurrenceMap: [UUID: SpecialPaymentOccurrence] = [:]
            var linkedMap: [UUID: UUID] = [:]

            for definition in definitions {
                for occurrence in definition.occurrences {
                    newRows.append(
                        OccurrenceRow(
                            occurrence: occurrence,
                            definition: definition,
                            referenceDate: referenceDate,
                        ),
                    )
                    occurrenceMap[occurrence.id] = occurrence
                    if let transaction = occurrence.transaction {
                        linkedMap[transaction.id] = occurrence.id
                    }
                }
            }

            newRows.sort { lhs, rhs in
                if lhs.needsAttention == rhs.needsAttention {
                    if lhs.scheduledDate == rhs.scheduledDate {
                        return lhs.definitionName < rhs.definitionName
                    }
                    return lhs.scheduledDate < rhs.scheduledDate
                }
                return lhs.needsAttention && !rhs.needsAttention
            }

            rows = newRows
            occurrenceLookup = occurrenceMap
            linkedTransactionLookup = linkedMap
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

    func saveSelectedOccurrence() {
        guard let occurrence = selectedOccurrence else {
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
            try specialPaymentStore.markOccurrenceCompleted(
                occurrence,
                input: input,
            )
            statusMessage = "実績を保存しました。"
            refresh()
            selectedOccurrenceId = occurrence.id
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

    func unlinkSelectedOccurrence() {
        guard let occurrence = selectedOccurrence else {
            errorMessage = "解除対象の特別支払いを選択してください。"
            return
        }

        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            try specialPaymentStore.updateOccurrence(
                occurrence,
                input: OccurrenceUpdateInput(
                    status: .planned,
                    actualDate: nil,
                    actualAmount: nil,
                    transaction: nil
                )
            )
            statusMessage = "取引リンクを解除しました。"
            refresh()
            selectedOccurrenceId = occurrence.id
        } catch {
            errorMessage = "リンク解除に失敗しました: \(error.localizedDescription)"
        }
    }

    func resetFormToExpectedValues() {
        guard let occurrence = selectedOccurrence else { return }
        actualAmountText = occurrence.expectedAmount.plainString
        actualDate = occurrence.scheduledDate
        selectedTransactionId = occurrence.transaction?.id
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Private Helpers

private extension SpecialPaymentReconciliationStore {
    var selectedOccurrence: SpecialPaymentOccurrence? {
        guard let id = selectedOccurrenceId else { return nil }
        return occurrenceLookup[id]
    }

    private func applyFilters() {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let loweredSearch = normalizedSearch.lowercased()
        filteredRows = rows.filter { row in
            filter.matches(row: row)
                && row.matches(searchText: loweredSearch)
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
        selectedTransactionId = occurrence.transaction?.id
        recomputeCandidates(for: occurrence)
    }

    private func recomputeCandidates(for occurrence: SpecialPaymentOccurrence) {
        let scorer = TransactionCandidateScorer(windowDays: candidateSearchWindowDays)

        let startWindow = calendar.date(byAdding: .day, value: -candidateSearchWindowDays, to: occurrence.scheduledDate)
        let endWindow = calendar.date(byAdding: .day, value: candidateSearchWindowDays, to: occurrence.scheduledDate)

        var newCandidates: [TransactionCandidate] = []

        for transaction in transactions {
            let linkedOccurrenceId = linkedTransactionLookup[transaction.id]
            if let linkedOccurrenceId, linkedOccurrenceId != occurrence.id {
                continue
            }
            let isCurrentLink = linkedOccurrenceId == occurrence.id

            guard transaction.isExpense, transaction.isIncludedInCalculation else {
                continue
            }

            if let startWindow, let endWindow,
               !transaction.date.isInRange(from: startWindow, to: endWindow) {
                continue
            }

            let score = scorer.score(occurrence: occurrence, transaction: transaction)
            guard score.isWithinBounds else { continue }

            newCandidates.append(
                TransactionCandidate(
                    transaction: transaction,
                    score: score,
                    isCurrentLink: isCurrentLink,
                ),
            )
        }

        if let linkedTransaction = occurrence.transaction,
           !newCandidates.contains(where: { $0.transaction.id == linkedTransaction.id }) {
            let score = scorer.score(occurrence: occurrence, transaction: linkedTransaction)
            newCandidates.append(
                TransactionCandidate(
                    transaction: linkedTransaction,
                    score: score,
                    isCurrentLink: true,
                ),
            )
        }

        newCandidates.sort()
        candidateTransactions = Array(newCandidates.prefix(candidateLimit))
    }

    private func decimalAmount(from text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "ja_JP"))
            ?? Decimal(string: normalized)
    }

    private func transactionById(_ id: UUID) -> Transaction? {
        transactions.first { $0.id == id }
    }
}
