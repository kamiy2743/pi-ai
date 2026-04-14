# AI

## 目的

- `/home/kamiy2743/workspace/ai` は、Codex 実行用の Docker 環境と Codex skills を管理するプロジェクト。
- この実行環境ではホスト側のプロジェクトルートがコンテナ内の `/workspace` にマウントされるため、Pi 上の `/home/kamiy2743/workspace/<project>` はコンテナ内では `/workspace/<project>` として見える。

## 構成

- `docker-compose.yml` は `codex` サービスを定義し、`sleep infinity` で常駐させる。
- `Dockerfile` は Debian bookworm-slim ベースで、`bubblewrap`, `curl`, `git`, `openssh-client`, `ripgrep` を入れ、OpenAI Codex の Linux aarch64 musl 版を GitHub Releases から取得する。
- `codex` は `docker compose exec codex codex "$@"` を実行する薄いラッパースクリプト。
- `config.toml` は Codex 設定で、`/workspace` を trusted project とし、GitHub curated plugin を有効化している。
- `skills/` は `/home/codex/.codex/skills/` に rw マウントされ、`raspi-dev`, `go-impl`, `update-raspi-dev` と system skills を置く。

## Docker 実行環境

- `codex-home` と `codex-cache` は Docker volume。
- `./config.toml` は `/home/codex/.codex/config.toml` に read-only でマウントされる。
- `../` は `/workspace/` に read-write でマウントされる。
- コンテナは `cap_drop: ALL`, `no-new-privileges:true`, `read_only: true`, `/tmp` tmpfs で動かす。
- build args は `.env` 由来の `HOST_UID`, `HOST_GID`, `CODEX_VERSION` を使う。`.env` の値は reference に残さない。

## Codex 設定

- `sandbox_mode = "danger-full-access"` は、Codex がファイルシステムを広く読み書きできる設定。
- `approvals_reviewer = "user"` は、承認が必要な操作の確認先をユーザーにする設定。
- `[projects."/workspace"] trust_level = "trusted"` により、コンテナ内の workspace を信頼済みプロジェクトとして扱う。
- `[plugins."github@openai-curated"] enabled = true` により、GitHub plugin を有効化する。

## 運用メモ

- skills を更新する場合は、基本的に `/home/kamiy2743/workspace/ai/skills/` 側を編集する。
- このプロジェクト内で実行中の Codex から見ると、同じ内容は `/workspace/ai/skills/` および `/home/codex/.codex/skills/` として見える。
- `config.toml` はコンテナ内では read-only マウントなので、恒久変更はホスト側の `ai/config.toml` を編集する。
- `sandbox_mode = "danger-full-access"` は便利だが強い権限を持つため、秘密鍵、`.env`、システム設定を扱う作業では内容の露出や不要な変更を避ける。
