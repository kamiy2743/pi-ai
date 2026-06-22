# blog

## 概要

- パス: `/home/kamiy2743/workspace/blog`
- 目的: `blog.panda-dev.net` でブログを公開する
- 主な構成: Go、MySQL、Svelte、Inertia、nginx、cloudflared
- 主なルート: `/`, `/health`, `/article`, `/article/{articleId}`, `/admin`

## ディレクトリ構成

- `backend/`: Go アプリケーション
- `frontend/`: Svelte + Inertia のフロントエンドと SSR。`server/` に dev 用 Vite サーバーと本番 SSR サーバーを置く
- `mcp/`: `./blog back test` を HTTP 経由で公開する Go 製 MCP server。現在の公開 tool 名は `back_test`
- `nginx/`: reverse proxy と静的アセット配信
- `cloudflared/`: Tunnel の ingress 設定
- `secrets/`: `dev/`, `stg`, `prd` ごとの Docker secrets。dev/stg は repo 内 `secrets/<env>/` を使い、prd は deploy 時に `/etc/blog/secrets/` 直下へ同期する
- `docker-compose.dev.yml`: 開発用の `nginx`, `go`, `go-test`, `mysql`, `mysql-test`, `vite-dev`
- `docker-compose.stg.yml`: staging 用の `nginx`, `go`, `mysql`, `ssr`, `cloudflared`
- `docker-compose.prd.yml`: 本番用の `nginx`, `go`, `mysql`, `ssr`, `cloudflared`
- `blog`: `./blog {dev|stg|prd} ...` で `docker compose -p blog-{env}` を呼ぶラッパ。基本的な操作は `docker compose` を直接叩かず、原則 `./blog` 経由で行う

## 実行時のポイント

