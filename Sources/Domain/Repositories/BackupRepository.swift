import Foundation

/// バックアップとリストアのためのリポジトリ
internal protocol BackupRepository: Sendable {
    /// 全エンティティをバックアップ用にフェッチ
    /// - Returns: 全エンティティのDTO
    func fetchAllEntities() async throws -> BackupEntitiesData

    /// 全データをクリア
    func clearAllData() async throws

    /// エンティティを復元
    /// - Parameter data: 復元するエンティティデータ
    func restoreEntities(_ data: BackupEntitiesData) async throws
}
