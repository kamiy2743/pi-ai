# cloudflare

## 概要

- パス: `/home/kamiy2743/workspace/cloudflare`
- 目的: Cloudflare の Zero Trust と `panda-dev.net` Zone 設定を Terraform で管理する

## 構成

- `zero_trust/`: Account スコープの設定。Access、IdP、Policy、App など
- `zone/panda_dev_net/`: Zone スコープの設定。DNS や Cache Rules など
- `modules/tunnel/`: Tunnel と DNS CNAME をまとめる共通 module

## ルール

- Account リソースは `zero_trust/` に置く
- Zone リソースは `zone/panda_dev_net/` に置く
- `variables.tf` と `terraform.tfvars` はディレクトリごとに管理する
- state は `zero_trust` と `zone` で分離する
- Terraform の `TF_VAR_*` は repo root の `.envrc` で読み込む運用。子ディレクトリで直接作業する場合は direnv hook が必要で、必要なら子 `.envrc` から `source_env ../../.envrc` のように親を読む
- `blog-stg.panda-dev.net` のような staging 公開は Cloudflare Tunnel だけでは外部遮断できないため、Zero Trust Access で認証を必須にする。Account スコープの Access Application / Policy は `zero_trust/` で管理する

## Cache Rule の注意

- `http_request_cache_settings` は既存 ruleset があると新規作成できない
- 既存管理に切り替えるときは `terraform import` を使う

例:

```bash
terraform import cloudflare_ruleset.no_cache zones/<zone_id>/<ruleset_id>
```
