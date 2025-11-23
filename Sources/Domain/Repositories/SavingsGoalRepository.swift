import Foundation

internal protocol SavingsGoalRepository: Sendable {
    /// 貯蓄目標を作成
    /// - Parameter input: 貯蓄目標の入力パラメータ
    /// - Returns: 作成された貯蓄目標
    func createGoal(_ input: SavingsGoalInput) async throws -> SavingsGoal

    /// 貯蓄目標を更新
    /// - Parameter input: 貯蓄目標の更新パラメータ
    /// - Returns: 更新された貯蓄目標
    func updateGoal(_ input: SavingsGoalUpdateInput) async throws -> SavingsGoal

    /// 貯蓄目標を削除
    /// - Parameter id: 削除する貯蓄目標のID
    func deleteGoal(_ id: UUID) async throws

    /// すべての貯蓄目標を取得
    /// - Returns: 貯蓄目標の配列
    func fetchAllGoals() async throws -> [SavingsGoal]

    /// 指定されたIDの貯蓄目標を取得
    /// - Parameter id: 貯蓄目標のID
    /// - Returns: 貯蓄目標（存在しない場合はnil）
    func fetchGoal(id: UUID) async throws -> SavingsGoal?

    /// 貯蓄目標の有効/無効を切り替え
    /// - Parameter id: 貯蓄目標のID
    func toggleGoalActive(_ id: UUID) async throws

    /// 貯蓄目標の変更を監視
    /// - Parameter onChange: 変更時に呼び出されるハンドラ
    /// - Returns: 監視を停止するためのハンドル
    @discardableResult
    func observeGoals(
        onChange: @escaping @Sendable ([SavingsGoal]) -> Void
    ) async throws -> ObservationHandle

    /// 変更を保存
    func saveChanges() async throws
}
