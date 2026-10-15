# 코드 리뷰 — [이승현] 스프린트 미션 4 (PR #65, 심화 X)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/65
- **작성자**: Hanna-log (이승현)
- **범위**: 학생이 직접 지정 — 컨트롤러 6개 + GlobalExceptionHandler (총 7개 클래스)
- **규모**: +4701, 105 files 전부 신규 추가, 10 commits
- **라벨**: 미완성🛠️, 지각제출⏰
- **참고**: 담당 멘티 7명 명단 외 학생. Postman 컬렉션 export 첨부함(요구사항 준수). PR 본문에 @RequestBody 2개 문제 질문 있음

> 대상 7개 클래스 전문 + 전체 구조 확인 완료. 라인 번호는 head(Hanna-log:sprint4) 실제 파일에서 검증.

---

## ⚠️ 프로세스 — PR base가 `main` (머지 금지!)

base가 본인 이름 브랜치가 아니라 **org의 `main`**으로 열려 있고, 105개 파일 전부 추가라 머지하면 **개인 프로젝트 전체가 org main에 들어감**. 리뷰 코멘트 전에 base를 본인 이름 브랜치(이승현)로 변경하도록 안내 필요 (PR 편집에서 base 브랜치만 바꾸면 됨 — PR 다시 만들 필요 없음).

---

## 총평

컨트롤러 6개가 요구 API를 빠짐없이 구현했고, `@RequestMapping(method=...)` 제약 준수, `ResponseEntity` + `@Valid` + DTO 분리 + `@Slf4j` 로깅까지 형태가 잘 갖춰짐. 막힌 부분(@RequestBody 2개)을 임시 우회하고 PR 본문에 "왜 막혔고 언제까지 어떻게 해결할지"를 솔직하게 적은 태도가 특히 좋음. 예외 클래스 파편화도 스스로 인지하고 개선 계획을 밝힘.

---

## 학생 질문 답변 — @RequestBody 2개 / MultipartFile

**질문 요지**: UserCreateRequest + BinaryContentCreateRequest를 같이 받으려니 오류 → 프로필이 필수가 아니라 잠시 뺐고, MultipartFile은 미션5 전에 학습 예정.

**답변 방향**:
1. 원인 정확히 이해한 것 맞음 — `@RequestBody`는 "요청 본문(JSON) 전체"를 한 객체로 바인딩하는 것이라 한 메서드에 하나만 가능 (본문은 한 번만 읽힘).
2. 해결 두 가지: ① JSON 하나로 합치기 — `UserCreateRequest` 안에 프로필 필드를 중첩(지금 단계에서 간단). ② 정석 — `multipart/form-data`로 받기: `@RequestPart UserCreateRequest` + `@RequestPart MultipartFile profile`. 파일은 바이너리라 JSON에 싣는 것보다 multipart가 표준. 미션5 전에 알아두겠다는 계획이 정확한 방향.
3. 지금 null/List.of() 우회는 프로필이 선택 사항이니 임시방편으로 OK. 단 서비스가 null을 받았을 때 NPE 없이 동작하는지만 확인.

---

## 🟡 Major

### 1. GlobalExceptionHandler — 모든 예외가 400, 응답이 raw String
- NotFound류(유저/채널/메시지/상태 없음)도, 로그인 실패(InvalidCredential)도 전부 `badRequest()`(400). **조회 실패=404, 인증 실패=401, 중복=409**로 구분해야 클라이언트가 의미를 알 수 있음.
- 응답 본문이 문자열 하나 — `ErrorResponse(code, message)` 레코드로 형태를 잡아주면 좋음.
- 핸들러 13개가 전부 동일 코드 복붙 — 학생 스스로 "enum 방식 적용 예정"이라 했으니 방향 확인: **공통 부모 예외(예: DiscodeitException) + ErrorCode enum(status+message)**으로 만들면 핸들러가 1~2개로 줄고 상태코드 구분도 자동 해결. (미션5 계획과 정확히 맞음)
- catch-all `Exception` 핸들러(:10)가 **로그를 안 남김** — 500의 원인을 추적할 수 없음. `log.error("...", e)` 필수.
- 메서드명이 대문자 시작(`AllExceptionhandler`, `BinaryContentNotFoundhandler`) — 자바 네이밍 컨벤션(소문자 camelCase) 위반.

