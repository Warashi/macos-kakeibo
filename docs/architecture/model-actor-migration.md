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
- `Tests/Utilities/Architecture/ModelActorIsolationTests.swift` で Domain 層が `import SwiftData` や `ModelContext` を参照していないことを自動検査。ModelActor 化の前提条件をテストで担保する。
- `docs/architecture/fetch-queries.md` / `repository-observation.md` / 本ドキュメントを合わせて読み、クエリと監視の共通 API を経由するルールを確認する。
- View で Repository/UseCase を直接生成しない。`TransactionStackBuilder` のようなビルダーにまとめ、将来の actor 差し替えポイントを限定する。

## レビュー/追加時のチェックリスト

1. 新しい Domain ファイルが `SwiftData` / `SwiftUI` / `ModelContext` を import していないか。
2. Infrastructure の SwiftData コードは `Sources/Infrastructure/Persistence` から外へ漏れていないか。
3. View/Store で `ModelContainer` を扱う場合はビルダー経由になっているか。
4. Repository の追加/変更時は `@DatabaseActor` 属性を付けたまま、UseCase/Store 経由でのみ呼び出しているか。
5. クエリ生成や監視処理は `Sources/Utilities/Queries` / `Sources/Utilities/Observation` を通じているか。

これらを満たしていれば、`@ModelActor` への置換は Database 層の実装差分に閉じ込められ、他レイヤーの変更を最小化できる。
