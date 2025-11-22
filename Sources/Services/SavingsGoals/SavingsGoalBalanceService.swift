import Foundation
import os.lock
import SwiftData

// MARK: - SavingsGoalBalanceService

/// 貯蓄目標の残高管理サービス
///
/// 月次積立の記録、引出処理、残高の再計算を行います。
internal struct SavingsGoalBalanceService: Sendable {
    private let cache: SavingsGoalBalanceCache

    internal init(cache: SavingsGoalBalanceCache = SavingsGoalBalanceCache()) {
        self.cache = cache
    }

    internal func cacheMetrics() -> SavingsGoalBalanceCacheMetrics {
        cache.metricsSnapshot
    }

    internal func invalidateCache(for balanceId: UUID? = nil) {
        cache.invalidate(balanceId: balanceId)
    }

    /// 月次積立記録パラメータ
    internal struct MonthlySavingsParameters {
        internal let goal: SwiftDataSavingsGoal
        internal let balance: SwiftDataSavingsGoalBalance?
        internal let year: Int
        internal let month: Int
    }

    /// 月次積立を記録
    /// - Parameter params: 月次積立記録パラメータ
    /// - Returns: 更新または新規作成された残高（新規の場合は呼び出し側で挿入すること）
    @discardableResult
    internal func recordMonthlySavings(params: MonthlySavingsParameters) -> SwiftDataSavingsGoalBalance {
        let goal = params.goal
        let balance = params.balance
        let year = params.year
        let month = params.month
        let monthlySaving = goal.monthlySavingAmount

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
            let newBalance = SwiftDataSavingsGoalBalance(
                goal: goal,
                totalSavedAmount: monthlySaving,
                totalWithdrawnAmount: 0,
                lastUpdatedYear: year,
                lastUpdatedMonth: month,
            )
            cache.invalidate(balanceId: newBalance.id)
            return newBalance
        }
    }

    /// 引出処理を反映
    /// - Parameters:
    ///   - withdrawal: 引出記録
    ///   - balance: 積立残高
    /// - Returns: 引出後の残高
    @discardableResult
    internal func processWithdrawal(
        withdrawal: SwiftDataSavingsGoalWithdrawal,
        balance: SwiftDataSavingsGoalBalance,
    ) -> Decimal {
        let amount = withdrawal.amount

        // 残高から引出額を差し引く
        balance.totalWithdrawnAmount = balance.totalWithdrawnAmount.safeAdd(amount)
        balance.updatedAt = Date()
        cache.invalidate(balanceId: balance.id)

        // 引出後の残高を返す
        return balance.balance
    }

    /// 残高再計算パラメータ
    internal struct RecalculateBalanceParameters {
        internal let goal: SwiftDataSavingsGoal
        internal let balance: SwiftDataSavingsGoalBalance
        internal let year: Int
        internal let month: Int
        internal let startYear: Int?
        internal let startMonth: Int?

        internal init(
            goal: SwiftDataSavingsGoal,
            balance: SwiftDataSavingsGoalBalance,
            year: Int,
            month: Int,
            startYear: Int? = nil,
            startMonth: Int? = nil,
        ) {
            self.goal = goal
            self.balance = balance
            self.year = year
            self.month = month
            self.startYear = startYear
            self.startMonth = startMonth
        }
    }

    /// 残高を再計算
    ///
    /// goalの全withdrawalから残高を再計算します。
    /// データ修正時やデバッグ時に使用します。
    /// - Parameter params: 残高再計算パラメータ
    internal func recalculateBalance(params: RecalculateBalanceParameters) {
        let goal = params.goal
        let balance = params.balance
        let year = params.year
        let month = params.month
        let startYear = params.startYear
        let startMonth = params.startMonth
        let cacheKey = SavingsGoalBalanceCacheKey(
            goalId: goal.id,
            balanceId: balance.id,
            year: year,
            month: month,
            startYear: startYear,
            startMonth: startMonth,
            goalVersion: goalVersion(for: goal),
            balanceVersion: balanceVersion(for: balance),
        )
        if let snapshot = cache.snapshot(for: cacheKey) {
            apply(snapshot: snapshot, to: balance)
            return
        }

        // 全引出額を計算
        let totalWithdrawn = goal.withdrawals.reduce(Decimal(0)) { sum, withdrawal in
            sum.safeAdd(withdrawal.amount)
        }

        // 積立開始年月を決定
        let savingsStartYear: Int
        let savingsStartMonth: Int

        if let startYear, let startMonth {
            // 明示的に指定された開始年月を使用
            savingsStartYear = startYear
            savingsStartMonth = startMonth
        } else {
            // 貯蓄目標の開始日から計算
            let startDate = goal.startDate
            savingsStartYear = Calendar.current.component(.year, from: startDate)
            savingsStartMonth = Calendar.current.component(.month, from: startDate)
        }

        let monthsElapsed = calculateMonthsElapsed(
            fromYear: savingsStartYear,
            fromMonth: savingsStartMonth,
            toYear: year,
            toMonth: month,
        )

        // 月次積立額 × 経過月数を累計積立額とする
        let monthlySaving = goal.monthlySavingAmount
        let totalSaved = monthlySaving.safeMultiply(Decimal(monthsElapsed))

        // 残高を更新
        balance.totalSavedAmount = totalSaved
        balance.totalWithdrawnAmount = totalWithdrawn
        balance.lastUpdatedYear = year
        balance.lastUpdatedMonth = month
        balance.updatedAt = Date()
        let snapshot = SavingsGoalBalanceSnapshot(
            totalSavedAmount: totalSaved,
            totalWithdrawnAmount: totalWithdrawn,
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

internal struct SavingsGoalBalanceCacheMetrics: Sendable {
    internal let hits: Int
    internal let misses: Int
    internal let invalidations: Int
}

internal struct SavingsGoalBalanceCacheKey: Hashable {
    internal let goalId: UUID
    internal let balanceId: UUID
    internal let year: Int
    internal let month: Int
    internal let startYear: Int?
    internal let startMonth: Int?
    internal let goalVersion: Int
    internal let balanceVersion: Int
}

internal struct SavingsGoalBalanceSnapshot: Sendable {
    internal let totalSavedAmount: Decimal
    internal let totalWithdrawnAmount: Decimal
    internal let lastUpdatedYear: Int
    internal let lastUpdatedMonth: Int
}

internal final class SavingsGoalBalanceCache: Sendable {
    private struct Metrics {
        var hits: Int = 0
        var misses: Int = 0
        var invalidations: Int = 0
    }

    private struct Storage {
        var snapshots: [SavingsGoalBalanceCacheKey: SavingsGoalBalanceSnapshot] = [:]
        var metrics: Metrics = Metrics()
    }

    private let storage: OSAllocatedUnfairLock<Storage> = OSAllocatedUnfairLock(
        initialState: Storage(),
    )

    internal var metricsSnapshot: SavingsGoalBalanceCacheMetrics {
        storage.withLock { storage in
            SavingsGoalBalanceCacheMetrics(
                hits: storage.metrics.hits,
                misses: storage.metrics.misses,
                invalidations: storage.metrics.invalidations,
            )
        }
    }

    internal func snapshot(for key: SavingsGoalBalanceCacheKey) -> SavingsGoalBalanceSnapshot? {
        storage.withLock { storage in
            if let value = storage.snapshots[key] {
                storage.metrics.hits += 1
                return value
            }
            storage.metrics.misses += 1
            return nil
        }
    }

    internal func store(snapshot: SavingsGoalBalanceSnapshot, for key: SavingsGoalBalanceCacheKey) {
        storage.withLock { storage in
            storage.snapshots[key] = snapshot
        }
    }

    internal func invalidate(balanceId: UUID?) {
        storage.withLock { storage in
            if let balanceId {
                storage.snapshots = storage.snapshots.filter { $0.key.balanceId != balanceId }
            } else {
                storage.snapshots.removeAll()
            }
            storage.metrics.invalidations += 1
        }
    }
}

private func apply(snapshot: SavingsGoalBalanceSnapshot, to balance: SwiftDataSavingsGoalBalance) {
    balance.totalSavedAmount = snapshot.totalSavedAmount
    balance.totalWithdrawnAmount = snapshot.totalWithdrawnAmount
    balance.lastUpdatedYear = snapshot.lastUpdatedYear
    balance.lastUpdatedMonth = snapshot.lastUpdatedMonth
    balance.updatedAt = Date()
}

private func goalVersion(for goal: SwiftDataSavingsGoal) -> Int {
    var hasher = Hasher()
    hasher.combine(goal.id)
    hasher.combine(goal.updatedAt.timeIntervalSinceReferenceDate)
    hasher.combine(goal.withdrawals.count)
    if let latest = goal.withdrawals.map(\.updatedAt).max() {
        hasher.combine(latest.timeIntervalSinceReferenceDate)
    }
    return hasher.finalize()
}

private func balanceVersion(for balance: SwiftDataSavingsGoalBalance) -> Int {
    var hasher = Hasher()
    hasher.combine(balance.id)
    return hasher.finalize()
}
