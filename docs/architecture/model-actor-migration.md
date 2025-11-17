# ModelActor Migration Plan

SwiftData の `@ModelActor` を採用するための移行方針と、層ごとの責務を守るためのサポートコードを整理する。

## 目的

- `DatabaseActor` / `AccessScheduler` / `DatabaseAccess` による直列書込 + 並列読取の仕組みを、`@ModelActor` ベースの serial executor へ置換してもアプリ全体の責務境界を壊さないようにする。
- Domain / UseCase / Store / Infrastructure を Onion Architecture で維持し、新しい Repository や DTO を追加しても SwiftData 依存が内側の層へ漏れないようにする。
- ドキュメントとテストで移行手順を明文化し、Pull Request レビュー時に ModelActor 方針がブレないようガードする。

## 層ごとの責務

| 層 | 役割 | ModelActor への影響 |
| --- | --- | --- |
| Domain (`Sources/Domain`) | モデル/値オブジェクト/Repository プロトコルを定義。Infrastructure 以外から SwiftData を見せない。 | `@ModelActor` へ切り替えても API は純粋な Swift 型のまま。Domain では `import SwiftData` や `ModelContext` への参照を禁止。 |
| UseCases / Stores / Presenters | View と Repository の仲立ち。`Task { @DatabaseActor ... }` の呼び出し点を最小化し、将来的に `Task { @ModelActor ... }` へ置換する。 | Store には「actor 境界を超えるのは UseCase 経由のみ」というルールを守る。 |
| Infrastructure (`Sources/Infrastructure/Persistence`) | SwiftData の Model/Mapper/Repository 実装を保持。 | `@ModelActor` による `isolated ModelContext` を内部に隠蔽し、Domain 型に変換して返す。 |
| Utilities (`Sources/Utilities/Queries`, `Observation`, `Environment`) | FetchDescriptor ビルダー、`ObservationToken`, `appModelContainer` を提供。 | Query/Observation API はそのまま再利用し、ModelActor 化では ModelContext を差し替えるのみ。 |

## 移行フェーズ

1. **Isolation**（完了）
   - Repository プロトコルへ `@DatabaseActor` 属性を付与し、SwiftData モデルは Infrastructure に閉じ込める。
   - `TransactionStackBuilder` など Store 構築のビルダーを用意し、View からの依存生成を一元化する。
2. **Bootstrap**
   - `DatabaseActor` を `ModelContainer` から初期化する経路を統一し、`DatabaseScheduling` 準拠の AccessScheduler で直列 executor を管理。
   - `Task { @DatabaseActor in ... }` の呼び出し箇所を洗い出しておく（`rg "@DatabaseActor"`）。
3. **Adoption**
   - `@DatabaseActor` 属性を `@ModelActor` へ置換し、Repository 実装を `isolated ModelContext` で再構成。
   - Store/View 側はビルダー経由で actor を初期化するだけで差分を吸収できる。Observation や Query は変更不要。

## サポートコード

- `DatabaseScheduling` (`Sources/Database/DatabaseScheduling.swift`) を境界インターフェースとして導入。AccessScheduler もこのプロトコルに準拠しており、将来的に `@ModelActor` ベースの executor を差し込む際は同じ API を実装するだけでよい。
- `Tests/Utilities/Architecture/ModelActorIsolationTests.swift` で Domain / UseCase 層が `import SwiftData` や `ModelContext` を参照していないことを自動検査。ModelActor 化の前提条件をテストで担保する。
- `docs/architecture/fetch-queries.md` / `repository-observation.md` / 本ドキュメントを合わせて読み、クエリと監視の共通 API を経由するルールを確認する。
- View で Repository/UseCase を直接生成しない。`TransactionStackBuilder` のようなビルダーにまとめ、将来の actor 差し替えポイントを限定する。

## スタック別の移行メモ

### 取引スタック

