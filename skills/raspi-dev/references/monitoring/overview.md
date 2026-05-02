# monitoring

## 概要

- パス: `/home/kamiy2743/workspace/monitoring`
- リポジトリ: `git@github.com:kamiy2743/pi-monitoring.git`
- 目的: Raspberry Pi 5 のホストリソースと Docker ディスク使用量を Prometheus + Grafana + node_exporter で監視する
- 構成: Docker Compose で `node_exporter`, `prometheus`, `grafana`, `disk_usage_collector`, `compose_docker_usage_collector` を動かす

## 公開方針

- Grafana と Prometheus は LAN に直接公開せず、compose の ports は `127.0.0.1` bind にする
- Windows から見る場合は SSH トンネルを使う
- Grafana admin password は `.env` ではなく `secrets/grafana_admin_password` の Docker secret で管理する
- `compose_docker_usage_collector` は `/var/run/docker.sock` を使うため権限が強い。外部公開用途へ流用しない

## 主要ファイル

- `docker-compose.yml`: 監視スタック本体
- `prometheus/prometheus.yml`: `prometheus:9090` と `node_exporter:9100` の scrape 設定
- `grafana/provisioning/datasources/prometheus.yml`: Grafana datasource。dashboard JSON に合わせて datasource 名と uid は `prometheus`
- `grafana/provisioning/dashboards/`: Grafana dashboard provisioning。`Raspberry Pi Overview` を提供する
- `scripts/collect-disk-usage.sh`: 主要ディレクトリ使用量を `pi_directory_usage_bytes` として textfile collector へ出す
- `scripts/collect-compose-docker-usage.sh`: compose project ごとの Docker 使用量を `pi_compose_docker_usage_bytes` として出す
- `secrets/grafana_admin_password`: Grafana admin password。Git 管理しない

## 動作

- `node_exporter` は `pid: host` と `/:/host:ro,rslave` を使い、ホストの CPU、メモリ、ディスク、ネットワークメトリクスを公開する
- `node_exporter` は textfile collector で `collector_tmp_metrics` volume の `.prom` ファイルも読む
- `disk_usage_collector` は `/`, `/home`, `/var`, `/usr`, `/var/lib/docker` 配下などを `du -skx` で測り、ディレクトリ別ディスク使用量を出す
- `compose_docker_usage_collector` は Docker socket と compose label を使い、project ごとの `container_rw`, `images`, `volumes`, `total` を出す
- `collector_tmp_metrics` volume は collector から node_exporter への一時メトリクス受け渡し用で、長期保存用ではない
- `prometheus` は `node_exporter:9100` と `prometheus:9090` を scrape し、保持期間は `--storage.tsdb.retention.time` で管理する
- `grafana` は provisioning で datasource と dashboard を作成し、CPU、メモリ、ディスク、ネットワーク、ディレクトリ別使用量、compose 別 Docker 使用量を表示する
- compose 別 Docker 使用量の `images` は project 間で共有 layer がある場合に重複計上され得る。実ディスク逼迫は `/var/lib/docker` 全体、project 別は目安として見る

## 操作

起動:

```bash
cd /home/kamiy2743/workspace/monitoring
docker compose up -d
docker compose ps
```

Windows から確認:

```powershell
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 kamiy2743@kamiy2743-2.local
```

- Grafana: `http://127.0.0.1:3000`
- Prometheus: `http://127.0.0.1:9090`

collector メトリクス確認:

```bash
curl -s 'http://127.0.0.1:9090/api/v1/query?query=pi_directory_usage_bytes'
curl -s 'http://127.0.0.1:9090/api/v1/query?query=pi_compose_docker_usage_bytes'
```
