---
name: go-impl
description: Go で internal 配下を domain, infra, handler, middleware, config, di に分ける構成の実装・修正を行うときに使う。cmd/main.go でアプリ初期化とルーティングを行い、main で外部リソースを open し、di/container で repository, usecase, handler を組み立てるプロジェクトで使う。
---

# Go Impl

## 目的

- Go の `cmd` / `internal` 構成を持つプロジェクトで、実装位置と責務分割を揃えて作業する。
- メインのスキル本文は薄く保ち、package ごとの詳細は `references/` を読む前提にする。

## 使い方

1. Go のルートディレクトリを特定する。
2. まず [references/overview.md](references/overview.md) を読む。
3. 触る package に対応する reference だけ追加で読む。
4. reference を前提にしつつ、実装前に既存コードを必ず確認する。

## 読み分け

- エントリポイントや route 登録: [references/cmd/main.md](references/cmd/main.md)
- 環境変数や secrets: [references/internal/config/overview.md](references/internal/config/overview.md)
- domain 型、ID、criteria、repository interface: [references/internal/domain/overview.md](references/internal/domain/overview.md)
- handler、usecase、formatter、result: [references/internal/handler/overview.md](references/internal/handler/overview.md)
- repository 実装、hydrator、永続化: [references/internal/infra/overview.md](references/internal/infra/overview.md)
- middleware の型、順序、適用: [references/internal/middleware/overview.md](references/internal/middleware/overview.md)
- `internal/di/` は `cmd/main.go` と併せて読み、main から渡された依存で repository / usecase / handler を組み立てる前提で扱う。

## 共通方針

- 新しい feature を足すときは、先に domain の型と interface を決め、その後で infra と handler をつなぐ。
- 外部リソースの open / close は `main` で管理し、`di` では受け取った依存の組み立てに集中する。
- validation は入力に近い domain 型や parse 関数に寄せる。
- hydrate は永続化モデルを domain に写す責務に留める。
- route の追加時は `main` の依存注入と middleware 適用箇所も合わせて確認する。
- Go のテスト実行は file 単位ではなく package 単位を基本にし、`go test ./internal/.../show` のように対象 directory / package を渡す。
