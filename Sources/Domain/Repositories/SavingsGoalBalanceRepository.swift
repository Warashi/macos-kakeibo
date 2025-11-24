import Foundation

internal protocol SavingsGoalBalanceRepository: Sendable {
    /// 指定されたgoalIdの残高を取得
    /// - Parameter goalId: 貯蓄目標のID
    /// - Returns: 残高（存在しない場合はnil）
    func fetchBalance(forGoalId goalId: UUID) async throws -> SavingsGoalBalance?

    /// すべての残高を取得
    /// - Returns: 残高の配列
    func fetchAllBalances() async throws -> [SavingsGoalBalance]

    /// 残高の変更を監視
    /// - Parameter onChange: 変更時に呼び出されるハンドラ
    /// - Returns: 監視を停止するためのハンドル
    @discardableResult
    func observeBalances(
        onChange: @escaping @Sendable ([SavingsGoalBalance]) -> Void
    ) async throws -> ObservationHandle
}
