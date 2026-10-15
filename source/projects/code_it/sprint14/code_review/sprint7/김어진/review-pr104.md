# 코드 리뷰 — [김어진] sprint7 (PR #104)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/104
- **작성자**: rladjwls02 (김어진), head `rladjwls02:김어진-sprint7` → base `김어진` ✅
- **규모**: +1963 / −105, 63 files
- **라벨**: 성실 + 질문왕📚 — 기본 거의 완주(Controller 슬라이스만 미완·본인 인지), 🔴 3건
- **멘티 질문 4개 + 코드 속 숨은 질문 1개** (UserException 주석 "왜 이렇게 보일러플레이트를?") — 전부 답변 필요
- **참고**: 8~13기 인사이트 (`reference/sprint7-past-cohort-review-insights.md`)

> diff 전체(3067줄) + head raw 검증 완료.

---

## 총평 — 예외 계층·ErrorCode(status+level까지)·검증 메시지·테스트 명명 일관성 등 설계 뼈대가 좋고 질문의 질이 높다. 그러나 🔴 3: ①로그인 실패 응답에 비밀번호 평문 노출 ②통합 테스트 1건이 기대값 오타로 실패(빌드 깨짐) ③수정 시 자기 자신 중복검사 — 전 기수 6번 반복된 그 버그

**잘한 것:**
- **예외 체계 스펙 그대로 3단 계층**: DiscodeitException → 도메인 예외(User/Channel/...) → 구체 예외 + ErrorCode enum. 기존 NoSuchElement/IllegalArgument를 서비스 전 계층에서 커스텀으로 **전면 교체 완료**
- **ErrorCode에 status + 로그 Level까지 설계** (`ErrorCode.java` — slf4j Level 필드) — "예외가 자기 로그 레벨을 안다"는 발상은 13기 멘토 권장 패턴과 동일. 단 핸들러에서 아직 미사용(🟡5)
- **@Valid 전 컨트롤러 + DTO 제약에 한글 메시지 정성** (@NotBlank/@NotNull/@NotEmpty/@Email/@Size min·max)
- **prod 설정 감각**: env var(${DB_URL}), `show-details: never`(prod) vs always(dev) 분리 — 13기 지적 선반영. `profiles.default: dev`(active 하드코딩보다 나은 선택, dev는 localhost뿐이라 기본값=로컬 전용 패턴 충족)
- logback `totalSizeCap 5GB`(김예준도 없던 디테일) + 일자 롤링 30일 + dev/prod 패턴 분리
- 테스트: `success_`/`fail_` 명명 일관 + BDD 주석 + `returnsFirstArg()` 활용 + 실패 케이스 수반. 단위/슬라이스/통합 3층 × 3도메인
- 헬스체크 스크린샷(DB down 케이스까지)으로 동작 증빙

---

## 🔴 Critical

### 1. 로그인 실패 응답에 비밀번호 평문 노출 — `BasicAuthService.java:31`
```java
throw new InvalidPasswordException(user.getPassword());
```
`InvalidPasswordException(String username)` 생성자인데 **username 자리에 user.getPassword()를 전달** → details = {"username": "<실제 비밀번호>"} → ErrorResponse.details로 **API 응답에 비밀번호가 그대로 나감**. 비밀번호 틀리게 입력해보면 응답 JSON에서 바로 보임. `user.getUsername()`으로 수정. (+원칙: 예외 details에는 식별자·메타만, 비밀번호/토큰은 절대 금지 — 9기 P1 동급)

### 2. 통합 테스트 기대값 불일치 → 테스트 실패(빌드 깨짐) — `MessageIntegrationTest.java:89, 97`
요청은 `"수정 후 메세지입니다."`(:89)인데 검증은 `"수정 된 메세지입니다."`(:97) — 이 테스트는 **항상 실패**. `./gradlew test`를 제출 전에 한 번 돌렸으면 잡혔을 오타. (전체 테스트 스위트 실행 여부 확인 질문)

### 3. 수정 시 자기 자신 중복검사 미제외 — `BasicUserService.java:114, 118`
`existsByEmail(newEmail)` / `existsByUsername(newUsername)` — **자기 자신을 제외하지 않아서**, 이름은 그대로 두고 이메일만 바꾸는(또는 비밀번호만 바꾸는) 요청이 "이미 존재하는 이름" 409로 실패. **9~10기에서만 6개 PR에서 반복된 단골 버그.** `existsByUsernameAndIdNot(username, userId)` / `existsByEmailAndIdNot(email, userId)`로. (+newEmail이 null일 때 existsByEmail(null) 호출도 같이 가드)

## 🟡 Major