- `cloudflared` は `blog.panda-dev.net` / `blog-stg.panda-dev.net` を `http://nginx:8000` に転送する。stg は外部公開する場合、Cloudflare Access で認証を必須にする
- `dev` / `stg` は dev マシン上、`prd` は prd マシン上で動かす。SSH 名は dev/stg 側が `eq14-dev`、prd 側が `eq14-prd`。prd とは Docker volume、network、secrets、git checkout、image cache が共有されない前提で扱う
- Codex 上で `blog` の test を頼まれたときは、まず `mcp__blog_mcp__blog_back_test` を使う。fmt は Codex コンテナ側の `gofmt` / `go fmt` で実行する
- `backend/internal/config/` で env と Docker secrets の取得をまとめ、`go` は `APP_ENV`, `PORT`, `SSR_URL`, `INERTIA_TEMPLATES_DIR`, `TEMPLATE_*` などを前提に Inertia SSR を使う
- `backend/` の Go 実装方針を読むときは `go-impl` スキルを優先し、ここでは Raspberry Pi 上の構成・運用前提だけを見る
- Inertia 向け handler は adapter 経由で HTTP response へ変換する。page handler は `handlerresult.PageResult, error`、action handler は `handlerresult.ActionResult, error` を返す
- Inertia page の共通 props 名は `oldInput`, `validationErrors`, `flash` の順で使う
- `ValidationError` は `field -> message` の `Messages map[string]string` を持つ error として扱い、page はそのまま返し、action は session 経由で redirect back 後に表示する
- action adapter はエラー時に request body の string field を `oldInput` として session に保存する。body は読み戻してから handler に渡すので、feature handler で oldInput 保存はしない
- `backend/internal/handler/session.SessionPayload` は `OldInput map[string]string`, `ValidationError *handlererror.ValidationError`, `Flash *session.Flash` をこの順で持つ
- 同一 page 内の複数 form で field 名が重なるときは、hidden field `formKey` で form を識別する。validation key は backend では `name` のような field 名のまま扱い、frontend 側で `oldInput.formKey` を見て対象 form の値と error を表示する
- top 画面のカテゴリ一覧は記事から抽出せず、`category.Repository` の `All` で全カテゴリを取得する
- 日時は DB / backend では UTC に統一し、backend から frontend へ渡すときだけ ISO 8601 文字列にする。frontend では ISO 8601 として扱い、画面表示時だけ JST に整形する
- `go` 側は末尾 `/` を middleware で除去して canonical URL に寄せる前提なので、`/article` と `/article/` のような二重定義は不要
- `/admin` 配下は Go 側で Basic Auth を要求し、その資格情報は `/run/secrets/admin_basic_auth_*` から読む。公開時は Cloudflare Access と合わせて二段で保護する前提
- 管理画面のカテゴリ管理は `GET/POST /admin/category`, `POST /admin/category/{categoryId}`, `POST /admin/category/{categoryId}/delete` を基本形にする。HTML form 前提なので削除も POST で扱う
- 管理画面の記事作成は作成時点で公開/非公開、公開開始時刻、公開終了時刻を指定できる前提にする。本文 field は DB/domain の `body` に合わせ、旧 UI の `content_md` へ寄せない
- Svelte/Inertia の default layout でページ本体と常設 UI（例: global flash）を並べるときは fragment root にせず、安定した wrapper を置く。prd SSR で hydration 時の DOM 差し込み先が不安定になるのを避けるため
- `dev` / `stg` の compose は `secrets/<env>/`、prd compose と prd の `migrate` / `seed` は `/etc/blog/secrets/` を参照する。MySQL の root password, user, user password も Docker secrets で渡す
- `mcp` service は `docker.sock` 経由で `./blog` を叩くので、`REPO_ROOT` と repo mount path は `/home/kamiy2743/workspace/blog` のようなホスト実在 path に合わせる。`/app` のようなコンテナ内専用 path だと `docker compose` の bind mount / secrets 解決に失敗する
- `mcp` server は `mcp/.env` の `PORT`, `REPO_ROOT`, `SERVER_NAME`, `SERVER_VERSION` を読む。HTTP path は `/` で待ち受け、`CMD` は `blog-mcp` だけを実行する
- `dev` では `SSR_URL=http://vite-dev:5173` を使い、`vite-dev` のカスタム Node サーバーが Vite middleware と `/render` を兼ねる。開発用の別 `ssr` service は使わない
- `dev` の `nginx` は `127.0.0.1:8000` を host に bind し、`/error`, Vite の module/HMR/fallback favicon だけを `vite-dev:5173` へ、画面本体と API は `go` へ proxy する
- `dev` を Windows から確認するときは、上の localhost bind と SSH トンネル利用が前提になる
- Codex コンテナには Node / npm が入っていないため、frontend の build / typecheck は直接実行できない。必要ならホスト側または frontend 用コンテナで確認する
- `stg` / `prd` の `nginx` は `/dist/client/` を直接返し、それ以外を `go` へ proxy する
- `stg` / `prd` の `ssr` は `frontend/Dockerfile.ssr` から起動し、`frontend/server/ssr-server.ts` が `/render` と `/health` を返す
- `frontend/public/` の静的ファイルは dev では Vite dev server がルート直下 `/...` で返し、stg / prd では client build 後に `/dist/client/...` として nginx から返す
- `nginx/snippets/header.conf` に CSP の共通形を置き、`dev.conf` / `stg.conf` / `prd.conf` では `set $csp_connect_src ...` で `connect-src` だけ出し分ける。dev は HMR 用に `ws://localhost:8000` を許可する
- `backend/cmd/` は `app`, `migration`, `seed` に分かれ、通常起動と DB 操作を分離している
- `ent` の schema と生成コードは `backend/internal/db/ent/` に置き、`./blog ent generate` はここを対象にする
- `./blog` には `up|down|restart|recreate` に加えて `mysql`, `migrate`, `seed`, `ent generate`, `back fmt`, `back test <backend package path>` があり、基本操作はこのラッパ経由で行う
- `./blog back fmt` と `./blog back mod tidy` は `backend/`, `mcp/`, `blogcmd/` の各 Go module を対象にする。fmt は各 module で `go fmt ./...` を実行する
- `./blog back test` は Go package 単位の実行を前提とし、`backend/internal/.../show` のようなディレクトリや package path を渡す。`*_test.go` のファイル指定は受けない
- `./blog back test backend/internal/handler/...` のように `...` で配下 package を再帰実行できる。`mysql-test` を共有するため、ラッパ側では package 並列実行を避ける `go test -p 1` を使う
- `dev` には常駐の `go-test` service があり、`./blog back test` は `go-test` へ `docker compose exec` して実行する。`go-test` は `backend/Dockerfile.test` で依存取得を build 時に済ませ、実行時は `private` network のみで動かす
- `./blog back test` は `go list` で `*_test.go` を持つ package だけを抽出してから `go test -mod=readonly -p 1` を流すので、`[no test files]` は出ない
- `go-test` は `backend/.env.test` を使い、`mysql-test` へ `mysql-test:3306` で接続する。`mysql-test` は host 公開せず `private` network 内だけで使う
- `dev` の `mcp` service は `mcp-share` external network に `blog-mcp` alias で参加し、共通の `codex` コンテナから `http://blog-mcp:<PORT>/` で使う前提
- `mcp` は `mcp/.env` の `PORT` を listen port に使い、`docker compose` 実行用の Docker CLI 設定は `DOCKER_CONFIG=/tmp/docker-config` と `tmpfs /tmp` で read-only rootfs から分離する
- `backend/internal/test/helper/RequestInertia` は Inertia page object の JSON を返す正常系レスポンス向けで、plain text の `500` や redirect 検証には向かない。`InertiaResponse.AssertProps` は `200 OK` を内部で固定し、component と props の検証に使う
- admin 配下の Inertia test は `RequestInertia` に `UseBasicAuth: true` を渡し、Basic Auth の値は helper 側で config から読む
- Inertia action test は `internal/test/helper/inertia/action` を使い、redirect 先、`oldInput`, `validationErrors`, `flash` を必要に応じて session payload から検証する。複数 form の画面では request body に `formKey` を含める
- `article/search` と `admin/show` のカテゴリ絞り込みは、カテゴリ未指定なら `categoryRepository.Search` を呼ばず空 selection のまま扱う。複数カテゴリ指定時の記事検索は OR ではなく AND 条件で、指定した全カテゴリを持つ記事だけを返す
- `./blog {env} migrate ...` と `./blog {env} seed ...` は compose の常駐 service ではなく、専用 Dockerfile から one-shot コンテナを起動して実行する。prd では `/etc/blog/secrets/` を `/run/secrets` に bind mount する
- 開発用 seed は SQL ファイルではなく `backend/cmd/seed` から ent 経由で投入する
- `./blog` は project 名に `blog-dev`, `blog-stg`, `blog-prd` を使うので、volume や network 名にもその prefix が付く
- `./blog` の実装本体は `blogcmd/` の独立 Go module。`./blog buildcmd` で `blogcmd/bin/blogcmd` をビルドし、それ以外の `./blog ...` は `blogcmd/bin/blogcmd` へそのまま渡す
- `stg` / `prd` の image は `ghcr.io/kamiy2743/blog/{go,nginx,ssr,migration,seed}:<env>` 固定。`./blog {stg|prd} deploy` は dev マシンで build + push し、stg は同一 dev マシンで pull + up、prd は `eq14-prd` へ SSH して `/opt/blog` へ必要ファイル、`/etc/blog/secrets` へ secret を同期してから pull + up する
- prd の `/etc/blog/secrets` は Docker secrets として非 root コンテナから読まれるため、directory は辿れる権限、secret file は world-readable 相当の権限にする。secret を image へ含めないことを優先する
- MySQL は初期化時に data directory 以外にも書き込みが発生するため、`read_only: true` にはしない
- 記事本文 Markdown は backend domain で HTML へ変換し、sanitize 後の HTML を frontend の `{@html ...}` で表示する。Markdown 拡張や link 属性のような本文 HTML の仕様は、この変換処理側で揃える