- **初期化経路**: `TransactionListView.prepareStore()` が `TransactionStackBuilder.makeStore(modelContainer:)` を呼び、`SwiftDataTransactionRepository` / `DefaultTransactionListUseCase` / `DefaultTransactionFormUseCase` をまとめて生成している。`@ModelActor` 化ではこのビルダーを actor 版の repository / use case に差し替えればよく、View / Store には差分が波及しない。
- **UseCase/API**: `TransactionListUseCase` / `TransactionFormUseCase` は `@DatabaseActor` 属性が付いた純粋 Swift API で、Store との境界条件が明確。`observeTransactions` は `ObservationToken` で MainActor へ橋渡ししているため、ModelActor 版でもライフサイクル管理を再利用できる。
- **二次利用ポイント**: `SettingsStackBuilder` や `RecurringPaymentStackBuilder`（突合ストア用）が同じ `SwiftDataTransactionRepository` を生成している。将来的には Transaction 用の `@ModelActor` を 1 箇所で生成し、各ビルダーから共有できるよう factory を束ねる必要がある。
- **View / Store 側の Task**: `TransactionListView` は `Task { await TransactionStackBuilder.makeStore(...) }` で非同期初期化するのみで `@DatabaseActor` を直接指定していない。ModelActor へ切り替えても Task 呼び出しを書き換える必要はない。
- **テストカバレッジ**: `TransactionStackBuilderTests` / `TransactionStoreTests` / `TransactionListViewTests` が In-Memory Container を使った初期化と UI レベルの動作を確認している。ModelActor 導入時はこれらを `TransactionModelActorStackBuilder` へ向け直すことで回帰を検知できる。

### 予算 / 定期支払いスタック

- **初期化経路**: `BudgetStackBuilder` と `RecurringPaymentStackBuilder` がそれぞれ `BudgetView` / `RecurringPaymentListView` / `RecurringPaymentReconciliationView` から呼ばれ、SwiftData Repository と UseCase / Service（`DefaultMonthlyBudgetUseCase`, `DefaultRecurringPaymentSavingsUseCase`, `RecurringPaymentOccurrencesService` など）をまとめて生成している。ModelActor 化ではこれらのビルダーを差し替えることで、複数画面の初期化コードを同時に移行できる。
- **View からの直接操作**: `BudgetView` の定期支払い CRUD ハンドラは `Task { @DatabaseActor in ... }` 内で `RecurringPaymentStackBuilder.makeStore` を呼び出し、`RecurringPaymentStore` を一時的に構築して操作している。ModelActor 移行時はここが `Task { @ModelActor in ... }` への書き換えポイントになるため、Budget/RecurringPayment actor を共通 DI できる API を準備する。
- **Recurrence/Service 層**: `RecurringPaymentStore` / `BudgetStore` は Repository 経由でのみ永続化しており、`RecurringPaymentRepository` や `BudgetRepository` の差し替えだけで動作が完結する。`BudgetCalculator` や `RecurringPaymentScheduleService` は純粋 Swift なので actor 隔離の影響を受けない。
- **二次利用ポイント**: `SettingsStore.deleteAllData()` や `DashboardStackBuilder` からも `BudgetRepository` / `RecurringPaymentRepository` が利用される。ModelActor 版では該当 actor の初期化が単一箇所にまとまるよう、StackBuilder のファクトリを経由させる。
- **テストカバレッジ**: `BudgetStackBuilderTests` / `RecurringPaymentStackBuilderTests` / `BudgetStoreTests*` / `RecurringPaymentStore*Tests` / `RecurringPaymentReconciliationStoreTests` などが層ごとの差分検証を担っている。ModelActor 化では新しい StackBuilder を使ったテストケースを追加することで移行の安全性を担保する。

## レビュー/追加時のチェックリスト

1. 新しい Domain ファイルが `SwiftData` / `SwiftUI` / `ModelContext` を import していないか。
2. Infrastructure の SwiftData コードは `Sources/Infrastructure/Persistence` から外へ漏れていないか。
3. View/Store で `ModelContainer` を扱う場合はビルダー経由になっているか。
4. Repository の追加/変更時は `@DatabaseActor` 属性を付けたまま、UseCase/Store 経由でのみ呼び出しているか。
5. クエリ生成や監視処理は `Sources/Utilities/Queries` / `Sources/Utilities/Observation` を通じているか。

これらを満たしていれば、`@ModelActor` への置換は Database 層の実装差分に閉じ込められ、他レイヤーの変更を最小化できる。
