# go-impl

## 概要

- 対象: `cmd/main.go` と `internal/` を持つ Go アプリケーション
- 想定構成: `internal/config`, `internal/domain`, `internal/handler`, `internal/infra`, `internal/middleware`, `internal/di`
- 目的: 責務ごとの配置を崩さずに実装を追加・修正する

## ディレクトリ構成

- `cmd/main.go`: アプリ起動、env 読み取り、外部リソース open/close、route 登録
- `internal/config/`: env や secret の取得
- `internal/domain/`: entity、ID 型、criteria、repository interface
- `internal/handler/`: HTTP handler、usecase、formatter、result
- `internal/infra/`: repository 実装、hydrator など外部 I/O の詳細
- `internal/middleware/`: HTTP middleware とその合成
- `internal/di/`: main から受け取った依存を組み立てて handler を返す

## 実装順

1. 変更対象 feature の既存 package を確認する。
2. 新規 feature なら `domain` に型と interface を追加する。
3. 永続化や外部連携が要るなら `infra` を追加する。
4. HTTP 入出力が要るなら `handler` を追加する。
5. `internal/di/` で repository / usecase / handler を組み立てる。
6. `cmd/main.go` で依存注入と route を接続する。
7. 既存 middleware や config への影響を確認する。

## 命名の目安

- ID 型: `<Entity>ID`
- Parse 関数: `Parse<Entity>ID`
- repository interface: `<Entity>Repository`
- repository 実装: `New<Entity>Repository`
- handler 入口: `Handle`
- usecase 実行入口: `Run`
- frontend 変換: `Format`
- 取得系条件: `Search<Entity>Criteria`
- 作成入力: `Create<Entity>Input`
- feature result: `Show<Entity>Result` など action 単位

## コード例

```text
internal/
  config/
  domain/
    article/
      article.go
      article_id.go
      article_repository_interface.go
      search_article_criteria.go
  handler/
    top/
      show/
        show_top_handler.go
        show_top_usecase.go
        show_top_result.go
        show_top_formatter.go
  infra/
    article/
      article_repository.go
      article_hydrator.go
  di/
    container.go
  middleware/
cmd/
  app/main.go
```