## prd セキュリティ確認

- `prd` の外形監査は host の待受、ufw、Docker publish、Cloudflare Tunnel、nginx、admin 認証、secrets、本文 sanitizer の順に見る
- host 側は `sudo ss -ltnp` と `sudo ufw status verbose` で、外部待受が SSH だけか、ufw が `deny incoming` か、SSH 許可元が LAN など必要範囲に限定されているかを確認する
- Docker 側は `docker ps --format 'table {{.Names}}\t{{.Ports}}\t{{.Status}}'` で、`0.0.0.0:3306`, `0.0.0.0:8000`, `0.0.0.0:80`, `0.0.0.0:443` のような host port publish がないことを確認する。`80/tcp` や `3306/tcp` だけなら expose 表示であり host 公開ではない
- Cloudflare Tunnel は `cloudflared/config.prd.yml` で、`blog.panda-dev.net` だけが `http://nginx:8000` に向き、最後が `http_status:404` の catch-all になっていることを確認する
- nginx 設定は image 内に含まれるため、prd では `./blog prd exec nginx nginx -T` で実際に読み込まれた設定を見る。CSP、`frame-ancestors 'none'`、`object-src 'none'`、`X-Content-Type-Options nosniff`、`Strict-Transport-Security`、`Permissions-Policy`、`Referrer-Policy`、`autoindex` 無効、不要な location 不在を確認する。`server_tokens off;` も入れる
- `/admin` は Cloudflare Access と Go Basic Auth の二段で守る。外部から `curl -I https://blog.panda-dev.net/admin` が Access login へ 302 され、内部から `./blog prd exec nginx wget -S -O - http://go:8000/admin` が `401 Unauthorized` になることを確認する。`/admin/` や `/admin/category` など配下 path も同様に確認する
- secrets は repo や image に含めず、prd では `/etc/blog/secrets/` から Docker secrets として渡す。Cloudflare Tunnel token、Basic Auth、MySQL password などを `.env` や compose の平文に置かない
- 記事本文は Markdown から HTML 化して `{@html ...}` で表示するため、XSS 監査では backend domain の sanitizer と link 属性仕様を最優先で確認する
- 公開レスポンスは `curl -I https://blog.panda-dev.net/` でセキュリティヘッダーが Cloudflare 越しにも出ていることを確認する

