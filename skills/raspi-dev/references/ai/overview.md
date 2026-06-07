# AI

## 目的

- `/home/kamiy2743/workspace/ai` は、Codex 実行用の Docker 環境と Codex skills を管理するプロジェクト。

## 構成

- `docker-compose.yml` は `codex` サービスを定義し、`sleep infinity` で常駐させる。
- `Dockerfile` は Debian bookworm-slim ベースで、`bubblewrap`, `curl`, `git`, `openssh-client`, `ripgrep` を入れ、OpenAI Codex の Linux aarch64 musl 版を GitHub Releases から取得する。
- `codex` は `docker compose exec codex` で Codex を起動するラッパースクリプト。
- `codex` は起動直後に `/home/codex/.codex/log/codex-tui.log` へ出る `thread_id` を監視し、検出したセッションIDを `/proc/1/fd/1` へ書いてコンテナログへ出す。
- `config.toml` は Codex 設定で、`/workspace` を trusted project とし、GitHub curated plugin を有効化している。
- `config.toml` は `/workspace/ai/config.toml` を実体とし、起動時に `/home/codex/.codex/config.toml` から symlink で参照される。
- `skills/` は `/workspace/ai/skills` を実体とし、起動時に `/home/codex/.codex/skills` から symlink で参照される。

## Docker 実行環境

- `codex-home` と `codex-cache` は Docker volume。
- `./config.toml` はホスト側の実体設定として使い、起動時に `/home/codex/.codex/config.toml` から symlink で参照される。
- `../` は `/workspace/` に read-write でマウントされる。
- コンテナは `cap_drop: ALL`, `no-new-privileges:true`, `read_only: true`, `/tmp` tmpfs で動かす。
- build args は `.env` 由来の `HOST_UID`, `HOST_GID`, `CODEX_VERSION` を使う。`.env` の値は reference に残さない。

## Codex 設定

- `sandbox_mode = "danger-full-access"` は、Codex がファイルシステムを広く読み書きできる設定。
- `approvals_reviewer = "user"` は、承認が必要な操作の確認先をユーザーにする設定。
- `[projects."/workspace"] trust_level = "trusted"` により、コンテナ内の workspace を信頼済みプロジェクトとして扱う。
- `[plugins."github@openai-curated"] enabled = true` により、GitHub plugin を有効化する。

## 運用メモ

- Codex 側の `/home/codex/.codex/config.toml` 変更は、ホスト側 `/workspace/ai/config.toml` へそのまま反映される。
- 既存 volume に通常ファイルの `/home/codex/.codex/config.toml` がある場合、初回起動時に `config.toml.pre-symlink.<timestamp>` として退避される。
- `sandbox_mode = "danger-full-access"` は便利だが強い権限を持つため、秘密鍵、`.env`、システム設定を扱う作業では内容の露出や不要な変更を避ける。
