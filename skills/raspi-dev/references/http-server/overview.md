# http-server

## 概要

- パス: `/home/kamiy2743/workspace/http-server`
- 目的: nginx と Cloudflare Tunnel で静的サイトを公開する
- 公開ホスト名: `http-server.panda-dev.net`

## 構成

- `content/article.md`: 記事の元 Markdown
- `scripts/build_site.py`: Markdown から `public/index.html` を生成する
- `public/`: 静的アセットと生成済み HTML
- `nginx/http-server.conf`: 静的配信と `/health`
- `cloudflared/config.yml`: Tunnel ingress
- `docker-compose.yml`: `nginx` と `cloudflared` を起動

## ビルドフロー

- `scripts/build_site.py` は限定的な Markdown を HTML に変換する
- 生成した記事 HTML を `public/index.html` の `<main class="article">...</main>` に差し込む
- これはアプリケーションサーバーではなく静的サイト生成の流れ

## 実行時のポイント

- nginx は `/usr/share/nginx/html` から静的ファイルを返す
- `/health` は `200 ok` を返す
- Cloudflare Tunnel は `http-server.panda-dev.net` を `http://nginx:8000` に転送する
- Cloudflare Tunnel token などの機密値は `.env` ではなく `secrets/` 配下の Docker secrets で管理する
