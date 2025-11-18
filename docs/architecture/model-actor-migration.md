# ModelActor Migration Plan

SwiftData の `@ModelActor` を採用するための移行方針と、層ごとの責務を守るためのサポートコードを整理する。

## 目的

- Repository へのアクセスは `@ModelActor` ベースの実装に統一し、従来の `DatabaseActor` / `AccessScheduler` / `DatabaseAccess` を撤廃してもアプリ全体の責務境界を壊さないようにする。
- Domain / UseCase / Store / Infrastructure を Onion Architecture で維持し、新しい Repository や DTO を追加しても SwiftData 依存が内側の層へ漏れないようにする。
- ドキュメントとテストで移行手順を明文化し、Pull Request レビュー時に ModelActor 方針がブレないようガードする。

## 層ごとの責務

| 層 | 役割 | ModelActor への影響 |
| --- | --- | --- |
| Domain (`Sources/Domain`) | モデル/値オブジェクト/Repository プロトコルを定義。Infrastructure 以外から SwiftData を見せない。 | `@ModelActor` へ切り替えても API は純粋な Swift 型のまま。Domain では `import SwiftData` や `ModelContext` への参照を禁止。 |
| UseCases / Stores / Presenters | View と Repository の仲立ち。Store は純粋な Swift API (`Sendable` な UseCase/Service) を await するだけでよい。 | Store には「actor 境界を超えるのは UseCase 経由のみ」というルールを守り、Repository 呼び出しはすべて async/await で直に表現する。 |
| Infrastructure (`Sources/Infrastructure/Persistence`) | SwiftData の Model/Mapper/Repository 実装を保持。 | `@ModelActor` による `isolated ModelContext` を内部に隠蔽し、Domain 型に変換して返す。 |
| Utilities (`Sources/Utilities/Queries`, `Observation`, `Environment`) | FetchDescriptor ビルダー、`ObservationToken`, `appModelContainer` を提供。 | Query/Observation API はそのまま再利用し、ModelActor 化では ModelContext を差し替えるのみ。 |

## 移行フェーズ

1. **Isolation**（完了）
   - Repository プロトコルを Domain 層へ閉じ込め、SwiftData への参照を Infrastructure だけに限定する。
   - `TransactionStackBuilder` など Store 構築のビルダーを用意し、View からの依存生成を一元化する。
2. **Bootstrap**（完了）
   - すべての StackBuilder が `ModelContainer` から `@ModelActor` ベースの Repository を初期化するよう整理し、View/Store 側では `await Builder.makeStore(...)` を呼ぶだけでよい状態にする。
   - 旧 `Task { @DatabaseActor ... }` 呼び出しは排除し、actor 隔離の境界を UseCase/Repository だけに限定する。
3. **Adoption**（進行中 / 運用フェーズ）
   - Repository 実装は `@ModelActor` かつ async API で統一され、UseCase/Service/Store は Sendable な純 Swift API を await するだけで済む。
   - Observation や Query は従来どおり共通ユーティリティを経由し、ModelContext の扱いは Infrastructure に閉じ込め続ける。

## サポートコード

- `TransactionStackBuilder` / `BudgetStackBuilder` / `RecurringPaymentStackBuilder` / `SettingsStackBuilder` など、Store 初期化を 1 か所へ集約するビルダーを揃えておく。これにより ModelActor を切り替える際はビルダーの実装だけを変更すればよい。
- `Tests/Utilities/Architecture/ModelActorIsolationTests.swift` で Domain / UseCase 層が `import SwiftData` や `ModelContext` を参照していないことを自動検査。ModelActor 化の前提条件をテストで担保する。
- `docs/architecture/fetch-queries.md` / `repository-observation.md` / 本ドキュメントを合わせて読み、クエリと監視の共通 API を経由するルールを確認する。
- View で Repository/UseCase を直接生成しない。`TransactionStackBuilder` のようなビルダーにまとめ、将来の actor 差し替えポイントを限定する。

## スタック別の移行メモ

### 取引スタック

