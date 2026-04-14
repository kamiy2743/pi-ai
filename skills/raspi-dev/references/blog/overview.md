# blog

## 概要

- パス: `/home/kamiy2743/workspace/blog`
- 目的: `blog.panda-dev.net` でブログを公開する
- 主な構成: Go、MySQL、Svelte、Inertia、nginx、cloudflared
- 主なルート: `/`, `/health`, `/article`, `/article/{articleId}`, `/admin`

## ディレクトリ構成

- `backend/`: Go アプリケーション
- `frontend/`: Svelte + Inertia のフロントエンドと SSR
- `nginx/`: reverse proxy と静的アセット配信
- `cloudflared/`: Tunnel の ingress 設定
- `secrets/`: `dev/`, `prd/` ごとの Docker secrets
- `docker-compose.dev.yml`: 開発用の `nginx`, `go`, `mysql`, `vite-dev`, `ssr`
- `docker-compose.prd.yml`: 本番用の `nginx`, `go`, `mysql`, `ssr`, `cloudflared`
- `blog`: `./blog {dev|prd} ...` で `docker compose -p blog-{env}` を呼ぶラッパ。基本的な操作は `docker compose` を直接叩かず、原則 `./blog` 経由で行う

## 実行時のポイント

- `cloudflared` は `blog.panda-dev.net` を `http://nginx:8000` に転送する
- `backend/internal/config/` で env と Docker secrets の取得をまとめ、`go` は `APP_ENV`, `PORT`, `SSR_URL`, `INERTIA_ROOT_TEMPLATE` などを前提に Inertia SSR を使う
- `backend/` の Go 実装方針を読むときは `go-impl` スキルを優先し、ここでは Raspberry Pi 上の構成・運用前提だけを見る
- top 画面のカテゴリ一覧は記事から抽出せず、`category.Repository` の `All` で全カテゴリを取得する
- backend から frontend へ渡す日時は表示用に整形せず、ISO 8601 文字列で渡して frontend 側で整形する方針
- `go` 側は末尾 `/` を middleware で除去して canonical URL に寄せる前提なので、`/article` と `/article/` のような二重定義は不要
- `/admin` 配下は Go 側で Basic Auth を要求し、その資格情報は `/run/secrets/admin_basic_auth_*` から読む。公開時は Cloudflare Access と合わせて二段で保護する前提
- `dev` / `prd` の compose は `secrets/dev/`, `secrets/prd/` を参照し、MySQL の root password, user, user password も Docker secrets で渡す
- `dev` の `nginx` は `127.0.0.1:8000` を host に bind し、Vite の asset/HMR を `vite-dev:5173` へ、その他を `go` へ proxy する
- `dev` を Windows から確認するときは、上の localhost bind と SSH トンネル利用が前提になる
- `prd` の `nginx` は `/dist/client/` を直接返し、それ以外を `go` へ proxy する
- `frontend/public/` の静的ファイルは dev では Vite dev server がルート直下 `/...` で返し、prd では client build 後に `/dist/client/...` として nginx から返す
- `backend/cmd/` は `app`, `migration`, `seed` に分かれ、通常起動と DB 操作を分離している
- `ent` の schema と生成コードは `backend/internal/ent/` に置き、`./blog ent generate` はここを対象にする
- `./blog` には `up|down|restart|recreate` に加えて `mysql`, `migrate`, `seed`, `ent generate`, `back fmt`, `back test <backend package path>` があり、基本操作はこのラッパ経由で行う
- `./blog back test` は Go package 単位の実行を前提とし、`backend/internal/.../show` のようなディレクトリや package path を渡す。`*_test.go` のファイル指定は受けない
- `dev` には常駐の `go-test` service があり、`./blog back test` は `go-test` へ `docker compose exec` して実行する。初回は module / build cache を作るが、2 回目以降は cache が効く
- `go-test` は `backend/.env.test` を使い、`mysql-test` へ `mysql-test:3306` で接続する。`mysql-test` は host 公開せず `private` network 内だけで使う
- `backend/internal/test/helper/RequestInertia` は Inertia page object の JSON を返す正常系レスポンス向けで、plain text の `500` や redirect 検証には向かない。`InertiaResponse.AssertProps` は `200 OK` を内部で固定し、component と props の検証に使う
- `./blog {env} migrate ...` と `./blog {env} seed ...` は compose の常駐 service ではなく、専用 Dockerfile から one-shot コンテナを起動して実行する
- 開発用 seed は SQL ファイルではなく `backend/cmd/seed` から ent 経由で投入する
- `./blog` は project 名に `blog-dev`, `blog-prd` を使うので、volume や network 名にもその prefix が付く
- MySQL は初期化時に data directory 以外にも書き込みが発生するため、`read_only: true` にはしない

## 重要ファイル

- `backend/cmd/app/main.go`: Go アプリのエントリポイント
- `backend/cmd/migration/main.go`: migration 実行用エントリポイント
- `backend/cmd/seed/main.go`: seed 実行用エントリポイント
- `backend/internal/config/`: backend の env / Docker secrets 読み取り
- `backend/internal/db/`: MySQL / ent client の接続処理
- `backend/internal/domain/`: `article`, `category` などの domain 型
- `backend/internal/ent/`: ent schema と生成コード
- `backend/internal/handler/`: handler 群。例: `admin/article/create/`, `article/search/`, `top/show/`
- `backend/internal/infra/category/`: カテゴリ repository。top 画面のカテゴリ一覧取得元
- `backend/internal/seed/`: 開発用 seed 実装
- `backend/internal/test/`: backend integration test 用 helper と fixture
- `backend/Dockerfile.app`: app 用イメージ
- `backend/Dockerfile.migration`: migration 用イメージ
- `backend/Dockerfile.seed`: seed 用イメージ
- `docker-compose.dev.yml`: 開発 compose
- `docker-compose.prd.yml`: 本番 compose
- `blog`: compose ラッパ
- `nginx/dev.conf`: 開発 nginx 設定
- `nginx/prd.conf`: 本番 nginx 設定
- `nginx/snippets/upstream.conf`: `go` upstream 定義
- `frontend/vite.config.vite-dev.js`: Vite dev server 設定
- `frontend/vite.config.client.js`: client build 設定
- `frontend/vite.config.ssr.js`: SSR build 設定
- `frontend/Dockerfile.ssr.dev`: 開発 SSR コンテナ
- `frontend/Dockerfile.ssr.prd`: 本番 SSR コンテナ
- `cloudflared/config.yml`: Tunnel ingress 設定

## 現状メモ

- バックエンドは Inertia の画面遷移とルーティングの骨組みが中心で、記事 CRUD や DB アクセスは未完成の部分がある
