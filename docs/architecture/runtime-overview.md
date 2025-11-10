# Runtime Overview

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

- **Stores** は ModelContext から `BudgetSnapshot` などを構築し、 UseCase へ引き渡す役割に専念します。
- **UseCase** はビューが必要とする形 (`MonthlyBudgetEntry`, `SpecialPaymentSavingsEntry` など) へデータを整形し、計算サービスの差し替えポイントになります。
- **Services** 層では `BudgetCalculator` と `SpecialPaymentBalanceService` が計算とキャッシュ制御を担当し、`TransactionAggregator` や `AnnualBudgetAllocator` を再利用しています。

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
