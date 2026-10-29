# 2026-10-29 홈서버 모니터링 구축 (Grafana + Prometheus + Loki)

**관련**: tennis-record-k PR #24 (10/29 20:44 머지·배포) · archiving `infra/monitoring/` · 설계 그림 https://claude.ai/artifact/6YPwJmKub2kom7wN2beGqn

## 1. 배경·결정

- 요구: 테니스·쿠폰노트 두 앱을 **Grafana 한 화면**에서 지표+로그로 보기
- "Grafana/Prometheus vs ELK": 지표↔로그는 보완 관계. 실질 선택은 Loki vs Elasticsearch이고, 앱 2개·홈서버엔 Loki(라벨 색인, 수백 MB)가 맞음. ES는 힙 2~4GB. 필요해지면 Grafana 데이터소스로 ES만 추가
- Loki도 **저장소**(로그 줄), Prometheus는 지표 저장소, Alloy는 옮기기만, Grafana는 읽기만
- 접근은 새 포트를 인터넷에 열지 않고 Grafana를 LAN 주소에만 바인딩. 집에서는 직접, 밖에서는 SSH 터널(DB와 동일)

## 2. 한 일

| 단계 | 내용 |
|---|---|
| 테니스 앱 | PR #24: actuator + micrometer-prometheus, `health,prometheus`만 노출, `application=tennis`, http 히스토그램, beta ECS JSON 로그. 테스트 통과, 로컬 bootRun으로 지표 281줄 확인. 20:4x "머지해줘" → release에 merge 커밋, main은 ff로 동기화, feature 브랜치 삭제. Jenkins pollSCM → 20:44 컨테이너 재생성 → Prometheus `tennis` UP |
| nginx | 두 vhost `location ^~ /actuator/ { return 404; }` — 그동안 `couponnote.kr/actuator/prometheus`(27KB)가 인터넷에 열려 있었음. 외부 404, 사이트 200 확인 |
| 로그 로테이션 | 앱 compose 2개 `json-file 10m × 3`, 컨테이너 재생성 |
| 모니터링 compose | `services/monitoring`: prometheus v3.4.1 · loki 3.5.0 · alloy v1.9.0 · grafana 12.0.0 · node-exporter v1.9.1 · cadvisor v0.52.1. Prometheus만 app-network에 추가 참여. Grafana `192.168.35.122:3000`, admin `highjune`, 비밀번호 `.env`(600) |
| 대시보드 | 직접 작성 `홈서버 앱 개요` (app 드롭다운, 19패널) + 커뮤니티 4701/1860/14282 파일 프로비저닝 |
| 검증 | 타깃 5개 UP(tennis는 배포 후), Loki `app` 라벨 6종(highnance 포함), Grafana 경유 PromQL·LogQL 조회 OK, Loki `app` 라벨 5종, 메모리 합계 ≈ 420MB |
| 문서 | archiving README(구성도·포트 표·모니터링 단락), 아키텍처 §6-3, `infra/monitoring/README.md`, 테니스 README 한 줄(PR 포함) |

## 3. 삽질·발견

- Alloy `stage.json`: **Boot 버전별 ECS 키 모양이 다름**. 쿠폰노트(Boot 4) `{"log":{"level":"WARN"}}` 중첩 → JMESPath `log.level`, 테니스(Boot 3.4.5) `{"log.level":"INFO"}` 평탄 → `"log.level"`(따옴표 식별자). 처음엔 중첩만 잡아 테니스 `level` 라벨이 비었음 → 둘 다 추출해 `stage.template`(`{{ if .level_nested }}…{{ else }}…{{ end }}`)으로 합치고 alloy 재기동. 이후 tennis=INFO/ERROR, couponnote=WARN 확인
- 앱 재배포 시 Alloy가 옛 컨테이너 ID를 10초쯤 "No such container"로 찍다가 positions에서 제거 — 정상
- Loki 3.5 `negative structured metadata bytes received` 에러 로그가 주기적으로 찍히나 적재엔 영향 없음(detected_level 관련 노이즈)
- Loki 기동 직후 7일 넘은 옛 컨테이너 로그를 "timestamp too old"로 거부 (1회성, 무해)
- 서버 안에서 `curl https://couponnote.kr`은 헤어핀 NAT로 응답 없음 → ssh 명령이 120초 타임아웃. 외부 확인은 맥북에서
- 쿠폰노트엔 micrometer `application` 태그가 없어 Prometheus static label `application=couponnote`로 보강 (JVM 4701 대시보드 변수용)
- 커뮤니티 4701은 구형 `rows` 포맷(panels 0개) — Grafana가 로드 시 자동 변환
- Jenkins는 compose 파일을 복사하지 않고 서버 디렉토리에서 `compose up`만 하므로 서버 compose 편집이 유지됨
- 테니스 `application.yml` beta 프로필에 DB 비밀번호가 평문으로 남아 있음(private 레포). 환경변수 주입으로 옮길 것

## 4. 남은 것

