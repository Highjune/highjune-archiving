# Sprint 7 (운영 준비 + 테스트) — 과거 기수(8~13기) 멘토 리뷰 인사이트

> 수집일: 2026-10-07. `codeit-bootcamp-spring/{8..13}-sprint-mission` sprint7 PR 멘토 리뷰를 병렬 에이전트로 수집·통합.
> **8기 Highjune 본인 담당**: #64/#68/#69/#71/#72 — 특히 #68·#69·#71·#72의 **테스트 철학 장문 총평**이 재사용 핵심 자산.

## 미션 7 컨텍스트 (전 기수 동일)

**운영 준비(Production-Readiness) + 테스트**: 프로파일 분리(dev/prod/test), 로깅(@Slf4j + logback-spring.xml, `.logs` 롤링 30일), 예외 고도화(ErrorCode enum + DiscodeitException 계층 + ErrorResponse), Bean Validation(@Valid), Actuator(health/info/metrics/loggers), 테스트 3층(Mockito 단위 / @WebMvcTest·@DataJpaTest 슬라이스 / @SpringBootTest 통합). 심화: MDC requestId, Spring Boot Admin, JaCoCo(서비스 60%+).

## 공통 리뷰 테마 (빈도순)

### 1. 설정·민감정보 — 전 기수 최다 빈출
- prod DB 자격증명 하드코딩 금지 → `${DB_URL}` 환경변수 (8기 hagyutae 4건, 9기 #145/#154, 10기 다수, 11기 #145, 12기 #108, 13기 #116)
- **`spring.profiles.active: dev` 하드코딩 금지** → `SPRING_PROFILES_ACTIVE` 주입 ("운영 배포 시 실수로 dev 활성화 위험" — 10기 #228)
- **Actuator info에 인프라 정보(datasource URL 등) 노출 주의**, `show-details: always`·`info.env.enabled: true`는 dev 전용 (10기 #243, 11기 #150, 13기 #116 "prod에선 show-details: never, env.enabled: false")
- **info의 spring-boot 버전이 build.gradle과 불일치** — 하드코딩 금지 (8기 hagyutae #63/#65/#66)
- bind trace 로그는 바인딩 값(비밀번호 해시 등) 전부 노출 — prod 금지 (12기 #103, 13기 #116)

### 2. 예외 처리 설계
- **ErrorCode enum에 HttpStatus 내장** → 핸들러 분기 제거 (9기 #149/#159, 13기 jinho-yoo-jack 5건 반복 — "HTTP 상태 + 커스텀 코드 U001 병행"). 반대 관점도 존재: "service의 ErrorCode가 HTTP를 아는 건 모순" (11기 #154) — 토론 거리
- **Exception.class 최후 방어선** 필수 — 없으면 NPE 등이 Spring 기본 에러로 (12기 #103/#108, 13기 #120)
- e.getMessage() 그대로 노출 금지 — 내부 정보 유출, 상세는 로그로만 (10기 #243, 11기 #154, 12기 #108)
- 남은 NoSuchElementException/orElseThrow 기본 예외까지 커스텀으로 완전 통일 (전 기수)
- cause 받는 생성자 없으면 원인 스택 유실 (12기 #108) / 예외 계층 오염(ChannelNotFound가 UserException 상속) (8기 #63/#65)
- HTTP 의미론: 로그인 실패 401(400 아님), NOT_FOUND에 409 금지 (10기 #241/#234, 13기 #118 P3)
- Validation 오류 수집 Map 키 중복 → 마지막 메시지만 남음 → `Map<String, List<String>>` (13기 the-eris-net P2 템플릿 4건)

### 3. 로깅 실천
- **4xx=WARN / 5xx=ERROR 레벨 구분** (8기 #63/#66, 10기 #224/#241, 11기 #163, 12기 #108)
- 민감정보 로그 금지: request 통째 로깅 시 비밀번호 평문 (9기 #159), 메시지 content 대신 ID·메타만 (8기 #63/#67)
- 핸들러에서 응답만 만들고 로그 안 남기는 패턴 지적 (9기 #154) / 전 요청 로깅은 비용 폭증 — 중요 구간 선별 (12기 #103)
- 로그는 영어 권장(인코딩·검색) (9기 #154) / MDC는 slf4j의 MDC여야 %X가 동작 (8기 #63) / requestId 8자는 충돌 — 12자+ (9기 #152)

### 4. 테스트 — Highjune 본인 철학 (8기 #68/#69/#71/#72 총평, 재사용 1순위)
- "private 메서드를 테스트하고 싶은 유혹이 들면 → 객체로 분리해 public으로 만든 뒤 테스트"
- "fixture에 빌더 모아두기 비추 — 수십 개로 불어나 관리 불능. 테스트 클래스마다 private으로" / "테스트 data.sql 비추 — given절 파편화로 테스트의 문서 기능 상실" (※ 9기 bellman66은 반대로 Fixture 권장 — 관점 차이)
- "@BeforeEach는 ①몰라도 이해에 지장 없고 ②수정해도 전 테스트에 무영향일 때만"
- "@WebMvcTest 중복(MockMvc·ObjectMapper) → ControllerTestSupport 추상 클래스"
- "@Transactional 롤백보다 @AfterEach deleteAll — 프로덕션 코드의 @Transactional 누락을 테스트가 잡아낸다"
- "@DataJpaTest보다 @SpringBootTest — 컨텍스트 2개 뜨는 비용이 더 크다"

### 5. 테스트 — 타 기수 공통
- **@EnableJpaAuditing은 별도 Config 분리 + @Import(JpaAuditingConfig)가 모범답안** (10기 #233, 11기 #163 — 메인 클래스에 두면 슬라이스 깨짐)
- Thread.sleep으로 시간 순서 보장 금지 → Clock 주입/createdAt 직접 설정 (10기 #228/#217, 11기 #150)
- 성공 케이스만 X — 실패 정책 + "저장되면 안 된다"는 부수효과 미발생 검증 (11기 #162 — 테스트 철학 최고 깊이)
- 명명 규칙: MethodName_State_Expected / should_when / given_when_then 중 택1 일관 (13기 jinho-yoo-jack 3건)
- verify 횟수 검증, ErrorCode·message까지 검증 (12기 #103, 13기 #115)
- "테스트 작성했다고 썼는데 diff에 src/test가 없다" — 제출물 커밋 검증 (8기 #70)

### 6. Validation
- @NotBlank는 CharSequence 전용 — UUID/Instant엔 @NotNull (9기 #145, 8기 #70)
- @Size만으론 null/빈문자 못 막음 — @NotBlank 병행 (9기 #159)
- DTO에 제약 없으면 @Valid 무의미 / 컨트롤러에 @Valid 없으면 DTO 제약 무의미 — 양쪽 다 확인 (8기 #67, 10기 #230)

### 7. 반복 로직 버그 (기수 불문 동일 패턴)
- **update 시 자기 자신 중복검사 미제외** → 본인 이름/이메일로 중복 에러 (9기 #145/#150, 10기 #243/#241/#240/#230 — 6건!)
- ReadStatus update가 null일 때만 갱신 — 논리 반전 (8기 #67)
- 비밀번호 평문 저장/비교 → BCrypt (9기 #150/#159 P1, 10기 #228, 11기 #158)

### 8. 기타
- Mapper의 Repository 주입 금지(N+1) — sprint6부터 이어지는 단골 (8기 #67, 10기 #241/#224, 11기 #158)
- 트랜잭션-파일 정합성: 롤백 시 고스트 파일 → 커밋 후 확정/보상 삭제, 심화는 Pre-signed URL (11기 #145/#162, 10기 #234)
- 채널별 최신 메시지 루프 N+1 → GROUP BY+MAX 한 방 (10기 #228)
- 클래스 @Transactional(readOnly=true) + 쓰기만 override (8기 #71/#72 Highjune)
- 빌드 산출물·로그파일·.idea 커밋 금지 — "PR에 600개 파일!" (8기 #69 Highjune)
- logback totalSizeCap, prod 콘솔 전용(수집기 전제) 등 운영 디테일

## 리뷰 스타일 참고
- Highjune(8기): APPROVED + 장문 테스트 철학 총평 + 실무 관점 인라인
- 9기 joonfluence / 13기 the-eris-net: P1~P5 우선순위 라벨 (수강생이 "P1 반영" 형식으로 응답하는 문화)
- 10기: 요구사항 체크리스트 대비 전수 리뷰 + 4포인트 구조화 총평
- 13기 라벨: 매운맛🔥/순한맛🐑/미완성⚒️/지각제출⏰