- **初期化経路**: `TransactionListView.prepareStore()` が `TransactionStackBuilder.makeStore(modelContainer:)` を呼び、`SwiftDataTransactionRepository` / `DefaultTransactionListUseCase` / `DefaultTransactionFormUseCase` をまとめて生成している。`@ModelActor` 化ではこのビルダーを actor 版の repository / use case に差し替えればよく、View / Store には差分が波及しない。
- **UseCase/API**: `TransactionListUseCase` / `TransactionFormUseCase` は `Sendable` な構造体で、Repository の async API を await するだけの純粋 Swift 実装になっている。`observeTransactions` は `ObservationToken` で MainActor へ橋渡ししているため、ModelActor でもライフサイクル管理を再利用できる。
- **二次利用ポイント**: `SettingsStackBuilder` や `RecurringPaymentStackBuilder`（突合ストア用）が同じ `SwiftDataTransactionRepository` を生成している。将来的には Transaction 用の `@ModelActor` を 1 箇所で生成し、各ビルダーから共有できるよう factory を束ねる必要がある。
- **View / Store 側の Task**: `TransactionListView` は `Task { await TransactionStackBuilder.makeStore(...) }` で非同期初期化するのみで actor 名を直接指定していない。ModelActor へ切り替えても Task 呼び出しを書き換える必要はない。
- **テストカバレッジ**: `TransactionStackBuilderTests` / `TransactionStoreTests` / `TransactionListViewTests` が In-Memory Container を使った初期化と UI レベルの動作を確認している。ModelActor 導入時はこれらを `TransactionModelActorStackBuilder` へ向け直すことで回帰を検知できる。

### 予算 / 定期支払いスタック

- **初期化経路**: `BudgetStackBuilder` と `RecurringPaymentStackBuilder` がそれぞれ `BudgetView` / `RecurringPaymentListView` / `RecurringPaymentReconciliationView` から呼ばれ、SwiftData Repository と UseCase / Service（`DefaultMonthlyBudgetUseCase`, `DefaultRecurringPaymentSavingsUseCase`, `RecurringPaymentOccurrencesService` など）をまとめて生成している。ModelActor 化ではこれらのビルダーを差し替えることで、複数画面の初期化コードを同時に移行できる。
- **View からの直接操作**: `BudgetView` の定期支払い CRUD ハンドラは `Task { await RecurringPaymentStackBuilder.makeStore(...) }` で一時的な `RecurringPaymentStore` を構築して操作している。ModelActor でも同じビルダー API を利用するだけでよく、View 側で actor 名を意識する必要はない。
- **Recurrence/Service 層**: `RecurringPaymentStore` / `BudgetStore` は Repository 経由でのみ永続化しており、`RecurringPaymentRepository` や `BudgetRepository` の差し替えだけで動作が完結する。`BudgetCalculator` や `RecurringPaymentScheduleService` は純粋 Swift なので actor 隔離の影響を受けない。
- **二次利用ポイント**: `SettingsStore.deleteAllData()` や `DashboardStackBuilder` からも `BudgetRepository` / `RecurringPaymentRepository` が利用される。ModelActor 版では該当 actor の初期化が単一箇所にまとまるよう、StackBuilder のファクトリを経由させる。
- **テストカバレッジ**: `BudgetStackBuilderTests` / `RecurringPaymentStackBuilderTests` / `BudgetStoreTests*` / `RecurringPaymentStore*Tests` / `RecurringPaymentReconciliationStoreTests` などが層ごとの差分検証を担っている。ModelActor 化では新しい StackBuilder を使ったテストケースを追加することで移行の安全性を担保する。

## レビュー/追加時のチェックリスト

1. 新しい Domain ファイルが `SwiftData` / `SwiftUI` / `ModelContext` を import していないか。
2. Infrastructure の SwiftData コードは `Sources/Infrastructure/Persistence` から外へ漏れていないか。
3. View/Store で `ModelContainer` を扱う場合はビルダー経由になっているか。
4. Repository の追加/変更時は async/await な Domain プロトコルを守り、UseCase/Store 経由でのみ呼び出しているか。
5. クエリ生成や監視処理は `Sources/Utilities/Queries` / `Sources/Utilities/Observation` を通じているか。

これらを満たしていれば、`@ModelActor` への置換は Database 層の実装差分に閉じ込められ、他レイヤーの変更を最小化できる。
