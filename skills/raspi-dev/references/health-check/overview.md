# health-check

## 概要

- パス: `/home/kamiy2743/workspace/health-check`
- 目的: Raspberry Pi 上で公開している URL 群を定期監視し、状態変化があれば Discord に通知する
- 実装: Go 製の常駐プロセスを Docker Compose で動かす

## 動作

- 監視対象 URL は `URLS_PATH` で指定したファイルから読む。現行運用では `/app/.urls`
- 各 URL の `/health` を HTTP GET で監視する
- `HEALTH_CHECK_INTERVAL` ごとに境界時刻へ揃えて実行する
- `HEALTH_CHECK_TIMEOUT` と `HEALTH_CHECK_RETRIES` を使って各 URL を判定する
- 前回の失敗集合はメモリ保持で管理し、状態ファイルは使わない
- Discord Webhook URL は `.env` ではなく Docker secrets の `/run/secrets/discord_webhook_url` から読む
- Discord 通知は失敗集合に差分があるときだけ送る

## 主要ファイル

- `cmd/main.go`: エントリポイント
- `internal/config/config.go`: `.env` と secrets の getter
- `internal/config/env.go`: 環境変数の型変換
- `internal/config/secrets.go`: Docker secrets の読み取り
- `internal/config/urls.go`: 監視対象 URL の読み取り
- `internal/healthcheck/checker.go`: `/health` チェックとリトライ
- `internal/healthcheck/run.go`: 定期実行、差分計算、通知呼び出し
- `internal/healthcheck/discord.go`: Discord Webhook の payload 作成
- `docker-compose.yml`
- `Dockerfile`

## 通知仕様

- すべて解消、一部解消、新規失敗、失敗増加の 4 パターンを扱う
- Discord の Embed 形式で通知する
- 同じ失敗集合が継続している間は重複通知を抑制する
