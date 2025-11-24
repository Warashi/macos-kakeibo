import Foundation

internal protocol SavingsGoalWithdrawalRepository: Sendable {
    /// 引出記録を作成
    /// - Parameter input: 引出記録の入力パラメータ
    /// - Returns: 作成された引出記録
    func createWithdrawal(_ input: SavingsGoalWithdrawalInput) async throws -> SavingsGoalWithdrawal

    /// 指定されたgoalIdの引出記録を取得
    /// - Parameter goalId: 貯蓄目標のID
    /// - Returns: 引出記録の配列
    func fetchWithdrawals(forGoalId goalId: UUID) async throws -> [SavingsGoalWithdrawal]

    /// すべての引出記録を取得
    /// - Returns: 引出記録の配列
    func fetchAllWithdrawals() async throws -> [SavingsGoalWithdrawal]

    /// 引出記録を削除
    /// - Parameter id: 削除する引出記録のID
    func deleteWithdrawal(_ id: UUID) async throws

    /// 引出記録の変更を監視
    /// - Parameter onChange: 変更時に呼び出されるハンドラ
    /// - Returns: 監視を停止するためのハンドル
    @discardableResult
    func observeWithdrawals(
        onChange: @escaping @Sendable ([SavingsGoalWithdrawal]) -> Void,
    ) async throws -> ObservationHandle
}
