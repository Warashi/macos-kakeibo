import Foundation

internal struct RecurringPaymentReconciliationPresenter {
    internal struct Presentation {
        internal let rows: [OccurrenceRow]
        internal let occurrenceLookup: [UUID: RecurringPaymentOccurrenceDTO]
        internal let linkedTransactionLookup: [UUID: UUID]
    }

    internal struct OccurrenceRow: Identifiable, Hashable {
        internal let id: UUID
        internal let definitionName: String
        internal let categoryName: String?
        internal let scheduledDate: Date
        internal let expectedAmount: Decimal
        internal let status: RecurringPaymentStatus
        internal let recurrenceDescription: String
        internal let transactionTitle: String?
        internal let actualAmount: Decimal?
        internal let isOverdue: Bool

        internal init(
            occurrence: RecurringPaymentOccurrenceDTO,
            definition: RecurringPaymentDefinitionDTO,
            categoryName: String?,
            transactionTitle: String?,
            referenceDate: Date,
        ) {
            self.id = occurrence.id
            self.definitionName = definition.name
            self.categoryName = categoryName
            self.scheduledDate = occurrence.scheduledDate
            self.expectedAmount = occurrence.expectedAmount
            self.status = occurrence.status
            self.recurrenceDescription = Self.makeRecurrenceDescription(
                recurrenceIntervalMonths: definition.recurrenceIntervalMonths,
            )
            self.transactionTitle = transactionTitle
            self.actualAmount = occurrence.actualAmount
            self.isOverdue = occurrence.scheduledDate < referenceDate && !occurrence.isCompleted
        }

        private static func makeRecurrenceDescription(recurrenceIntervalMonths: Int) -> String {
            guard recurrenceIntervalMonths > 0 else { return "未設定" }
            let years = recurrenceIntervalMonths / 12
            let months = recurrenceIntervalMonths % 12

            switch (years, months) {
            case let (0, monthsOnly):
                return "\(monthsOnly)か月"
            case let (yearsOnly, 0):
                return "\(yearsOnly)年"
            default:
                return "\(years)年\(months)か月"
            }
        }

        internal var needsAttention: Bool {
            isOverdue
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

        internal func matches(searchText: SearchText) -> Bool {
            searchText.matchesAny(
                haystacks: [
                    definitionName,
                    categoryName ?? "",
                    recurrenceDescription,
                    transactionTitle ?? "",
                    scheduledDate.longDateFormatted,
                ],
            )
        }
    }

    internal struct TransactionCandidate: Identifiable, Hashable, Comparable {
        internal var id: UUID { transaction.id }
        internal let transaction: TransactionDTO
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

    internal struct TransactionCandidateSearchContext {
        internal let transactions: [TransactionDTO]
        internal let linkedTransactionLookup: [UUID: UUID]
        internal let windowDays: Int
        internal let limit: Int
        internal let currentDate: Date
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
            occurrence: RecurringPaymentOccurrenceDTO,
            definition: RecurringPaymentDefinitionDTO,
            transaction: TransactionDTO,
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

            let normalizedDefinition = definition.name.lowercased()
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

    private let calendar: Calendar

    internal init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    internal struct PresentationInput {
        internal let occurrences: [RecurringPaymentOccurrenceDTO]
        internal let definitions: [UUID: RecurringPaymentDefinitionDTO]
        internal let categories: [UUID: String]
        internal let transactions: [UUID: String]
        internal let referenceDate: Date
    }

    internal func makePresentation(input: PresentationInput) -> Presentation {
        let occurrences = input.occurrences
        let definitions = input.definitions
        let categories = input.categories
        let transactions = input.transactions
        let referenceDate = input.referenceDate
        var rows: [OccurrenceRow] = []
        var occurrenceLookup: [UUID: RecurringPaymentOccurrenceDTO] = [:]
        var linkedTransactionLookup: [UUID: UUID] = [:]

        for occurrence in occurrences {
            guard let definition = definitions[occurrence.definitionId] else {
                continue
            }
            let categoryName = definition.categoryId.flatMap { categories[$0] }
            let transactionTitle = occurrence.transactionId.flatMap { transactions[$0] }

            rows.append(
                OccurrenceRow(
                    occurrence: occurrence,
                    definition: definition,
                    categoryName: categoryName,
                    transactionTitle: transactionTitle,
                    referenceDate: referenceDate,
                ),
            )
            occurrenceLookup[occurrence.id] = occurrence
            if let transactionId = occurrence.transactionId {
                linkedTransactionLookup[transactionId] = occurrence.id
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
            linkedTransactionLookup: linkedTransactionLookup,
        )
    }

    internal func transactionCandidates(
        for occurrence: RecurringPaymentOccurrenceDTO,
        definition: RecurringPaymentDefinitionDTO,
        context: TransactionCandidateSearchContext,
    ) -> [TransactionCandidate] {
        let scorer = TransactionCandidateScorer(calendar: calendar, windowDays: context.windowDays)

        let startWindow = calendar.date(byAdding: .day, value: -context.windowDays, to: occurrence.scheduledDate)
        let calculatedEndWindow = calendar.date(byAdding: .day, value: context.windowDays, to: occurrence.scheduledDate)
        let endWindow = calculatedEndWindow.map { min($0, context.currentDate) }

        var candidates: [TransactionCandidate] = []

        for transaction in context.transactions {
            let linkedOccurrenceId = context.linkedTransactionLookup[transaction.id]
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

            let score = scorer.score(occurrence: occurrence, definition: definition, transaction: transaction)
            guard score.isWithinBounds else { continue }

            candidates.append(
                TransactionCandidate(
                    transaction: transaction,
                    score: score,
                    isCurrentLink: isCurrentLink,
                ),
            )
        }

        candidates.sort()
        return Array(candidates.prefix(context.limit))
    }
}
