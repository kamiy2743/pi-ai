# Codex container

Codex CLI をホストから分離して、常駐コンテナ内で使うための構成です。

## 起動

```bash
cd /home/kamiy2743/workspace/ai
printf 'HOST_UID=%s\nHOST_GID=%s\nCODEX_VERSION=latest\n' "$(id -u)" "$(id -g)" > .env
docker compose build
docker compose up -d
```

Codex CLI は npm ではなく、GitHub Release の Linux arm64 ネイティブバイナリを使います。既定では `latest` の `codex-aarch64-unknown-linux-musl.tar.gz` を取得します。

`.env` の `HOST_UID` / `HOST_GID` は、ホスト側の実行ユーザーに合わせます。これにより `/workspace` に作るファイルの所有者がホスト側のユーザーと一致します。

特定バージョンに固定する場合は `.env` の `CODEX_VERSION` を変更します。

```env
CODEX_VERSION=rust-v0.80.0
```

## 認証

初回だけコンテナ内で Codex にログインします。認証情報は `codex-home` volume に保存されます。

```bash
docker compose exec codex codex login
```

API key を使う場合は、対話ログインの代わりに次のように渡して実行します。

```bash
docker compose exec -e OPENAI_API_KEY="$OPENAI_API_KEY" codex codex
```

## 使い方

ワークスペース全体はコンテナ内の `/workspace` に mount されます。コンテナ自体は待機だけを行い、Codex セッションは必要なときに起動します。

```bash
docker compose exec codex codex
```

別のプロジェクトディレクトリで起動する場合:

```bash
docker compose exec -w /workspace/http-server codex codex
docker compose exec -w /workspace/health-check codex codex
```

コンテナを止める場合:

```bash
docker compose down
```

認証情報を含む Codex 用 volume も消す場合:

```bash
docker compose down -v
```

## 隔離の考え方

- ホストの Docker socket は mount しません。
- コンテナは `cap_drop: ALL` と `no-new-privileges` で権限を絞ります。
- ルートファイルシステムは read-only にし、`/tmp` と Codex の home/cache volume だけを書き込み可能にします。
- `/home/kamiy2743/workspace` は `/workspace` として read-write mount するため、この範囲のファイルは Codex から編集できます。
- Codex の対話セッションは `docker compose exec ... codex` の実行中だけ動きます。
