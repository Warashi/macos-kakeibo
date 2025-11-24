import Foundation

/// 取引データから定期支払いのパターンを検出するサービス
internal struct RecurringPaymentDetectionService: Sendable {
    private let criteria: RecurringPaymentDetectionCriteria
    private let calendar: Calendar

    internal init(
        criteria: RecurringPaymentDetectionCriteria = .default,
        calendar: Calendar = .current
    ) {
        self.criteria = criteria
        self.calendar = calendar
    }

    /// 取引リストから定期支払いの提案を生成
    internal func detectSuggestions(
        from transactions: [Transaction],
        existingDefinitions: [RecurringPaymentDefinition]
    ) -> [RecurringPaymentSuggestion] {
        // 1. 取引をグループ化
        let groups = groupTransactions(transactions)

        // 2. 各グループから提案を生成
        let suggestions = groups.compactMap { group in
            detectPattern(in: group)
        }

        // 3. 既存の定期支払いと重複するものを除外
        let filtered = filterDuplicates(suggestions, existingDefinitions: existingDefinitions)

        // 4. 信頼度スコアでソート
        return filtered.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    // MARK: - Private Methods

    /// 取引をtitleの類似度でグループ化
    private func groupTransactions(_ transactions: [Transaction]) -> [[Transaction]] {
        var groups: [[Transaction]] = []
        var processed: Set<UUID> = []

        for transaction in transactions {
            guard !processed.contains(transaction.id) else { continue }

            // 類似する取引を見つける
            var group = [transaction]
            processed.insert(transaction.id)

            for other in transactions where !processed.contains(other.id) {
                if areTitlesSimilar(transaction.title, other.title) {
                    group.append(other)
                    processed.insert(other.id)
                }
            }

            // 最小検出回数を満たすグループのみ保持
            if group.count >= criteria.minimumOccurrences {
                groups.append(group)
            }
        }

        return groups
    }

    /// titleの類似性を判定
    private func areTitlesSimilar(_ title1: String, _ title2: String) -> Bool {
        let normalized1 = normalizeTitle(title1)
        let normalized2 = normalizeTitle(title2)

        // 完全一致
        if normalized1 == normalized2 {
            return true
        }

        // Levenshtein距離ベースの類似度（簡易版）
        let distance = levenshteinDistance(normalized1, normalized2)
        let maxLength = max(normalized1.count, normalized2.count)
        guard maxLength > 0 else { return false }

        let similarity = 1.0 - Double(distance) / Double(maxLength)
        return similarity >= 0.8 // 80%以上の類似度
    }

    /// titleの正規化（空白除去、小文字化）
    private func normalizeTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// Levenshtein距離の計算（編集距離）
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count {
            dist[i][0] = i
        }
        for j in 0...b.count {
            dist[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dist[i][j] = min(
                    dist[i - 1][j] + 1,
                    dist[i][j - 1] + 1,
                    dist[i - 1][j - 1] + cost
                )
            }
        }

        return dist[a.count][b.count]
    }

    /// グループから定期支払いパターンを検出
    private func detectPattern(in transactions: [Transaction]) -> RecurringPaymentSuggestion? {
        guard transactions.count >= criteria.minimumOccurrences else { return nil }

        // 日付でソート
        let sorted = transactions.sorted { $0.date < $1.date }

        // 周期性を検出
        guard let recurrenceMonths = detectRecurrence(in: sorted) else { return nil }

        // 日付パターンを推測
        let dayPattern = detectDayPattern(in: sorted)

        // 金額の分析
        let amounts = sorted.map(\.absoluteAmount)
        let avgAmount = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)
        let (isStable, range) = analyzeAmountStability(amounts)

        // カテゴリの推測（最頻値）
        let categoryId = detectMostFrequentCategory(in: sorted)

        // マッチングキーワードの生成
        let keywords = generateMatchKeywords(from: sorted)

        // 信頼度スコアの計算
        let confidence = calculateConfidence(
            occurrenceCount: sorted.count,
            isAmountStable: isStable,
            recurrenceMonths: recurrenceMonths
        )

