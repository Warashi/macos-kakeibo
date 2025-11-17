import Foundation

/// リポジトリ層のエラー
internal enum RepositoryError: Error {
    /// リソースが見つかりません
    case notFound
}
