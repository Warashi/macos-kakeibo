# Runtime Overview

ModelActor への移行計画は `docs/architecture/model-actor-migration.md` を参照。

## Store / UseCase / Service 依存関係

```
View ──binds──> Store (@Observable)
   │              │
   │              ├─uses──> UseCase (MonthlyBudget / AnnualBudget / SpecialPaymentSavings)
   │              │            │
   │              │            └─calls──> Services (TransactionAggregator, BudgetCalculator, AnnualBudgetAllocator,
   │              │                         SpecialPaymentBalanceService)
   │              │
   │              └─mutates──> BudgetRepository (SwiftData)
   │
   └─refresh──> ModelContext snapshots (BudgetSnapshot, etc.)
```

- **Stores** は ModelContext から `BudgetSnapshot` などを構築し、 UseCase へ引き渡す役割に専念します。BudgetStore のナビゲーション/表示モード制御は `Sources/Stores/Support/` の `BudgetNavigationState` / `BudgetDisplayModeTraits` へ切り出しています。
- **UseCase** はビューが必要とする形 (`MonthlyBudgetEntry`, `SpecialPaymentSavingsEntry` など) へデータを整形し、計算サービスの差し替えポイントになります。これらのDTOは `Sources/Presenters/Budgets/` 配下で共有され、複数画面から再利用できます。
- **Services** 層では `BudgetCalculator` と `SpecialPaymentBalanceService` が計算とキャッシュ制御を担当し、`TransactionAggregator` や `AnnualBudgetAllocator` を再利用しています。

### 初期化ヘルパー

- 取引スタックは `TransactionStackBuilder` で Repository / UseCase をまとめて生成し、`TransactionListView` などの SwiftUI View はこのビルダー経由で `TransactionStore` を準備します。`@ModelActor` 化時はビルダー内の初期化コードのみ差し替えればよく、View/Store の変更を最小限に抑えられます。
- 予算スタックは `BudgetStackBuilder` で `BudgetStore` の依存（Repository / Monthly & Annual / RecurringPayment UseCase / Mutation UseCase）を一元化し、`BudgetView` からはビルダーを呼び出すだけで済むようにしています。ModelActor へ切り替える際はこのビルダーで Repository の実装を差し替えます。
- 定期支払いスタックは `RecurringPaymentStackBuilder` が一覧・突合ストア向けの Repository / Service を構築し、`RecurringPaymentListView` や `RecurringPaymentReconciliationView` からの依存注入を一本化しています。SwiftData -> ModelActor の切り替えもこのビルダー差し替えで完結します。
- 設定/CSV インポート画面は `SettingsStackBuilder` で `SettingsStore` / `ImportStore` の依存をまとめて用意し、共通の Repository セットを再利用します。`SettingsView` や `CSVImportView` ではビルダーを呼ぶだけでよく、View 側での明示的な Task/actor 指定を排除しています。

## 計算チェーンとキャッシュ

```
Transactions ─┐
              ├─> TransactionAggregator ─> BudgetCalculator (monthly budgets cache)
Budgets    ───┘                                     │
                                                   ├─> AnnualBudgetAllocator (category allocation)
SpecialPaymentDefinitions ─┐                       │
SpecialPaymentBalances  ───┴─> BudgetCalculator (special payment caches)

SpecialPaymentDefinition + Balance ─> SpecialPaymentBalanceService (recalc cache)
```

- 月次予算と特別支払い積立は `BudgetCalculator` 内部の `BudgetCalculationCache` でハッシュキー管理。
  - キー要素: 年月 / AggregationFilter / 除外カテゴリ / Transactions & Budgets の `(id, updatedAt)` ハッシュ。
  - `BudgetCalculatorCacheTests` でヒット/ミスが計測できるよう `cacheMetrics()` を公開。
- `SpecialPaymentBalanceService` は再計算スナップショットを `SpecialPaymentBalanceCache` に保存し、`recordMonthlySavings` や `processPayment` 経由で無効化。
  - キー要素: 定義ID、残高ID、再計算対象年月、開始年月、`definition.updatedAt`、Occurrence の最新更新、`balance.updatedAt`。

## テスト/検証戦略（抜粋）

| 層 | テストスイート | 目的 |
| --- | --- | --- |
| Services/Calculations | `BudgetCalculatorBasicTests`, `BudgetCalculatorSpecialPaymentTests`, `BudgetCalculatorCacheTests` | 予算計算ロジックとキャッシュミス/ヒット挙動の検証 |
| Services/SpecialPayments | `PaymentBalance*Tests`, `SpecialPaymentBalanceCacheTests` | 残高計算、積立、再計算キャッシュの整合性 |
| Stores/UseCases | `BudgetStoreTests*`, `DashboardStoreTests` | スナップショット再生成と UseCase 連携 |
| Integration | `SpecialPaymentSavings*Tests` | 特別支払いの月次配分と残高反映の統合パス |

- すべてのテストは `ModelContainer.createInMemoryContainer()` で SwiftData をメモリ化し、副作用を隔離。
- キャッシュテストでは `cacheMetrics()` / `cache.invalidate…()` を通じてヒット率・無効化経路を直接 assert し、パフォーマンス回帰を防止します。
