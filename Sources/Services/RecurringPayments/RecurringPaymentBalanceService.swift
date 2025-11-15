import Foundation
import SwiftData

// MARK: - 支払差分情報

/// 実績支払いと予定金額の差分
internal struct PaymentDifference: Sendable {
    /// 予定金額
    internal let expected: Decimal

    /// 実績金額
    internal let actual: Decimal

    /// 差分（actual - expected）
    internal let difference: Decimal

    /// 差分タイプ
    internal let type: DifferenceType

    internal enum DifferenceType: Sendable {
        case overpaid // 実績 > 予定（超過払い）
        case underpaid // 実績 < 予定（過少払い）
        case exact // 実績 = 予定（ぴったり）
    }

    internal init(expected: Decimal, actual: Decimal) {
        self.expected = expected
        self.actual = actual
        self.difference = actual.safeSubtract(expected)

        if actual > expected {
            self.type = .overpaid
        } else if actual < expected {
            self.type = .underpaid
        } else {
            self.type = .exact
        }
    }
}

// MARK: - SpecialPaymentBalanceService

/// 特別支払いの積立残高管理サービス
///
/// 月次積立の記録、実績支払いの反映、残高の再計算を行います。
internal struct SpecialPaymentBalanceService: Sendable {
    private let cache: SpecialPaymentBalanceCache

    internal init(cache: SpecialPaymentBalanceCache = SpecialPaymentBalanceCache()) {
        self.cache = cache
    }

    internal func cacheMetrics() -> SpecialPaymentBalanceCacheMetrics {
        cache.metricsSnapshot
    }

    internal func invalidateCache(for balanceId: UUID? = nil) {
        cache.invalidate(balanceId: balanceId)
    }

    /// 月次積立記録パラメータ
    internal struct MonthlySavingsParameters {
        internal let definition: SpecialPaymentDefinition
        internal let balance: SpecialPaymentSavingBalance?
        internal let year: Int
        internal let month: Int
        internal let context: ModelContext
    }

    /// 月次積立を記録
    /// - Parameter params: 月次積立記録パラメータ
    /// - Returns: 更新または新規作成された残高
    @discardableResult
    internal func recordMonthlySavings(params: MonthlySavingsParameters) -> SpecialPaymentSavingBalance {
        let definition = params.definition
        let balance = params.balance
        let year = params.year
        let month = params.month
        let context = params.context
        let monthlySaving = definition.monthlySavingAmount

        if let existingBalance = balance {
            // すでに同じ年月で記録済みの場合はスキップ
            if existingBalance.lastUpdatedYear == year, existingBalance.lastUpdatedMonth == month {
                return existingBalance
            }

            // 積立額を加算
            existingBalance.totalSavedAmount = existingBalance.totalSavedAmount.safeAdd(monthlySaving)
            existingBalance.lastUpdatedYear = year
            existingBalance.lastUpdatedMonth = month
            existingBalance.updatedAt = Date()

            cache.invalidate(balanceId: existingBalance.id)
            return existingBalance
        } else {
            // 新規作成
            let newBalance = SpecialPaymentSavingBalance(
                definition: definition,
                totalSavedAmount: monthlySaving,
                totalPaidAmount: 0,
                lastUpdatedYear: year,
                lastUpdatedMonth: month,
            )
            context.insert(newBalance)
            cache.invalidate(balanceId: newBalance.id)
            return newBalance
        }
    }

    /// 実績支払いを反映
    /// - Parameters:
    ///   - occurrence: 完了したOccurrence
    ///   - balance: 積立残高
    ///   - context: ModelContext
    /// - Returns: 支払差分情報
    @discardableResult
    internal func processPayment(
        occurrence: SpecialPaymentOccurrence,
        balance: SpecialPaymentSavingBalance,
        context: ModelContext,
    ) -> PaymentDifference {
        guard let actualAmount = occurrence.actualAmount else {
            // 実績金額がない場合は、予定金額を使用
            return PaymentDifference(expected: occurrence.expectedAmount, actual: 0)
        }

        // 差分を計算
        let difference = PaymentDifference(
            expected: occurrence.expectedAmount,
            actual: actualAmount,
        )

        // 残高から実績金額を差し引く
        balance.totalPaidAmount = balance.totalPaidAmount.safeAdd(actualAmount)
        balance.updatedAt = Date()
        cache.invalidate(balanceId: balance.id)

        return difference
    }

    /// 残高再計算パラメータ
    internal struct RecalculateBalanceParameters {
        internal let definition: SpecialPaymentDefinition
        internal let balance: SpecialPaymentSavingBalance
        internal let year: Int
        internal let month: Int
        internal let startYear: Int?
        internal let startMonth: Int?
        internal let context: ModelContext

        internal init(
            definition: SpecialPaymentDefinition,
            balance: SpecialPaymentSavingBalance,
            year: Int,
            month: Int,
            startYear: Int? = nil,
            startMonth: Int? = nil,
            context: ModelContext,
        ) {
            self.definition = definition
            self.balance = balance
            self.year = year
            self.month = month
            self.startYear = startYear
            self.startMonth = startMonth
            self.context = context
        }
    }

