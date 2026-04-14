# root-domain

## 概要

- パス: `/home/kamiy2743/workspace/root-domain`
- 目的: `panda-dev.net` のルートサイトを静的配信する
- 構成: nginx による静的配信と Cloudflare Tunnel

## 構成

- `public/`: 静的サイトファイル
- `nginx/root-domain.conf`: nginx の静的配信設定と `/health`
- `cloudflared/config.yml`: `panda-dev.net` 向け ingress
- `docker-compose.yml`: `nginx` と `cloudflared` を起動

## 実行時のポイント

- nginx は静的ファイルを返し、`/health` には `200 ok` を返す
- Cloudflare Tunnel は `panda-dev.net` を `http://nginx:8000` に転送する
- Cloudflare Tunnel token などの機密値は `.env` ではなく `secrets/` 配下の Docker secrets で管理する
