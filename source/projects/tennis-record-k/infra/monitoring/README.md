# 홈서버 모니터링 스택 (Grafana + Prometheus + Loki)

서버 경로 `/home/highjune/services/monitoring`. 이 폴더가 원본이고 서버에는 `scp`로 복사한다. 설계·접근 경로는 [architecture/home-server-architecture.md §6-3](../../architecture/home-server-architecture.md).

```
docker-compose.yml                 prometheus · loki · alloy · grafana · node-exporter · cadvisor
prometheus/prometheus.yml          수집 대상 (snt-app:8090, couponnote-api:8081, node, cadvisor)
loki/loki-config.yml               단일 프로세스, 로컬 디스크, 30일
alloy/config.alloy                 docker 로그 → app(snt-app→tennis, couponnote-api→couponnote, highnance-alert→highnance, …)/level(ECS JSON 중첩·평탄, 파이썬 logging) 라벨 → Loki
grafana/provisioning/              데이터소스(uid prometheus, loki) · 대시보드 폴더 "홈서버"
grafana/dashboards/*.json          home-apps-overview(직접 작성) + community-4701/1860/14282 (서버에서 내려받아 치환, 레포엔 없음)
.env.example                       GF_SECURITY_ADMIN_PASSWORD — 실제 .env는 서버에만 (600)
```

## 운영

- 시작/갱신: `cd ~/services/monitoring && docker compose up -d` (설정만 바꿨으면 `docker compose restart <서비스>`; prometheus.yml은 `curl -X POST localhost:9090/-/reload`도 가능)
- 접속: 집 WiFi `http://192.168.35.122:3000` / 밖 `ssh -L 3000:192.168.35.122:3000 highjune@snt.o-r.kr` → `http://localhost:3000`. 계정 `highjune`, 비밀번호 `cat ~/services/monitoring/.env`
- 대시보드 수정: Grafana UI에서 고친 뒤 JSON 내보내기 → `grafana/dashboards/`에 저장 → scp. 프로비저닝 파일은 30초마다 다시 읽는다
- 커뮤니티 대시보드 재설치: `curl -sL https://grafana.com/api/dashboards/<id>/revisions/latest/download -o community-<id>.json` 후 `${DS_PROMETHEUS}` 문자열을 `{"type":"prometheus","uid":"prometheus"}` 객체로 치환
- 디스크: 볼륨 `monitoring_prometheus-data`, `monitoring_loki-data`, `monitoring_grafana-data`. 보관 30일이라 수백 MB 수준