## 重要ファイル

- `backend/cmd/app/main.go`: Go アプリのエントリポイント
- `backend/cmd/migration/main.go`: migration 実行用エントリポイント
- `backend/cmd/seed/main.go`: seed 実行用エントリポイント
- `backend/internal/config/`: backend の env / Docker secrets 読み取り
- `backend/internal/db/`: MySQL / ent client の接続処理
- `backend/internal/domain/`: `article`, `category` などの domain 型
- `backend/internal/datetime/`: UTC / ISO 8601 変換を集約する日時 helper
- `backend/internal/db/ent/`: ent schema と生成コード
- `backend/internal/handler/`: handler 群。例: `admin/article/create/`, `article/search/`, `top/show/`
- handler 実装の参考: `top/show` はトップ画面、`article/search` と `admin/show` は initial / partialSearch を持つ検索・ページング、`article/show` は path ID からの詳細表示
- `backend/internal/infra/category/`: カテゴリ repository。top 画面のカテゴリ一覧取得元
- `backend/internal/seed/`: 開発用 seed 実装
- `backend/internal/test/`: backend integration test 用 helper と fixture
- `backend/Dockerfile.app`: app 用イメージ
- `backend/Dockerfile.test`: test 用イメージ
- `backend/Dockerfile.migration`: migration 用イメージ
- `backend/Dockerfile.seed`: seed 用イメージ
- `mcp/Dockerfile`: MCP server 用イメージ。`docker`, `docker compose`, `buildx` plugin も同梱する
- `docker-compose.dev.yml`: 開発 compose
- `docker-compose.stg.yml`: staging compose
- `docker-compose.stg-build.yml`: staging image build 用 compose override
- `docker-compose.prd.yml`: 本番 compose
- `docker-compose.prd-build.yml`: 本番 image build 用 compose override
- `blog`: compose ラッパ
- `blogcmd/cmd/app/main.go`: `blogcmd` のエントリポイントと top-level dispatch。実装本体は `blogcmd/internal/` 配下に command ごとの package として置く
- `nginx/dev.conf`: 開発 nginx 設定
- `nginx/stg.conf`: staging nginx 設定
- `nginx/prd.conf`: 本番 nginx 設定
- `nginx/snippets/upstream.conf`: `go` upstream 定義
- `nginx/snippets/header.conf`: 共通セキュリティヘッダーと CSP テンプレート
- `frontend/vite.config.vite-dev.js`: Vite dev server 設定
- `frontend/vite.config.client.js`: client build 設定
- `frontend/vite.config.ssr.js`: SSR build 設定
- `frontend/Dockerfile.ssr`: 本番 SSR コンテナ用の共通 Dockerfile
- `frontend/server/dev-server.mjs`: dev 用の Vite + SSR エントリポイント
- `frontend/server/render.ts`: dev / prd 共通の Inertia SSR 描画処理
- `frontend/server/ssr-server.ts`: 本番 SSR サーバー
- `cloudflared/config.stg.yml`, `cloudflared/config.prd.yml`: Tunnel ingress 設定
