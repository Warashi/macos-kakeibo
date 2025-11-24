import Foundation

/// 貯蓄目標一覧の表示用エントリ
internal struct SavingsGoalListEntry: Identifiable, Sendable {
    internal let goal: SavingsGoal
    internal let balance: SavingsGoalBalance?

    internal var id: UUID { goal.id }

    /// 進捗率の計算
    internal var progress: Double? {
        guard let targetAmount = goal.targetAmount,
              let balance,
              targetAmount > 0 else { return nil }
        let current = NSDecimalNumber(decimal: balance.balance).doubleValue
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(1.0, current / target)
    }
}