        return RecurringPaymentSuggestion(
            suggestedName: sorted.first?.title ?? "",
            suggestedAmount: avgAmount,
            suggestedRecurrenceMonths: recurrenceMonths,
            suggestedStartDate: sorted.first?.date ?? Date(),
            suggestedCategoryId: categoryId,
            suggestedDayPattern: dayPattern,
            suggestedMatchKeywords: keywords,
            relatedTransactions: sorted,
            isAmountStable: isStable,
            amountRange: range,
            confidenceScore: confidence
        )
    }

    /// 周期性を検出（1, 2, 3, 6, 12ヶ月のいずれか）
    private func detectRecurrence(in transactions: [Transaction]) -> Int? {
        guard transactions.count >= 2 else { return nil }

        let candidateIntervals = [1, 2, 3, 6, 12]

        // 各候補の周期について、日付間隔をチェック
        for interval in candidateIntervals {
            if isRecurring(transactions, withMonthInterval: interval) {
                return interval
            }
        }

        return nil
    }

    /// 指定された月間隔で定期的かチェック
    private func isRecurring(_ transactions: [Transaction], withMonthInterval interval: Int) -> Bool {
        guard transactions.count >= 2 else { return false }

        var matchCount = 0
        for i in 1..<transactions.count {
            let prev = transactions[i - 1].date
            let curr = transactions[i].date

            let expectedDate = calendar.date(byAdding: .month, value: interval, to: prev)!
            let daysDiff = abs(calendar.dateComponents([.day], from: expectedDate, to: curr).day ?? 0)

            if daysDiff <= criteria.dateToleranceDays {
                matchCount += 1
            }
        }

        // 70%以上の間隔が一致していれば定期的とみなす
        let threshold = Double(transactions.count - 1) * 0.7
        return Double(matchCount) >= threshold
    }

    /// 日付パターンを検出
    private func detectDayPattern(in transactions: [Transaction]) -> DayOfMonthPattern {
        let days = transactions.map { calendar.component(.day, from: $0.date) }

        // 月末付近かチェック（25日以降）
        let isEndOfMonth = days.allSatisfy { $0 >= 25 }
        if isEndOfMonth {
            return .endOfMonth
        }

        // 固定日パターン（最頻値）
        let dayFrequency = Dictionary(days.map { ($0, 1) }, uniquingKeysWith: +)
        if let mostFrequentDay = dayFrequency.max(by: { $0.value < $1.value })?.key {
            return .fixed(mostFrequentDay)
        }

        // デフォルトは最初の取引の日
        return .fixed(days.first ?? 1)
    }

    /// 金額の安定性を分析
    private func analyzeAmountStability(_ amounts: [Decimal]) -> (isStable: Bool, range: ClosedRange<Decimal>?) {
        guard !amounts.isEmpty else { return (false, nil) }

        let min = amounts.min()!
        let max = amounts.max()!
        let avg = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)

        let range = min...max

        // 変動係数を計算（簡易版：範囲の変動率）
        let avgDouble = NSDecimalNumber(decimal: avg).doubleValue
        let variation: Double
        if avgDouble > 0 {
            let minDouble = NSDecimalNumber(decimal: min).doubleValue
            let maxDouble = NSDecimalNumber(decimal: max).doubleValue
            variation = (maxDouble - minDouble) / avgDouble
        } else {
            variation = 0
        }

        let isStable = variation <= criteria.amountVariationTolerance

        return (isStable, range)
    }

    /// 最も頻度の高いカテゴリを検出
    private func detectMostFrequentCategory(in transactions: [Transaction]) -> UUID? {
        let categoryIds = transactions.compactMap(\.minorCategoryId)
        guard !categoryIds.isEmpty else {
            return transactions.compactMap(\.majorCategoryId).first
        }

        let frequency = Dictionary(categoryIds.map { ($0, 1) }, uniquingKeysWith: +)
        return frequency.max(by: { $0.value < $1.value })?.key
    }

    /// マッチングキーワードを生成
    private func generateMatchKeywords(from transactions: [Transaction]) -> [String] {
        guard let first = transactions.first else { return [] }
        let normalized = normalizeTitle(first.title)

        // 空白で分割してキーワード化
        let words = normalized.split(separator: " ").map(String.init)
        return words.isEmpty ? [normalized] : words
    }

    /// 信頼度スコアを計算
    private func calculateConfidence(
        occurrenceCount: Int,
        isAmountStable: Bool,
        recurrenceMonths: Int
    ) -> Double {
        var score = 0.0

        // 検出回数によるスコア（最大0.5）
        score += min(Double(occurrenceCount) / 12.0, 0.5)

        // 金額の安定性（0.3）
        if isAmountStable {
            score += 0.3
        }

        // 周期の一般性（毎月=0.2、その他=0.1）
        if recurrenceMonths == 1 {
            score += 0.2
        } else {
            score += 0.1
        }

        return min(score, 1.0)
    }

    /// 既存の定期支払いと重複するものを除外
    private func filterDuplicates(
        _ suggestions: [RecurringPaymentSuggestion],
        existingDefinitions: [RecurringPaymentDefinition]
    ) -> [RecurringPaymentSuggestion] {
        suggestions.filter { suggestion in
            !existingDefinitions.contains { definition in
                // 名称の類似性でチェック
                areTitlesSimilar(suggestion.suggestedName, definition.name)
            }
        }
    }
}
