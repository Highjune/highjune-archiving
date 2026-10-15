# coupon-site — 마이리얼트립 쿠폰·할인코드 어필리에이트 사이트

- 시작: 2026-10-15 (기획)
- 벤치마크: couponpin.co.kr/myrealtrip-promotion-code (마케팅파트너 131094, 개인 유형, 월 수수료 100만~150만원, 투어 상품 비중 80%)
- 수익 모델: 마이리얼트립 마케팅파트너 마이링크(CPS). 검색 유입 → 쿠폰 가이드 → 마이링크 클릭 → 7일 내 예약 귀속
- 홈서버 인프라: `../tennis-record-k/architecture/home-server-architecture.md` (SSOT)

## 확정 사항

| 항목 | 결정 | 이유 |
|---|---|---|
| 파트너 가입 유형 | 개인 (PERSONAL), 실명, 개인 gmail | 사업자등록 없음. 가입 후 유형 변경 불가·수익 발생 후 전환 불가 |
| 페이지 | **Spring Boot 4.1 + Kotlin + Thymeleaf (SSR)** | 쿠폰을 DB 데이터로 관리(만료 자동 숨김, 월 표기 자동), admin으로 배포 없이 수정, 클릭 로그 1일차부터. 정적(Astro)은 2026-10-15 폐기 |
| 서빙 | 홈서버 nginx `server_name couponnote.kr` → `proxy_pass 127.0.0.1:8081` (couponnote-api 컨테이너) | 테니스 앱과 동일 패턴 |
| 레포 | `Highjune/couponnote` (public). 모듈 core/domain/infrastructure/application/api + dto/client, api만 배포 | mrt3-ad·marketing-partner 와 같은 방향 `api → application → infrastructure → domain → core`. client는 mrt3-payment식 SDK(연습용, 소비자 후보: tennis-record-k) |
| DB | 기존 `tennis-mysql`에 논리 DB `coupon` + 전용 계정 | 컨테이너 추가 없이 스키마·권한만 분리 |
| 배포 | GitHub `release` 푸시 → Jenkins → bootJar·테스트 → DockerHub `highjunea37/couponnote-api` → compose up | 테니스 앱과 동일 파이프라인 |
| 도메인 | **couponnote.kr** (호스팅케이알, 2026-10-15 구매, 14,000원/년, 자동연장). DNS는 Cloudflare로 이전 예정 | `.com`은 2011년부터 타인 보유(미사용). 경쟁자도 대부분 짝 TLD 없음 |
| 속도 원칙 | 페이지 단위 Caffeine 캐시 5분(사용자별 내용 없음 → 100% 적중). SSR이지만 크롤러엔 정적과 동일 | TTFB·가용성만 관리 |
| 클릭 로그 | 파트너페이지는 일반 마이링크 클릭수를 안 줌(다이나믹 배너만). `/go/{id}`로 자체 기록 → 파트너페이지 "링크 ID별 수익" 엑셀과 조인해 버튼별 전환율 | 파트너페이지는 공개 포털이라 퇴사와 무관 |

## TODO

### Phase 0. 서버 정리
- [ ] 모뎀 포트포워딩에서 `3306`, `8080` 규칙 삭제 (MySQL 공인 노출 차단)
- [ ] 공유기 고정 IP 설정 (정전 후 포워딩 깨짐 방지)
- [x] SSH 키 등록 (2026-10-15, `ssh snt`) — `PasswordAuthentication no`는 Tailscale 후
- [x] Jenkins `JAVA_OPTS=-Xmx1g` (2026-10-15, 4.8GB → 0.44GB)
- [x] tennis-mysql compose `ports`를 `127.0.0.1:3306:3306`으로 (2026-10-15, 외부 closed 확인)
- [x] nginx `server_name` 옛 IP 제거, sudo NOPASSWD (2026-10-15)
- [ ] Tailscale 설치 (맥북·미니PC) → 22번 포워딩도 삭제 가능

