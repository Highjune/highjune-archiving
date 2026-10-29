# 2026-10-29 홈서버 모니터링 구축 (Grafana + Prometheus + Loki)

**관련**: tennis-record-k PR #24 (미머지) · archiving `infra/monitoring/` · 설계 그림 https://claude.ai/artifact/6YPwJmKub2kom7wN2beGqn

## 1. 배경·결정

- 요구: 테니스·쿠폰노트 두 앱을 **Grafana 한 화면**에서 지표+로그로 보기
- "Grafana/Prometheus vs ELK": 지표↔로그는 보완 관계. 실질 선택은 Loki vs Elasticsearch이고, 앱 2개·홈서버엔 Loki(라벨 색인, 수백 MB)가 맞음. ES는 힙 2~4GB. 필요해지면 Grafana 데이터소스로 ES만 추가
- Loki도 **저장소**(로그 줄), Prometheus는 지표 저장소, Alloy는 옮기기만, Grafana는 읽기만
- 접근은 새 포트를 인터넷에 열지 않고 Grafana를 LAN 주소에만 바인딩. 집에서는 직접, 밖에서는 SSH 터널(DB와 동일)

## 2. 한 일

| 단계 | 내용 |
|---|---|
| 테니스 앱 | PR #24: actuator + micrometer-prometheus, `health,prometheus`만 노출, `application=tennis`, http 히스토그램, beta ECS JSON 로그. 테스트 통과, 로컬 bootRun으로 지표 281줄 확인. **머지는 사용자 지시 대기** |
| nginx | 두 vhost `location ^~ /actuator/ { return 404; }` — 그동안 `couponnote.kr/actuator/prometheus`(27KB)가 인터넷에 열려 있었음. 외부 404, 사이트 200 확인 |
| 로그 로테이션 | 앱 compose 2개 `json-file 10m × 3`, 컨테이너 재생성 |
| 모니터링 compose | `services/monitoring`: prometheus v3.4.1 · loki 3.5.0 · alloy v1.9.0 · grafana 12.0.0 · node-exporter v1.9.1 · cadvisor v0.52.1. Prometheus만 app-network에 추가 참여. Grafana `192.168.35.122:3000`, admin `highjune`, 비밀번호 `.env`(600) |
| 대시보드 | 직접 작성 `홈서버 앱 개요` (app 드롭다운, 19패널) + 커뮤니티 4701/1860/14282 파일 프로비저닝 |
| 검증 | 타깃 4개 UP(tennis는 배포 전이라 DOWN), Grafana 경유 PromQL·LogQL 조회 OK, Loki `app` 라벨 5종, 메모리 합계 ≈ 420MB |
| 문서 | archiving README(구성도·포트 표·모니터링 단락), 아키텍처 §6-3, `infra/monitoring/README.md`, 테니스 README 한 줄(PR 포함) |

## 3. 삽질·발견

- Alloy `stage.json`: ECS 중첩 `log.level`은 JMESPath 경로 `log.level`로. `"log.level"`(따옴표)은 평면 키로 해석돼 `level` 라벨이 비었음
- Loki 기동 직후 7일 넘은 옛 컨테이너 로그를 "timestamp too old"로 거부 (1회성, 무해)
- 서버 안에서 `curl https://couponnote.kr`은 헤어핀 NAT로 응답 없음 → ssh 명령이 120초 타임아웃. 외부 확인은 맥북에서
- 쿠폰노트엔 micrometer `application` 태그가 없어 Prometheus static label `application=couponnote`로 보강 (JVM 4701 대시보드 변수용)
- 커뮤니티 4701은 구형 `rows` 포맷(panels 0개) — Grafana가 로드 시 자동 변환
- Jenkins는 compose 파일을 복사하지 않고 서버 디렉토리에서 `compose up`만 하므로 서버 compose 편집이 유지됨
- 테니스 `application.yml` beta 프로필에 DB 비밀번호가 평문으로 남아 있음(private 레포). 환경변수 주입으로 옮길 것

## 4. 남은 것

- [ ] PR #24 머지(사용자) → Prometheus `tennis` 타깃 UP 확인, JVM 대시보드에 tennis 나오는지
- [ ] 공유기 DHCP 고정 할당 192.168.35.122 (grafana 바인딩이 IP에 묶임)
- [ ] 알림: Grafana alerting(앱 DOWN, 5xx, 디스크) → 메일 또는 카카오 나에게 보내기
- [ ] 앱 커스텀 지표: 쿠폰노트 `/go` 클릭 카운터, 테니스 경기 입력 카운터
- [ ] 쿠폰노트 PR: `management.metrics.tags.application=couponnote`, http 히스토그램
- [ ] 테니스 yml DB 비밀번호 → 환경변수