    /// 残高を再計算
    ///
    /// definitionの全occurrenceから残高を再計算します。
    /// データ修正時やデバッグ時に使用します。
    /// - Parameter params: 残高再計算パラメータ
    internal func recalculateBalance(params: RecalculateBalanceParameters) {
        let definition = params.definition
        let balance = params.balance
        let year = params.year
        let month = params.month
        let startYear = params.startYear
        let startMonth = params.startMonth
        let cacheKey = BalanceCacheKey(
            definitionId: definition.id,
            balanceId: balance.id,
            year: year,
            month: month,
            startYear: startYear,
            startMonth: startMonth,
            definitionVersion: definitionVersion(for: definition),
            balanceVersion: balanceVersion(for: balance),
        )
        if let snapshot = cache.snapshot(for: cacheKey) {
            apply(snapshot: snapshot, to: balance)
            return
        }
        // 完了済みのoccurrenceから累計支払額を計算
        let completedOccurrences = definition.occurrences.filter { $0.status == .completed }
        let totalPaid = completedOccurrences.reduce(Decimal(0)) { sum, occurrence in
            sum.safeAdd(occurrence.actualAmount ?? 0)
        }

        // 積立開始年月を決定
        let savingsStartYear: Int
        let savingsStartMonth: Int

        if let startYear, let startMonth {
            // 明示的に指定された開始年月を使用
            savingsStartYear = startYear
            savingsStartMonth = startMonth
        } else {
            // 定義の作成日から計算
            let createdDate = definition.createdAt
            savingsStartYear = Calendar.current.component(.year, from: createdDate)
            savingsStartMonth = Calendar.current.component(.month, from: createdDate)
        }

        let monthsElapsed = calculateMonthsElapsed(
            fromYear: savingsStartYear,
            fromMonth: savingsStartMonth,
            toYear: year,
            toMonth: month,
        )

        // 月次積立額 × 経過月数を累計積立額とする
        let monthlySaving = definition.monthlySavingAmount
        let totalSaved = monthlySaving.safeMultiply(Decimal(monthsElapsed))

        // 残高を更新
        balance.totalSavedAmount = totalSaved
        balance.totalPaidAmount = totalPaid
        balance.lastUpdatedYear = year
        balance.lastUpdatedMonth = month
        balance.updatedAt = Date()
        let snapshot = BalanceSnapshot(
            totalSavedAmount: totalSaved,
            totalPaidAmount: totalPaid,
            lastUpdatedYear: year,
            lastUpdatedMonth: month,
        )
        cache.store(snapshot: snapshot, for: cacheKey)
    }

    // MARK: - Helper Methods

    private func calculateMonthsElapsed(
        fromYear: Int,
        fromMonth: Int,
        toYear: Int,
        toMonth: Int,
    ) -> Int {
        let fromIndex = (fromYear * 12) + (fromMonth - 1)
        let toIndex = (toYear * 12) + (toMonth - 1)
        return max(0, toIndex - fromIndex + 1)
    }
}

// MARK: - Cache Support

internal struct SpecialPaymentBalanceCacheMetrics: Sendable {
    internal let hits: Int
    internal let misses: Int
    internal let invalidations: Int
}

internal struct BalanceCacheKey: Hashable {
    internal let definitionId: UUID
    internal let balanceId: UUID
    internal let year: Int
    internal let month: Int
    internal let startYear: Int?
    internal let startMonth: Int?
    internal let definitionVersion: Int
    internal let balanceVersion: Int
}

internal struct BalanceSnapshot: Sendable {
    internal let totalSavedAmount: Decimal
    internal let totalPaidAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
}

internal final class SpecialPaymentBalanceCache: @unchecked Sendable {
    private struct Metrics {
        var hits: Int = 0
        var misses: Int = 0
        var invalidations: Int = 0
    }

    private let lock: NSLock = NSLock()
    private var snapshots: [BalanceCacheKey: BalanceSnapshot] = [:]
    private var metrics: Metrics = Metrics()

    internal var metricsSnapshot: SpecialPaymentBalanceCacheMetrics {
        lock.withLock {
            SpecialPaymentBalanceCacheMetrics(
                hits: metrics.hits,
                misses: metrics.misses,
                invalidations: metrics.invalidations,
            )
        }
    }

    internal func snapshot(for key: BalanceCacheKey) -> BalanceSnapshot? {
        lock.withLock {
            if let value = snapshots[key] {
                metrics.hits += 1
                return value
            }
            metrics.misses += 1
            return nil
        }
    }

    internal func store(snapshot: BalanceSnapshot, for key: BalanceCacheKey) {
        lock.withLock {
            snapshots[key] = snapshot
        }
    }

    internal func invalidate(balanceId: UUID?) {
        lock.withLock {
            if let balanceId {
                snapshots = snapshots.filter { $0.key.balanceId != balanceId }
            } else {
                snapshots.removeAll()
            }
            metrics.invalidations += 1
        }
    }
}

private func apply(snapshot: BalanceSnapshot, to balance: SpecialPaymentSavingBalance) {
    balance.totalSavedAmount = snapshot.totalSavedAmount
    balance.totalPaidAmount = snapshot.totalPaidAmount
    balance.lastUpdatedYear = snapshot.lastUpdatedYear
    balance.lastUpdatedMonth = snapshot.lastUpdatedMonth
    balance.updatedAt = Date()
}

private func definitionVersion(for definition: SpecialPaymentDefinition) -> Int {
    var hasher = Hasher()
    hasher.combine(definition.id)
    hasher.combine(definition.updatedAt.timeIntervalSinceReferenceDate)
    hasher.combine(definition.occurrences.count)
    if let latest = definition.occurrences.map(\.updatedAt).max() {
        hasher.combine(latest.timeIntervalSinceReferenceDate)
    }
    return hasher.finalize()
}

private func balanceVersion(for balance: SpecialPaymentSavingBalance) -> Int {
    var hasher = Hasher()
    hasher.combine(balance.id)
    return hasher.finalize()
}

private extension NSLock {
    func withLock<T>(_ execute: () -> T) -> T {
        lock()
        defer { unlock() }
        return execute()
    }
}
