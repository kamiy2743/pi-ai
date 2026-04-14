---
name: raspi-dev
description: Raspberry Pi 上の /home/kamiy2743/workspace で作業するときに使う。
---

# Raspi Dev

## 目的

- `/home/kamiy2743/workspace` 配下の作業で使う。
- Raspberry Pi 上の実行環境、公開構成、既存プロジェクトの文脈を毎回説明しなくてよいようにする。

## 共通コンテキスト

- この環境は Raspberry Pi 5 上で動いている。
- ユーザーは学習目的で Raspberry Pi 上の開発とサーバー運用をしている。
- ユーザーは同一 LAN 内の Windows マシンから SSH で接続して作業している。
- Windows から Pi 上の localhost 向け開発サービスを見るときは、SSH トンネルを使う運用になっている。
- ホスト名は `kamiy2743`、mDNS 名は `kamiy2743-2.local`。
- 保有ドメインは `panda-dev.net`。
- SSH は公開鍵認証を使っている。
- `fail2ban` は導入済み。
- `ufw` は有効で、現時点では `22/tcp` を `192.168.0.0/24` からのみ許可している。
- この実行環境では Go の PATH が通っていないことがあるため、Go コマンドは `/usr/local/go/bin/go` の絶対パスで使う。
- 公開系プロジェクトの compose では、Cloudflare Tunnel token や Basic Auth などの機密値は `.env` ではなく `secrets/` 配下の Docker secrets で管理する運用になっている。
- 返答は日本語で行う。
- 説明では、可能な限り手順、コマンド、確認方法を示す。
- 外部からの攻撃を受けやすい環境であることを前提に、セキュリティに配慮する。

## 使い方

1. 対象のプロジェクトが `/home/kamiy2743/workspace` のどこかを特定する。
2. まず該当する project reference を読む。
3. reference は前提知識として使い、変わりやすい内容は必ず現在のコードや設定も確認する。

## Project References

- `blog`: `references/blog/overview.md`
- `cloudflare`: `references/cloudflare/overview.md`
- `health-check`: `references/health-check/overview.md`
- `http-server`: `references/http-server/overview.md`
- `root-domain`: `references/root-domain/overview.md`
