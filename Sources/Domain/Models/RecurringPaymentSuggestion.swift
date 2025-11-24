import Foundation

/// 定期支払いの提案を表す構造体
internal struct RecurringPaymentSuggestion: Identifiable, Sendable {
    /// 一意識別子
    internal let id: UUID

    /// 推測された名称（取引のtitleから）
    internal let suggestedName: String

    /// 推測された金額（平均または最頻値）
    internal let suggestedAmount: Decimal

    /// 推測された周期（月数）
    internal let suggestedRecurrenceMonths: Int

    /// 推測された開始日（最も古い取引の日付）
    internal let suggestedStartDate: Date

    /// 推測されたカテゴリID（最も多く使われたカテゴリ）
    internal let suggestedCategoryId: UUID?

    /// 推測された日付パターン
    internal let suggestedDayPattern: DayOfMonthPattern

    /// マッチングキーワード候補
    internal let suggestedMatchKeywords: [String]

    /// グループ化された取引のリスト
    internal let relatedTransactions: [Transaction]

    /// 検出回数
    internal var occurrenceCount: Int {
        relatedTransactions.count
    }

    /// 最後の取引日
    internal var lastOccurrenceDate: Date? {
        relatedTransactions.map(\.date).max()
    }

    /// 金額が安定しているか（変動係数が20%以内）
    internal let isAmountStable: Bool

    /// 金額の変動範囲（最小値〜最大値）
    internal let amountRange: ClosedRange<Decimal>?

    /// パターンの説明（UI表示用）
    internal var patternDescription: String {
        let interval: String = if suggestedRecurrenceMonths == 1 {
            "毎月"
        } else if suggestedRecurrenceMonths == 12 {
            "毎年"
        } else {
            "\(suggestedRecurrenceMonths)か月ごと"
        }

        let dayInfo: String = switch suggestedDayPattern {
        case let .fixed(day):
            "\(day)日付近"
        case .endOfMonth:
            "月末"
        case let .endOfMonthMinus(days):
            "月末\(days)日前"
        case .firstBusinessDay:
            "最初の営業日"
        case .lastBusinessDay:
            "最終営業日"
        default:
            ""
        }

        return "\(interval) \(dayInfo)"
    }

    /// 信頼度スコア（0.0〜1.0）
    internal let confidenceScore: Double

    internal init(
        id: UUID = UUID(),
        suggestedName: String,
        suggestedAmount: Decimal,
        suggestedRecurrenceMonths: Int,
        suggestedStartDate: Date,
        suggestedCategoryId: UUID?,
        suggestedDayPattern: DayOfMonthPattern,
        suggestedMatchKeywords: [String],
        relatedTransactions: [Transaction],
        isAmountStable: Bool,
        amountRange: ClosedRange<Decimal>?,
        confidenceScore: Double,
    ) {
        self.id = id
        self.suggestedName = suggestedName
        self.suggestedAmount = suggestedAmount
        self.suggestedRecurrenceMonths = suggestedRecurrenceMonths
        self.suggestedStartDate = suggestedStartDate
        self.suggestedCategoryId = suggestedCategoryId
        self.suggestedDayPattern = suggestedDayPattern
        self.suggestedMatchKeywords = suggestedMatchKeywords
        self.relatedTransactions = relatedTransactions
        self.isAmountStable = isAmountStable
        self.amountRange = amountRange
        self.confidenceScore = confidenceScore
    }
}

/// 定期支払い検出の条件
internal struct RecurringPaymentDetectionCriteria: Sendable {
    /// 対象期間の開始日（今日からN年前）
    internal let lookbackYears: Int

    /// 最小検出回数
    internal let minimumOccurrences: Int

    /// 日付の許容誤差（日数）
    internal let dateToleranceDays: Int

    /// 金額の許容変動率（0.0〜1.0）
    internal let amountVariationTolerance: Double

    internal static let `default`: RecurringPaymentDetectionCriteria = RecurringPaymentDetectionCriteria(
        lookbackYears: 3,
        minimumOccurrences: 2,
        dateToleranceDays: 3,
        amountVariationTolerance: 0.2,
    )
}
