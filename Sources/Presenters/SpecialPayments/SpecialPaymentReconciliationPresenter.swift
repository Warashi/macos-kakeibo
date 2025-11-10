import Foundation

internal struct SpecialPaymentReconciliationPresenter {
    internal struct Presentation {
        internal let rows: [OccurrenceRow]
        internal let occurrenceLookup: [UUID: SpecialPaymentOccurrence]
        internal let linkedTransactionLookup: [UUID: UUID]
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
            referenceDate: Date
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
                return true
            case .completed, .cancelled:
                return false
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
                return "予定"
            case .saving:
                return "積立中"
            case .completed:
                return "完了"
            case .cancelled:
                return "中止"
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
        private let calendar: Calendar
        private let windowDays: Int

        internal init(calendar: Calendar, windowDays: Int) {
            self.calendar = calendar
            self.windowDays = max(windowDays, 1)
        }

        internal func score(
            occurrence: SpecialPaymentOccurrence,
            transaction: Transaction
        ) -> TransactionCandidateScore {
            let expectedAmount = occurrence.expectedAmount
            let actualAmount = transaction.absoluteAmount
            let amountDifference = abs(actualAmount.safeSubtract(expectedAmount))
            let normalizedAmountDiff: Double = if expectedAmount.isZero {
                1
            } else {
                min(
                    1,
                    amountDifference.safeDivide(expectedAmount).doubleValue
                )
            }
            let amountScore = 1 - normalizedAmountDiff

            let dayDifference = abs(
                calendar.dateComponents(
                    [.day],
                    from: occurrence.scheduledDate,
                    to: transaction.date
                ).day ?? 0
            )
            let normalizedDays = min(
                1,
                Double(dayDifference) / Double(windowDays)
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
                    (amountScore * 0.5) + (dateScore * 0.3) + (titleScore * 0.2)
                )
            )

            return TransactionCandidateScore(
                total: totalScore,
                amountDifference: amountDifference,
                dayDifference: dayDifference,
                titleMatched: titleMatched
            )
        }
    }

    private let calendar: Calendar

    internal init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    internal func makePresentation(
        definitions: [SpecialPaymentDefinition],
        referenceDate: Date
    ) -> Presentation {
        var rows: [OccurrenceRow] = []
        var occurrenceLookup: [UUID: SpecialPaymentOccurrence] = [:]
        var linkedTransactionLookup: [UUID: UUID] = [:]

        for definition in definitions {
            for occurrence in definition.occurrences {
                rows.append(
                    OccurrenceRow(
                        occurrence: occurrence,
                        definition: definition,
                        referenceDate: referenceDate
                    )
                )
                occurrenceLookup[occurrence.id] = occurrence
                if let transaction = occurrence.transaction {
                    linkedTransactionLookup[transaction.id] = occurrence.id
                }
            }
        }

        rows.sort { lhs, rhs in
            if lhs.needsAttention == rhs.needsAttention {
                if lhs.scheduledDate == rhs.scheduledDate {
                    return lhs.definitionName < rhs.definitionName
                }
                return lhs.scheduledDate < rhs.scheduledDate
            }
            return lhs.needsAttention && !rhs.needsAttention
        }

        return Presentation(
            rows: rows,
            occurrenceLookup: occurrenceLookup,
            linkedTransactionLookup: linkedTransactionLookup
        )
    }

    internal func transactionCandidates(
        for occurrence: SpecialPaymentOccurrence,
        transactions: [Transaction],
        linkedTransactionLookup: [UUID: UUID],
        windowDays: Int,
        limit: Int
    ) -> [TransactionCandidate] {
        let scorer = TransactionCandidateScorer(calendar: calendar, windowDays: windowDays)

        let startWindow = calendar.date(byAdding: .day, value: -windowDays, to: occurrence.scheduledDate)
        let endWindow = calendar.date(byAdding: .day, value: windowDays, to: occurrence.scheduledDate)

        var candidates: [TransactionCandidate] = []

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

            candidates.append(
                TransactionCandidate(
                    transaction: transaction,
                    score: score,
                    isCurrentLink: isCurrentLink
                )
            )
        }

        if let linkedTransaction = occurrence.transaction,
           !candidates.contains(where: { $0.transaction.id == linkedTransaction.id }) {
            let score = scorer.score(occurrence: occurrence, transaction: linkedTransaction)
            candidates.append(
                TransactionCandidate(
                    transaction: linkedTransaction,
                    score: score,
                    isCurrentLink: true
                )
            )
        }

        candidates.sort()
        return Array(candidates.prefix(limit))
    }
}