### Phase 1. 도메인·정적 사이트 (MVP)
- [x] 도메인 구매 couponnote.kr (2026-10-15)
- [x] Cloudflare 네임서버 이전 (2026-10-15, athena/nero.ns.cloudflare.com, A → 홈서버 IP, DNS only)
- [ ] 홈서버 Cloudflare DDNS 갱신 스크립트 (cron 5분)
- [ ] 마케팅파트너 가입 (개인·실명·gmail, SNS 주소 = coupon 도메인)
- [ ] 마이링크 발급: 메인, 쿠폰팩 프로모션, 투어 카테고리, 숙소, 항공 (t_scope 7일)
- [x] Spring 뼈대 (2026-10-15): 엔티티·페이지·/go 리다이렉트·캐시·Dockerfile·Jenkinsfile·schema.sql, 스모크 테스트 4건 통과
- [x] tennis-mysql에 `coupon` 스키마·계정 생성 (2026-10-15)
- [x] 홈서버 `/home/highjune/services/couponnote/` compose + .env (2026-10-15)
- [x] nginx `couponnote.kr` server 블록 + certbot (2026-10-15, https 발급 완료)
- [x] Jenkins 잡 couponnote-pipeline (2026-10-15, HTTPS 익명 clone). release 푸시 → 빌드 #1 SUCCESS
- [ ] **첫 배포 검증**: 빌드 직후 홈서버 외부 접속 두절 → 집에서 확인 필요 (home-server-architecture.md 7-1)
- [ ] admin 화면(쿠폰·글 편집, 캐시 무효화) — 그 전까지는 DB 직접 편집
- [ ] 핵심 글 1: "마이리얼트립 할인코드·쿠폰 총정리 (YYYY년 M월)" — 쿠폰팩 → 카드사 할인표 → 여행지별 쿠폰 → 항공 프로모션 → FAQ
- [ ] 보조 글: 신규회원 혜택 / 취소·환불 규정 / 클룩·KKday 비교 / 항공권 카드할인
- [ ] 네이버 서치어드바이저·구글 서치콘솔 등록, 사이트맵 제출
- [ ] 파트너페이지 수익현황 주간 확인 루틴

### Phase 2. 동적 기능 (API 서버 + coupon DB)
- [ ] `coupon` 논리 DB·계정 생성, API 서버 컨테이너를 `app-network`에 연결
- [ ] **클릭·전환 로그**: 버튼 클릭 시 `sendBeacon`으로 기록 → 파트너페이지 수익과 대조해 글·버튼별 전환 파악
- [ ] **쿠폰 자동 수집**: 마이리얼트립 프로모션 페이지 주기 수집 → 쿠폰·만료일 갱신 → 정적 리빌드 트리거
- [ ] **쿠폰 만료·신규 알림 구독**: 이메일 입력 저장 + 발송
- [ ] **동적 배너·A/B**: 초기 HTML엔 기본 배너, 렌더 후 JS가 교체 (LCP 영향 없게)
- [ ] **여러 플랫폼 확장**: 클룩·아고다·트립닷컴 쿠폰 데이터화 (수기 마크다운 한계 넘으면)

### Phase 3. 운영
- [ ] 구글 검색광고 소액 테스트 (글이 자리 잡은 뒤 1~2개월 후)
- [ ] 모니터링 스택(Prometheus/Loki/Grafana)에 coupon API·nginx 로그 포함
- [ ] snt-app·coupon-api 로그를 JSON 구조화 포맷으로 통일 (`logging.structured.format.console=ecs`, Spring Boot 3.4+) → promtail `json` 스테이지로 `level` 라벨 추출. 스택트레이스 한 줄화

## 참고
- 수수료율 실측(파트너 131094, 2026-06~10): 투어 5~6%, 숙소 2%, 기차패스 2%, 항공 0.5% → 글의 추천 동선은 투어 중심
- 마케팅파트너 귀속 제외: `@myrealtrip.com` 가입자·법인회원(삼성 등 제휴법인) 예약은 마이링크를 타도 귀속되지 않음
- 정산: 월 10만원 초과 시 익월 25일, 미만은 6개월 이월. 개인 파트너는 매월 5~10일 파트너페이지에서 "정산 확인" 필수
- SNS 주소 추가·변경은 파트너페이지에 화면이 없고 `marketing_partner@myrealtrip.com` 메일 요청으로 처리
