# 스프린트 미션5 — 과거 기수(9~13기) 멘토 리뷰 인사이트

> 2026-08-24 수집. codeit-bootcamp-spring/{9,10,11,12,13}-sprint-mission 저장소의 미션5 PR 약 70개에서
> 멘토 인라인 코멘트·리뷰 총평을 추출·통합한 것. 14기 미션5 리뷰 시 이 문서를 근거로 활용.
> 미션5 = RESTful API 재설계(스펙 준수) + springdoc-openapi(Swagger) + Postman.

## 전 기수 공통 최다 반복 (리뷰 시 우선 확인)

1. **Swagger 어노테이션을 `XxxApi` 인터페이스로 분리, 컨트롤러가 구현** — 5개 기수 전부에서 등장한 미션5의 시그니처 제안.
   @Tag/@Operation/@ApiResponse를 인터페이스에 두면 컨트롤러 본문 가독성 유지. 분리한 학생은 일관되게 칭찬받음("멘티 평균을 크게 웃도는 좋은 선택" — 12기).
   네이밍 대안: `~Api`보다 `~ControllerSpec`(9기 eedys1234), `~ControllerDocs`(13기).
   ⚠️ 유일한 반대 의견: 11기 JJong0416 — "인터페이스에 문서 어노테이션은 관심사 분리 위반, 실무에선 구현체에" → 컨벤션 선택지로 소개할 것.
2. **엔티티를 API 응답으로 직접 반환 금지 (password 노출 = P1 보안)** — 10·11·12기 최다 지적. 응답 전용 DTO로 통일, 최소한 @JsonIgnore.
3. **제공된 API 스펙과의 정합성이 이번 미션의 핵심 평가축** — 필드명·part name(`userCreateRequest`, `binaryContentIds`)·경로(`/{userId}/userStatus`)·상태코드까지 스펙과 1:1 대조. oasdiff 활용 권장. "kebab-case가 실무 관례지만 스펙이 camelCase면 스펙 준수가 우선"(9·10·12기 공통 단서).
4. **`MethodArgumentNotValidException` 핸들러 누락 → @Valid 실패가 500으로 떨어짐** — 10기 반복 지적. Bean Validation(@NotBlank/@Email)+@Valid 짝 맞추기, 수동 null 체크 대체(11기 전 멘토 공통).
5. **@ControllerAdvice+@ResponseBody → `@RestControllerAdvice` 통일** — 9기에서 멘토 4명 전원이 지적한 유일 항목.
6. **에러 응답은 String이 아닌 구조화된 ErrorResponse DTO** `{code, message, status, timestamp}` — 9·12·13기. 성공/실패 응답의 JSON 구조 컨벤션 일치(11기). ProblemDetail만 반환하면 200으로 나가니 ResponseEntity로 감싸 상태코드 명시(13기).
7. **상태코드 세분화** — 404(없음)/409(중복)/401(인증)/400(입력) 구분, 생성 201(+Location 헤더 with `ServletUriComponentsBuilder`), 삭제 204(`ResponseEntity.noContent()`), 수정은 PUT 아닌 PATCH. 문서(@ApiResponse)와 실제 동작 상태코드 정합성(9·10·12기).
8. **동사 URL 금지, 자원 중심 설계** — `/create`·`/findAll` → HTTP 메서드가 행위 표현. 자원 식별은 path variable, 검색/필터는 query param(11기 — 혼동 시 실제 404 버그).

## 자주 반복

9. **findAll() 후 스트림 필터 금지** — `findByUsername`/`findAllByIdIn`(N+1 방지)/`existsBy...` 전용 조회 메서드 추가 (10·11기).
10. **multipart는 `@RequestPart`로 객체 자동 바인딩** — ObjectMapper 수동 파싱 금지(11·13기), `consumes = MULTIPART_FORM_DATA_VALUE` 명시(12기). 커스텀 MultipartJackson2HttpMessageConverter는 전역 사이드이펙트 경고(9·13기) vs 칭찬(10기) — 양론 존재.
11. **IOException을 bare RuntimeException으로 래핑 금지** — 정보 소실 + 범용 핸들러로 500. `FileProcessingException` 같은 커스텀 예외 + 파일명 등 컨텍스트 포함 (10·12기).
12. **응답 JSON에 byte[] 통째로 넣는 것 주의** — Base64 팽창·OOM. 메타데이터/다운로드 분리, 단 미션5 스펙의 BinaryContentDto엔 bytes가 있으므로 "스펙 우선 + 실무 관점 예고" 프레임으로 (10·11·13기).
13. **빌드 산출물·데이터 파일 커밋 금지** — build/, .gradle, *.ser, api-docs.json → .gitignore + `git rm --cached` (9·12·13기).
14. **PATCH 부분 수정 시맨틱** — null 필드가 기존 값을 덮어쓰거나(11기 "DB 초토화" 버그), 요청값(newLastActiveAt)을 무시하고 서버가 임의 갱신하는 것 모두 지적 (11·12·13기).
15. **커스텀 예외 계층화** — 공통 부모(DiscodeitException) + ErrorCode enum 패턴은 실무에서도 흔한 정석(11기 psh10066). 도메인별 상속으로 확장.
16. **SwaggerConfig에 localhost 하드코딩 금지** (10·12기), 버전명 등은 yml 프로퍼티화(13기), `@Schema` 필드 설명·operationId·@Parameter 채우기(9·12기), responseCode 문자열 하드코딩 대신 상수(9기).
17. **컨트롤러 계층 책임** — DTO 변환·조회·예외 생성은 서비스로, 컨트롤러는 HTTP 번역만. try-catch 대신 전역 핸들러 위임. `ResponseEntity<?>` 대신 구체 타입(Swagger 문서 품질과 직결) (10·11·13기).
18. **축약 매핑 어노테이션** — `@RequestMapping(method=...)` 대신 @GetMapping류 (9·10·11기).

## 단발성이지만 가치 높음

- 도메인 캡슐화: `user.authenticate(pw)`, `Channel.createPublic()` 정적 팩토리, `isPublic()` (12기).
- Service 빈은 stateless — 싱글턴 필드에 로그인 사용자 저장 금지 (10기).
- 삭제 시 연관 데이터 cascade 정리 (13기).
- 비밀번호 평문 비교 — BCryptPasswordEncoder 예습 키워드 제시 (10기).
- 주석 처리된 코드 삭제(git이 기억함), @PathVariable name 변수명과 같으면 생략, 컬렉션은 인터페이스 타입 선언.
- 파일 스트림 처리: getBytes() 메모리 적재 대신 stream 전달 — 다음 미션(storage) 예고용 (9·11기).
- API 버전 prefix `/api/v1/...` 소개 (11기).

## 기수별 원본

각 기수 상세(예시 PR 번호·파일 경로 포함)는 수집 에이전트 결과 참조. 멘토 성향 메모:
9기 eedys1234(REST 상태코드·Location 헤더), yerin-mentor(컨벤션·kebab), bellman66(Swagger 명세 품질), hagyutae(스펙 정합성·@RequestMapping 위험).
10기 joonfluence(P1~P5 라벨링·동작 버그 우선), byungwook-min(스펙 정합·일관성), itstimi-XD(보안·계층 분리).
11기 psh10066/eunjinkim-codeit(Api 인터페이스 분리 권장), JJong0416(반대 — 구현체에), lcy960729(Location 헤더).
12기 hagyutae/kwj2435/koritsu 외. 13기 jinho-yoo-jack/the-eris-net/spring-kang.
