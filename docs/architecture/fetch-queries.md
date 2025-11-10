# Fetch Query Builders

`FetchDescriptor` の生成と管理を共通化して、Store や Service から重複ロジックを排除しました。  
コードベースでは直接 `FetchDescriptor` を扱わず、以下のユーティリティを経由します。

## 基本コンポーネント

| コンポーネント | 役割 |
| --- | --- |
| `ModelFetchRequest<T>` | `FetchDescriptor<T>` の型エイリアス（唯一の `FetchDescriptor` 参照箇所） |
| `ModelFetchFactory` | predicate / sort / fetchLimit をまとめて設定するファクトリ |
| `TransactionQueries` | 月次リストやID検索など取引専用のビルダー |
| `BudgetQueries` | 予算・年次設定・カテゴリ取得向けビルダー |
| `SpecialPaymentQueries` | 特別支払い定義/Occurrence/残高のビルダー |
| `CategoryQueries` / `FinancialInstitutionQueries` | 共通マスタ向けビルダー |

## 利用ルール

1. **直接 `FetchDescriptor` を生成しない**  
   既存コードの置換例:  
   ```swift
   // 旧: FetchDescriptor<Transaction>(predicate: ..., sortBy: ...)
   let descriptor = TransactionQueries.list(query: query)
   let transactions = try context.fetch(descriptor)
   ```
2. **期間系の取引取得は `TransactionQueries.between`**  
   Dashboard や集計処理は start/end を算出してこのビルダーに渡します。
3. **Budget/SpecialPayment 系は専用ビルダーを利用**  
   - 例: `BudgetQueries.annualConfig(for:)`, `SpecialPaymentQueries.occurrences(predicate:)`
4. **テストでもユーティリティ経由**  
   `context.fetchAll(_:)` またはクエリビルダーを使い、`FetchDescriptor` の生呼び出しを避けます。

## 適用状況

- Stores: `DashboardStore`, `BudgetStore`, `TransactionStore`, `SettingsStore`
- Repositories: Transaction, Budget, SpecialPayment
- Services: CSVImporter resolvers, BackupManager, CustomHolidayProvider
- Views/Dev: `BudgetSpecialPaymentSection`, `SeedHelper`
- Tests: CSVImporter, SeedHelper, SpecialPaymentStore, ImportStore, モデル系テスト

これにより `rg "FetchDescriptor" Sources Tests` の出現数は **1 件**（型エイリアス定義のみ）となり、意図しない手書き定義を事実上禁止できます。追加のクエリが必要な場合は、上記ビルダーへ関数を追加してください。
