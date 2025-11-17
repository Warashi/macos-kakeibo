import Foundation
import SwiftData

/// SwiftData へのアクセスをスケジューリングするためのプロトコル
///
/// - `executeRead` / `executeWrite` は ModelContext を受け取り、呼び出し元のクロージャを実行する。
/// - AccessScheduler だけでなく、将来的に `@ModelActor` ベースの実装へ差し替える際にも同じ API を利用できるようにする。
internal protocol DatabaseScheduling: Sendable {
    func executeRead<T: Sendable>(
        block: @escaping @Sendable (ModelContext) throws -> T
    ) async rethrows -> T

    @discardableResult
    func executeWrite<T: Sendable>(
        block: @escaping @Sendable (ModelContext) throws -> T
    ) async rethrows -> T
}