### 4. 폴백 핸들러가 내부 정보를 노출하고, 로그는 printStackTrace — `GlobalExceptionHandler.java:21, 29, 70, 73`
- `Exception.class` 핸들러가 `e.getMessage()`를 그대로 body로(:73) — NPE/DB 오류 메시지가 클라이언트에 노출. **500은 고정 문구 + 상세는 로그로만** (10·11·12기 공통 지적)
- `e.printStackTrace()` ×3 — 미션 주제가 "로그 관리"인데 핸들러만 stdout. `@Slf4j` + log.error/warn으로
- 구 핸들러(IllegalArgument/NoSuchElement)는 커스텀 전환이 끝났으니 역할 재정의: 남긴다면 "전환 누락 감지용"으로 log.warn 추가

### 5. ErrorCode의 Level 필드가 미사용 — 설계 완성 한 걸음 전 — `ErrorCode.java:103`, `GlobalExceptionHandler.java:37-46`
레벨까지 enum에 넣은 발상이 좋은데 핸들러가 안 씀. `log.atLevel(errorCode.getLevel()).log(...)` 한 줄이면 "4xx=WARN/5xx=ERROR 구분"(전 기수 지적)이 구조적으로 완성됨. 지금은 서비스마다 수동 log.warn을 중복으로 찍는 중 — 핸들러 한 곳으로 모으면 서비스 쪽 warn 로그 대부분 제거 가능.

### 6. Validation 실패 시 DTO에 정성껏 단 메시지가 응답에 안 담김 — `GlobalExceptionHandler.java:59`
`MethodArgumentNotValidException` 핸들러가 details를 `Map.of()`(빈 맵)로 — "유저 이름을 입력해주세요" 같은 필드 메시지가 전부 유실되고 "올바른 입력이 아닙니다"만 나감. `e.getBindingResult().getFieldErrors()`에서 field→message 수집. **주의: email처럼 제약 2개(@NotBlank+@Email)인 필드는 Map 키 중복으로 하나만 남으니 `Map<String, List<String>>`로** (13기 P2 단골).

### 7. 에러 응답 포맷 혼재
DiscodeitException/Validation → ErrorResponse(JSON), IllegalArgument/NoSuchElement/Exception → String body. 스펙 "일관된 오류 응답" 관점에서 전부 ErrorResponse로 통일.

### 8. Actuator info 인프라 노출 + 버전 하드코딩 — `application.yaml:28-33`
datasource url(prod에선 ${DB_URL} 전체)이 /actuator/info로 노출 + version 1.7.0/spring-boot 4.1.1 하드코딩(올리면 거짓말 됨). info.config 블록은 dev 프로파일로 이동, prod는 `management.info.env.enabled: false`, 버전은 `springBoot { buildInfo() }` 자동 주입. (김예준 PR에도 동일 코멘트)

### 9. test 프로파일에서 CONSOLE appender 미정의 — `logback-spring.xml:10-24, 40`
CONSOLE이 dev/prod springProfile 안에만 정의돼 있는데 root는 항상 CONSOLE 참조 → test로 뜨면 "appender not found" 에러 로그 + 콘솔 로그 유실. CONSOLE 기본 정의 + 패턴만 프로파일 분기, 또는 test용 springProfile 추가.

## 🔵 Minor

- `@DataJpaTest` 3종에 `@ActiveProfiles("test")` 없음 — build.gradle의 `systemProperty`로 gradle 실행 시엔 커버되지만 **IDE에서 단독 실행하면 dev(로컬 postgres)로 붙음**. 명시 권장.
- `@EnableJpaAuditing`을 슬라이스 테스트마다 부착 — 동작은 정답 방향(운영을 끈 김예준과 대비됨!). 더 깔끔한 정석: JpaAuditingConfig 분리 + `@Import` (10·11기 모범답안).
- `ChannelUnitTest` — `@Mock ChannelMapper` 선언해놓고 `new ChannelMapper()` 사용(:2041, 2052) — 미사용 mock 제거. (질문4 답변과 연결)
- `UserSliceTest.success_findAllByPageAndSort` — DisplayName "내림차순"인데 ASC 정렬·검증.
- `BasicUserService.java:47` — 생성 로그에 email 전체 노출(PII). ID·마스킹 권장 (8기 "ID와 메타데이터만").
- 컨트롤러 info "완료" + 서비스 debug "시작/요청" 이중 로깅 — 질문3 답변 참고(한 곳으로).
- Channel public create에 @Transactional 없음 — 단건 save라 동작엔 문제 없으나 질문2 답변 참고.
- `ChannelException.java`에 미사용 import `CodecException`(:281) — 자동 import 실수.

---

## 멘티 질문 답변 5건

