# Repository Observation

Repository 層で SwiftData の変更を監視し、Store にプッシュ通知するための仕組み。

## コンポーネント

- `ObservationToken`
  - 監視のライフサイクルを管理するキャンセル用トークン。
  - Store 側では `@ObservationIgnored` で保持し、不要になれば `cancel()` を呼び出す。
- `ModelContext.observe(descriptor:transform:onChange:)`
  - `NSManagedObjectContextDidSave` をフックし、指定した `FetchDescriptor` を再評価した後に DTO へ変換してから `onChange` へ渡す。
  - コールバックは任意のアクタで実行でき、UI へ届ける場合は `observeOnMainActor(_:transform:onChange:)` を利用して MainActor へ橋渡しする。

## 利用例

```swift
transactionsToken = try listUseCase.observeTransactions(filter: filter) { [weak self] snapshot in
    Task { @MainActor [weak self] in
        self?.transactions = snapshot
    }
}
```

## メモリ管理

- Store で監視を開始するたびに既存トークンを `cancel()` してから新しいトークンを保持する。
- Store の `deinit` でも `cancel()` しておくとライフサイクル外で通知が飛ぶことを防げる。