### 2. 경로 패턴 충돌 — 같은 자리 `{X}`가 어떤 땐 id, 어떤 땐 userId/channelId
- `ChannelController`: PATCH/DELETE `/{channelId}` vs GET `/{userId}` — 같은 `/api/channel/{X}` 자리에 다른 의미의 값. URL만 봐선 구분 불가.
- `MessageController`: GET `/{channelId}` — `/api/message/{X}`인데 X가 메시지 id가 아니라 채널 id.
- `ReadStatusController`: GET `/{userId}` — 동일.
- "특정 사용자의 채널 목록" 같은 관계는 `GET /api/users/{userId}/channels` 형태로 URL 계층으로 표현. (김양현 #61, 김예준 #58과 공통 지적 — 스프린트 공통 교육 포인트)

### 3. `BinaryContentController`가 엔티티를 직접 반환
다른 컨트롤러는 전부 DTO를 반환하는데 여기만 `List<BinaryContent>` (byte[] 포함 엔티티 노출). BinaryContentDto로 통일.

### 4. 주석 처리된 코드 대량 잔존
- `JavaApplication.java` — 168줄 전체가 사실상 주석 (참고용으로 남김). git이 이력을 보존하니 파일째 삭제 대상.
- `UserController:32~`, `MessageController:32~` — "오류발생됨" 실패 버전 주석. PR 본문에 설명했으니 코드에선 삭제.
- `DiscodeitApplication:17~` — 긴 학습 노트 주석. 공부한 내용은 훌륭하지만 코드가 아닌 별도 노트로.

## 🔵 Minor / Nit

- create류 응답이 200 — 201 Created 권장 (`ResponseEntity.status(HttpStatus.CREATED)`).
- delete가 void 반환 (200 빈 응답) — `ResponseEntity<Void>` + 204 noContent 권장.
- 미사용 import 다수: `BinaryContentController`의 UserDto/PathVariable/Repository, `ReadStatusController`의 ChannelService/MessageService/UserService/entity.ReadStatus, `AuthController`의 PathVariable/UserService/UUID 등 — ⌥⌘O 정리.
- 온라인 상태 업데이트가 `UserController`에 위치(`/api/user/status/{userId}` + UserStatusService 주입) — 요구사항상 무방하나 UserStatusController 분리도 고려 여지.

---

## 잘한 점 (코멘트로 남겨줄 것)

- 요구 API 전체 구현 + `@RequestMapping(method=...)` 제약 준수 (클래스 레벨 prefix 조합도 깔끔)
- `ResponseEntity` + `@Valid` + 도메인별 DTO 분리 — 이번 스프린트에서 처음부터 형태를 갖춤
- 막힌 지점을 숨기지 않고 **PR 본문에 원인·임시조치·해결 계획을 명시** — 협업에서 가장 중요한 습관
- 예외 파편화를 스스로 인지하고 개선 계획(enum) 선언 — 방향도 정확
- Postman 컬렉션 export 첨부 (요구사항 준수)

---

## 복붙용 코멘트 위치 (head 파일 기준 검증 완료)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| ⚠️ base=main (PR 코멘트 or DM) | PR 자체 | — |
| 모든 예외 400 + String 응답 + 복붙 구조 | `exception/GlobalExceptionHandler.java:18` | 첫 개별 핸들러 |
| catch-all 로그 없음 | `GlobalExceptionHandler.java:10` | `@ExceptionHandler(Exception.class)` |
| 메서드명 대문자 | `GlobalExceptionHandler.java:11` | `AllExceptionhandler` |
| 채널 GET /{userId} 경로 | `controller/ChannelController.java:67` | `RequestMethod.GET, value = "/{userId}"` |
| 메시지 GET /{channelId} | `controller/MessageController.java:76` | 동일 패턴 |
| readStatus GET /{userId} | `controller/ReadStatusController.java:57` | 동일 패턴 |
| 엔티티 직접 반환 | `controller/BinaryContentController.java:28` | `List<BinaryContent>` |
| 질문 답변 (RequestBody×2) | `controller/UserController.java:32` (주석 블록) 또는 PR 본문 답글 | `/* 1. 사용자 등록 --- 오류발생됨` |
| 주석 잔존 (실패 버전) | `UserController.java:32`, `MessageController.java:32` | 주석 블록 |
| JavaApplication 삭제 | `JavaApplication.java:1` | 파일 전체 |
| 학습 주석 분리 | `DiscodeitApplication.java:17` | `/*` 학습 노트 |
| create null 우회 확인 | `UserController.java:62` | `userService.create(request, null)` |
