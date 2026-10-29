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
- [x] 마케팅파트너 가입 (2026-10-16, 개인 gmail 계정. 어필리에이트 메뉴 활성, 신분증·계좌 서류 유효, 정산 계좌 등록 → 운영팀 확인 대기) — 가입 URL `partner.myrealtrip.com/welcome/marketing_partner`
- [ ] 마파 오픈채팅방 입장(월별 코드 소스) + 국내숙소팀 특가 공지 채널 상시 확인
- [x] 마이링크 발급 1차 (2026-10-16): 홈(상시 코드 3개 공용)·휘닉스파크·뉴시즈 해운대. **발급은 사용자가 파트너페이지 UI에서 직접**(API 직접 호출 금지). 규칙: 랜딩 URL 1개 = 마이링크 1개, 받은 주소는 `curl -sI`로 301 대상(`mylink_id`, `t_scope=604800`) 확인 후 `coupons.target_url`에, 원본은 `landing_url`에
- [x] `coupons.landing_url`(원본 URL) 컬럼 추가 + 운영 ALTER, 특가 EVENT 행 2건(뉴시즈 ~10/20 노출 중, 휘닉스 10/27~29 자동 노출) (2026-10-16, 빌드 #5)
- [x] Spring 뼈대 (2026-10-15): 엔티티·페이지·/go 리다이렉트·캐시·Dockerfile·Jenkinsfile·schema.sql, 스모크 테스트 4건 통과
- [x] tennis-mysql에 `coupon` 스키마·계정 생성 (2026-10-15)
- [x] 홈서버 `/home/highjune/services/couponnote/` compose + .env (2026-10-15)
- [x] nginx `couponnote.kr` server 블록 + certbot (2026-10-15, https 발급 완료)
- [x] Jenkins 잡 couponnote-pipeline (2026-10-15, HTTPS 익명 clone). release 푸시 → 빌드 #1 SUCCESS
- [x] 첫 배포 검증 (2026-10-15 저녁 복구 확인. 서버 무재부팅, 네트워크 일시 장애로 추정)
- [x] 브랜드 카테고리(TRAVEL/SHOPPING/SUBSCRIPTION) + `coupons.featured` 컬럼, 운영 ALTER 적용 (2026-10-15)
- [x] 운영 데이터 1차: 마이리얼트립 + 파트너 전용 코드 PACKMKTP1000/3000/5000 (2026-10-15, target_url은 마이링크 발급 전까지 MRT 홈)
- [x] 디자인 1차(쿠폰 카드, 코드 복사+이동 버튼, 히어로, about, 파비콘·og) + 정적 리소스 콘텐츠 해시 버저닝 (2026-10-15)
- [x] 상단 티커(쿠폰핀과 동일 문구) → DB 기반 상태바(오늘 유효 쿠폰 수·마감 임박 D-day) 교체 (2026-10-16, 빌드 #6)
- [ ] 디자인 2차: 색은 **틸네이비(A)** 확정, 레이아웃 후보 3개(에디토리얼/코드우선 리스트/티켓)·여행 아이콘 후보(이모지/틸 라인/네이비 라인) 중 선택 대기 → 로고·파비콘·og 틸로 재생성, D-day·NEW 뱃지
- [ ] www CNAME(Cloudflare) 추가 → certbot `--expand` + nginx www→apex 301
- [ ] 소개 페이지 연락처: gmail 생성 후 서버 `.env`의 `CONTACT_EMAIL` 교체 (후보 couponnote.kr@gmail.com)
- [ ] admin 화면(쿠폰·글 편집, 캐시 무효화) — 그 전까지는 DB 직접 편집. **수동 입력 시 `--default-character-set=utf8mb4` 필수**(latin1로 들어가면 한글 깨짐, 10/15 실제 발생)
- [ ] 핵심 글 1: "마이리얼트립 할인코드·쿠폰 총정리 (YYYY년 M월)" — 쿠폰팩 → 카드사 할인표 → 여행지별 쿠폰 → 항공 프로모션 → FAQ
- [ ] 보조 글: 신규회원 혜택 / 취소·환불 규정 / 클룩·KKday 비교 / 항공권 카드할인
- [ ] 네이버 서치어드바이저·구글 서치콘솔 등록, 사이트맵 제출
- [ ] 파트너페이지 수익현황 주간 확인 루틴 — EDW 파트너 테이블은 T-1 배치라 10/17 이후 partner_id 확인 가능
- [ ] 운영 루틴: 오픈채팅 특가 공지 → 사용자가 프로모션 URL로 마이링크 발급 → EVENT 행 INSERT(starts/ends_at으로 자동 노출·숨김) → 판매 시작 1주 전 보조 글

### Phase 2. 동적 기능 (API 서버 + coupon DB)
- [ ] `coupon` 논리 DB·계정 생성, API 서버 컨테이너를 `app-network`에 연결
- [ ] **클릭·전환 로그**: 버튼 클릭 시 `sendBeacon`으로 기록 → 파트너페이지 수익과 대조해 글·버튼별 전환 파악
- [ ] **쿠폰 자동 수집**: 혜택탭 API(`traveler/promotions/v3`, `traveler/couponPack/v1/publish`) + 마파 공식 블로그 RSS(`rss.blog.naver.com/myrealtrip_mpartner.xml`) 폴링 → 새 혜택 알림
- [ ] **쿠폰 만료·신규 알림 구독**: 이메일 입력 저장 + 발송
- [ ] **동적 배너·A/B**: 초기 HTML엔 기본 배너, 렌더 후 JS가 교체 (LCP 영향 없게)
- [ ] **여러 플랫폼 확장**: 클룩·아고다·트립닷컴 쿠폰 데이터화 (수기 마크다운 한계 넘으면)

### Phase 3. 운영
- [ ] 구글 검색광고 소액 테스트 (글이 자리 잡은 뒤 1~2개월 후)
- [ ] 모니터링 스택(Prometheus/Loki/Grafana)에 coupon API·nginx 로그 포함
- [ ] snt-app·coupon-api 로그를 JSON 구조화 포맷으로 통일 (`logging.structured.format.console=ecs`, Spring Boot 3.4+) → promtail `json` 스테이지로 `level` 라벨 추출. 스택트레이스 한 줄화

## 벤치마크·수집 채널 (2026-10-15 조사)

- **쿠폰핀 구조**: WordPress(GeneratePress) + 손으로 매월 1일 갱신(같은 URL, 제목 월·코드·기간만 교체). 글 순서: 할인코드 → 할인쿠폰 → 항공 카드할인 → 숙소/투어 간편결제 → 항공 프로모션 → 면세점·그랩 → FAQ
- **쿠폰 데이터 출처 3곳**: ① 마파 카카오 오픈채팅방 공지(상시 코드 `PACKMKTP1000/3000/5000` + 월별 이벤트 코드) ② 마리트 혜택탭 `/promotions/benefit`(쿠폰·카드사·간편결제·항공 프로모션) ③ 마파 공식 블로그(월 1건). 사내 매니저 쿠폰 템플릿은 보지 않는다(공개 채널만)
- **수익은 마이링크 클릭 귀속에서만** 발생. 코드 자체는 귀속 없음 → 모든 버튼은 코드 복사 + 마이링크 이동을 동시에
- **9월 마파 수익 분포**(정산 테이블): 수익 발생 4,290명 중 100만↑ 42명(1%). 쿠폰핀 154만 = 29위. 상위권은 상품 큐레이션 네트워크(1위 4,974만, 월 30만 클릭)·링크프라이스 리셀러·네이버 카페·여행사·다이나믹 배너이며 쿠폰 사이트 모델은 비마이피스(7위 876만, 도메인 3개 goda-trip.com/love-trip.co.kr/korea-tripcode.com, 도착지 82% 프로모션)와 쿠폰핀뿐
- **클릭당 수익(수익÷클릭, 지급 단가 아님)**: 쿠폰 사이트 800~1,600원 vs 상품 큐레이션 170~480원. 쿠폰 검색 의도 트래픽이 전환이 높다 → 우리 게임은 트래픽(SEO). 월 2천 클릭 ≈ 쿠폰핀, 5천 ≈ 비마이피스
- 쿠폰핀 구글 광고는 9월 클릭 291건 중 `gclid` 5건 → 소액 테스트 수준. referer 없는 65%는 `rel=noreferrer` 버튼 때문이라 사실상 쿠폰핀 페이지 클릭
- 분석 테이블: `edw.DW_MRT_SETTLES_PARTNERSHIP_SETTLEMENT_PRODUCT_CLOSING`(partnership_type=MARKETING), `edw.DW_MRT_PARTNERS_MYLINK` → `edw.DW_MRT_COMMONS_SHORT_URL_REFERER`(클릭·referer) / `DW_MRT_COMMONS_SHORT_URL`(target_url_web). 구형 `MARKETING_ADVERTISING_LINK_REFERER`는 2024-06에 중단

## 참고
- 수수료율 실측(파트너 131094, 2026-06~10): 투어 5~6%, 숙소 2%, 기차패스 2%, 항공 0.5% → 글의 추천 동선은 투어 중심
- 마케팅파트너 귀속 제외: `@myrealtrip.com` 가입자·법인회원(삼성 등 제휴법인) 예약은 마이링크를 타도 귀속되지 않음
- 정산: 월 10만원 초과 시 익월 25일, 미만은 6개월 이월. 개인 파트너는 매월 5~10일 파트너페이지에서 "정산 확인" 필수
- SNS 주소 추가·변경은 파트너페이지에 화면이 없고 `marketing_partner@myrealtrip.com` 메일 요청으로 처리