- [x] PR #24 머지 → Prometheus `tennis` 타깃 UP, `application=tennis` JVM 지표 수집 확인 (10/29 20:44)
- [ ] 공유기 DHCP 고정 할당 192.168.35.122 (grafana 바인딩이 IP에 묶임) — 사용자가 집에서 진행 예정
- 밖에서 보기: 맥 터미널 `highjune-tunnel` → `http://localhost:3000` (아래 §5 참고)
- [ ] 테니스 `8090:8090`·Jenkins `18080`/`50000` `0.0.0.0` 바인딩을 `127.0.0.1:`로 잠글지 결정 (LAN 기기의 nginx 우회·Jenkins 직접 접근 차단. 잠그면 집에서도 터널로만). Grafana는 LAN 유지 권장
- [ ] 알림: Grafana alerting(앱 DOWN, 5xx, 디스크) → 메일 또는 카카오 나에게 보내기
- [ ] 앱 커스텀 지표: 쿠폰노트 `/go` 클릭 카운터, 테니스 경기 입력 카운터
- [ ] 쿠폰노트 PR: `management.metrics.tags.application=couponnote`, http 히스토그램
- [ ] 테니스 yml DB 비밀번호 → 환경변수

## 5. 저녁 후속 (머지 이후, 회사에서)

- **PR #24 머지·배포**: release merge 커밋, main ff. Jenkins pollSCM → 20:44 `snt-app` 재생성 → Prometheus `tennis` UP, `jvm_memory_used_bytes{application="tennis"}` 수집.
- **Alloy level 라벨 2차 수정**: 테니스(Boot 3.4.5)는 평탄 `{"log.level":…}`라 중첩용 JMESPath에 안 잡힘 → `log.level || "log.level"`. 중간에 `stage.template`으로 합쳤다가 비JSON 줄에 `level="<no value>"`가 붙는 걸 보고 `||`로 교체(null은 라벨 안 붙음). 하이낸스 파이썬 로그(`2026-10-29 21:20:12,670 INFO app.poller: …`)는 `stage.regex`로 level 추출. 확인: tennis=INFO/ERROR, couponnote=WARN, highnance=INFO.
- **highnance-alert 편입**: Alloy relabel `highnance-alert → app=highnance`(전엔 infra), 대시보드 `app` 변수를 query(`up` 기반)에서 custom `tennis,couponnote,highnance`로 변경. highnance는 지표가 없어 로그 2패널만 데이터. 서버 파일 + archiving `infra/monitoring/` 미러 동일.
- **Grafana 비밀번호**: 사용자가 기억하기 쉬운 값으로 변경 요청 → `docker exec grafana grafana cli admin reset-admin-password` + `.env` 동기화(600). env 값은 최초 기동 때만 읽히므로 env만 바꾸면 안 바뀜. 값은 문서에 없음.
- **SSH 터널 정리** (맥 로컬 설정, 레포 밖):
  - `~/.ssh/config`: `Host snt highjune`(동일 블록, 별칭 2개) + `Host highjune-tunnel`(LocalForward 3000→192.168.35.122:3000, 18080→localhost:18080, 8090→localhost:8090, 3306→localhost:3306, ServerAliveInterval 30, ExitOnForwardFailure yes). 백업 `config.bak-20261029`.
  - `~/.zshrc`: 함수 `highjune-tunnel`(열고 포트 목록·끊는 법 echo, 이미 열려 있으면 pid만 출력) / `highjune-tunnel-stop` / `highjune-tunnel-status`.
  - 회사망·회사 VPN 상태에서 22만으로 Grafana 302, Jenkins 403(로그인 전), 테니스 302, MySQL 3306 open 확인.
- **설명한 것**: ssh 키 위치(`~/.ssh/id_ed25519_highjune`, 서버 authorized_keys 지문 일치), `-N/-f/-L` 뜻, "localhost:3000이 보이는 이유", 바인딩 주소 `0.0.0.0` vs `192.168.35.122` vs `127.0.0.1` 차이. 현재 쿠폰노트·MySQL만 127.0.0.1, 테니스 8090·Jenkins 18080은 0.0.0.0, Grafana는 LAN IP.
- 사소: 앱 재배포 시 Alloy가 옛 컨테이너 ID로 "No such container" 10초쯤 → 자가 정리. Loki "negative structured metadata bytes" 로그는 노이즈. 이전 템플릿 기간의 `level="<no value>"` 스트림은 30일 후 소멸.
- **app 라벨 `tennis` → `snt-app`** (사용자: 컨테이너명이 더 직관적): Prometheus job/label, Alloy relabel, 대시보드 `app` 변수(custom `snt-app,couponnote,highnance`) 변경 후 alloy·prometheus 재기동. 코드의 micrometer 태그 `application=tennis`(PR #24)는 그대로라 커뮤니티 JVM 대시보드에서는 여전히 `tennis`로 보임. 이전 `app=tennis` 지표·로그는 30일 보관 후 소멸.
- **로그 보관 기간 정리**: Loki 30일(`retention_period: 720h`), Prometheus 30일. Docker 원본 파일은 앱 3개(snt-app, couponnote-api, highnance-alert)만 `10m × 3`, 나머지(mysql, jenkins, 모니터링 6개)는 daemon.json 없음 → 무제한. Alloy는 파일이 아니라 `docker.sock`(ro) 으로 Docker API `containers/{id}/logs?follow`를 구독.