### Q1. 매퍼가 DTO 정적 toDto()를 호출만 한다 — 어디에 둬야?
변환 로직이 **한 군데만** 있으면 됩니다. 지금처럼 두 곳(DTO 정적 메서드 + Mapper)에 있는 게 최악이고, 둘 중 선택:
- 단순 변환(필드 옮기기)뿐이면 → record 정적 팩토리로 충분, Mapper 삭제해도 됨
- 변환에 **다른 협력자가 필요해지면**(다른 매퍼 합성, null 정책, 조회 결과 조합) → Mapper 컴포넌트로 이사하고 DTO 정적 메서드 삭제. DI가 되는 쪽이 확장에 유리
- 과제 요구사항이 "Mapper 도입"이므로 이번엔 로직을 Mapper로 옮기고 DTO에서 지우는 쪽 권장. 실무에선 이 고민 자체를 MapStruct가 없애줌.

### Q2. delete(조회 후 삭제)에도 @Transactional이 필요한가?
필요합니다. 기준: **DB 작업이 2개 이상이면 원자성 경계가 필요** — 조회+삭제도 2개고, 어진님 delete는 메시지 첨부→메시지→채널처럼 여러 테이블을 지우니 더더욱(중간 실패 시 반쪽 삭제 — 12기에서 "세 삭제가 각각 별도 트랜잭션이라 메시지만 사라진다" 실사고 지적). 조회 전용이 많은 서비스는 **클래스에 @Transactional(readOnly=true), 쓰기 메서드만 @Transactional override**가 관례입니다(조회:쓰기 ≈ 8:2). readOnly는 변경 감지 스냅샷을 안 만들어 성능 이득 + 실수로 쓰기 방지. 다른 학생들 빈도가 높은 건 이 클래스 레벨 패턴 때문일 거예요.

### Q3. 유즈케이스 흐름 로그 — Controller info? Service debug?
원칙: **비즈니스 이벤트(생성 완료 등)는 그 일이 실제로 일어나는 Service에서 info 한 번.** Controller는 HTTP 관심사라 비즈니스 로그를 찍지 않는 게 보통이고, 요청 단위 추적이 필요하면 로그를 늘리는 대신 **MDC 인터셉터(requestId)** 로 모든 로그에 묶는 게 정석입니다(이번 심화 항목!). "시작" 로그는 대부분 불필요 — 완료/실패 로그에 파라미터를 담으면 시작은 유추됩니다. 지금처럼 Controller info + Service debug 이중으로 찍으면 같은 사건이 두 번 남아 노이즈가 돼요(8기부터 반복 지적). 레벨은: 성공 이벤트 info, 개발용 상세 debug, 클라이언트 잘못 warn, 서버 오류 error.

### Q4. 단위 테스트 의존성 주입 — @BeforeEach 생성자 vs @InjectMocks vs @Autowired
지금 방식(@Mock + @BeforeEach에서 생성자 직접 호출)이 **단위 테스트의 모범**입니다 — 의존성이 명시적이고, 생성자가 바뀌면 컴파일 에러로 즉시 드러나요. @InjectMocks는 타이핑이 줄지만 생성자 변경 시 조용히 어긋나는(리플렉션 주입) 함정이 있어 호불호가 갈립니다 — 팀 컨벤션으로 하나만 통일하면 됩니다. @Autowired는 스프링 컨텍스트가 뜨는 슬라이스/통합 테스트 전용 — 단위 테스트에 쓰면 느려지고 단위가 아니게 돼요. 한 가지만 정리: ChannelUnitTest에 @Mock ChannelMapper를 선언해놓고 실제론 new ChannelMapper()를 쓰고 있는데, 진짜 매퍼를 쓸 거면 @Mock 선언은 지우세요(읽는 사람이 헷갈림).

### Q5. (코드 속 질문 — UserException.java:429 주석) "왜 이런 보일러플레이트를?"
좋은 의심입니다. 계층의 실익: ①도메인 단위 일괄 catch(catch UserException) ②예외 타입만으로 의미 전달(스택트레이스 가독성) ③도메인별 공통 처리 삽입 지점. 하지만 **반대 관점도 실무에 존재** — "DiscodeitException + ErrorCode enum 하나면 충분, 클래스 수십 개는 과설계"(12기·13기 멘토들 실제 코멘트). 현재 규모에선 어느 쪽도 정답이고, 중요한 건 **계층을 만들었으면 지켜야 할 규칙**: 구체 예외는 반드시 자기 도메인 부모만 상속(8기에서 ChannelNotFound가 UserException을 상속한 사고가 있었음), details 같은 공통 구조는 최상위에만.

---

## 다음 스텝
1. 🔴 3건 수정 + `./gradlew test` 통과 확인
2. Controller 슬라이스 테스트(본인 미완 항목) — @WebMvcTest + @MockitoBean, 예외→상태코드 검증
3. 심화: MDC requestId 인터셉터 (Q3 답변의 자연스러운 다음 단계)
