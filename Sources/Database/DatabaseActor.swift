import Foundation
import SwiftData

/// グローバルアクター：データベース操作の分離
///
/// SwiftDataのModelContextはSendableではないため、
/// データベース操作を専用のグローバルアクターで隔離します。
/// UIスレッド（MainActor）をブロックせず、
/// 書込操作の直列化によりOverwrite問題を防ぎます。
@globalActor
public actor DatabaseActor {
    /// 共有インスタンス
    public static let shared: DatabaseActor = DatabaseActor()

    private var access: DatabaseAccess?

    /// ModelContainer をセットアップして DatabaseAccess を構築
    public func configure(modelContainer: ModelContainer) {
        access = DatabaseAccess(container: modelContainer)
    }

    /// 既に構成済みでなければセットアップ
    public func configureIfNeeded(modelContainer: ModelContainer) {
        guard access == nil else { return }
        configure(modelContainer: modelContainer)
    }

    /// 現在の DatabaseAccess を取得
    internal func databaseAccess() -> DatabaseAccess {
        guard let access else {
            preconditionFailure("DatabaseAccess is not configured. Call configure(modelContainer:) first.")
        }
        return access
    }

    #if DEBUG
    /// テスト用に Access をリセット
    public func resetConfigurationForTesting() {
        access = nil
    }
    #endif
}
