# Repository Observation

Repository 層で SwiftData の変更を監視し、Store にプッシュ通知するための仕組み。

## コンポーネント

- `ObservationHandle`
  - 監視のライフサイクルを管理するキャンセル用トークン。
  - Store 側では `@ObservationIgnored` で保持し、不要になれば `cancel()` を呼び出す。
- `ModelContext.observe(descriptor:transform:onChange:)`
  - `ModelContainer` から専用の `ModelObservationWorker` actor を生成し、監視対象の `ModelContext` を actor 外へ持ち出さずに `NSManagedObjectContextDidSave` 通知を待ち受ける。
  - 監視開始時に必ず最新スナップショットを 1 度配送し、その後は `NSManagedObjectContextDidSave` をフックして `FetchDescriptor` を再評価したデータを `@Sendable` 変換クロージャ経由で `onChange` へ渡す。
  - コールバックは任意のアクタで実行でき、UI へ届ける場合は `observeOnMainActor(_:transform:onChange:)` を利用して MainActor へ橋渡しする。

## 利用例

```swift
transactionsHandle = try listUseCase.observeTransactions(filter: filter) { [weak self] snapshot in
    Task { @MainActor [weak self] in
        self?.transactions = snapshot
    }
}
```

## Concurrency モデル

- Store 自体は `@MainActor` で保護せず、`refresh()` や `reload...()` のような重い処理は `Task.detached` / `ModelActor` 上で実行する。
- フェッチ結果を Store の公開プロパティへ反映するときのみ `await MainActor.run { ... }` もしくは `@MainActor` メソッドからまとめて更新し、UI スレッドの負荷を最小化する。
- SwiftData の監視結果は `ModelContext.observe` で DTO に変換したのち、UI で利用したい場合に限り `observeOnMainActor` を通じて MainActor に橋渡しする。
- Store メソッドは MainActor 以外のアクタから安全に呼び出せることをテストで保証し、UI 側は `Task { await store.refresh() }` のように自由に呼べる。

## 初期スナップショット

- Repository は監視開始と同時に現在のスナップショットを即時配送するため、UseCase / Store で初回フェッチ用の別 Task を走らせる必要はない。
- 取引一覧では `DefaultTransactionListUseCase.observeTransactions` が監視登録のみを行い、各スナップショットを Filter 関数で加工して Store へ橋渡しする。

## メモリ管理

- Store で監視を開始するたびに既存トークンを `cancel()` してから新しいトークンを保持する。
- Store の `deinit` でも `cancel()` しておくとライフサイクル外で通知が飛ぶことを防げる。
