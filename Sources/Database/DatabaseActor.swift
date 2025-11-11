import Foundation

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
}
