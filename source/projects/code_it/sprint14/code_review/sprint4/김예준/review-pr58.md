# 코드 리뷰 — [김예준] 스프린트 미션 4 (PR #58)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/58
- **작성자**: kim-yejunn (김예준)
- **범위**: 웹 API(컨트롤러 7개, `@RequestMapping`만 사용) + 전역 예외 처리(`@RestControllerAdvice`) + BaseEntity 추출 + 시드 데이터 + 생성형 AI 관리 화면(심화)
- **규모**: +2865 / −269, 57 files, 6 commits
- **라벨**: 매운맛🔥
- **참고**: 담당 멘티 7명 명단 외 학생 (조예준 joyejun과 다른 사람. 김예준 = kim-yejunn, 프로젝트 루트가 `sprint-mission-1/`)

> diff 전체(4350줄) 확인 완료. app.js(875줄, AI 생성 UI)는 구조만 훑음.

---

## 총평 — 예외 처리 설계가 이 단계 기대치를 훌쩍 넘음 👏

- **`ExceptionType` enum이 로그 레벨 + HTTP 상태 + 메시지를 한꺼번에 소유** → 예외 종류만 정하면 응답 코드와 로깅 수준이 자동 결정. 핸들러의 `log.atLevel(type.getLevel()).setCause(e).log(...)` 사용은 실무에서도 보기 드문 깔끔한 구성.
- **`DiscodeitException(type, details Map)`** — 예외에 컨텍스트(userId 등)를 구조화해 담고 로그로만 출력(응답엔 미노출). 서비스 전반의 `IllegalArgumentException`을 빠짐없이 일괄 전환.
- **BaseEntity 추출** (id/createdAt/updatedAt + `markUpdated()`) — 6개 엔티티의 중복 필드 제거, `getChannelId()`류가 전부 `getId()`로 통일.
- **File 레포 개선**: 파일이 없으면 조용히 시작, 있는데 못 읽으면 `IllegalStateException` throw — 이전의 "없습니다" println을 정확한 방향으로 교정. `RuntimeException` → `UncheckedIOException` 전환도 적절.
- **DataInitializer**: `@ConditionalOnProperty(discodeit.seed)` 게이트, Postman 변수 출력까지. `MockMultipartFile`이 test scope라 직접 `SimpleMultipartFile`을 구현한 건 의존성 스코프를 이해한다는 증거.
- **AI 심화**: api.js에 "컨트롤러에 실제로 존재하는 엔드포인트만 정의한다" 주석 + 없는 엔드포인트는 명시적으로 제외 — AI 산출물을 검증하며 쓴 흔적이 보임.

---

## 🟡 Major

### 1. URL 설계가 자원(Resource) 중심에서 벗어남
미션 제약은 "`@RequestMapping`만 사용"(메서드 지정 방식)이지 URL 설계까지 자유는 아님. 현재:

| 현재 | REST 관례 | 문제 |
|---|---|---|
| `DELETE /api/user/{id}/delete` | `DELETE /api/users/{id}` | HTTP 메서드가 이미 "삭제"를 의미 — `/delete` 중복 |
| `GET /api/user/findAll` | `GET /api/users` | URL에 메서드 이름(동사) 노출 |
| `GET /api/channel/{userId}/findAll` | `GET /api/users/{userId}/channels` | `{userId}`가 채널 id 자리처럼 읽힘 — 오해 소지 최상 |
| `GET /api/readStatus/{id}/find` | `GET /api/read-statuses/{id}` | 동사 노출 |
| `POST /api/publicChannel` | `POST /api/channels/public` | 자원은 명사·복수형, URL은 kebab-case가 관례 |

핵심 원칙: **URL은 자원(명사), 행위는 HTTP 메서드**. 다음 스프린트에서 API 명세가 프론트와의 계약이 되면 이 부분이 그대로 드러남.

### 2. 전역 예외 처리의 커버리지 빈틈 — DiscodeitException "만" 잡음
- `@Valid` 실패 → `MethodArgumentNotValidException`: 핸들러 없음 → 스프링 기본 400 응답(ErrorResponse 포맷 아님)
- `@PathVariable UUID` 파싱 실패 → `MethodArgumentTypeMismatchException`: 기본 400/500
- `UncheckedIOException`/`IllegalStateException` 등 나머지 전부: **스택트레이스가 담긴 기본 500 노출**

→ `@ExceptionHandler(MethodArgumentNotValidException.class)` 400 + catch-all `@ExceptionHandler(Exception.class)` 500(ERROR 로깅)을 추가해야 "모든 응답이 ErrorResponse 형식"이라는 계약이 완성됨.

### 3. `ErrorResponse.code = status.toString()` — 분기용 코드로 부적합
현재 code가 `"404 NOT_FOUND"` 같은 문자열이라 HTTP 상태와 사실상 중복. 클라이언트가 "같은 404라도 USER_NOT_FOUND vs CHANNEL_NOT_FOUND"를 구분하려면 **`type.name()`을 code로** 주는 게 정석. (details를 응답에 안 담은 건 내부정보 노출 방지 관점에서 오히려 좋은 판단 — 의도인지 확인)

### 4. `lastReadAt`/`lastActiveAt`을 `updatedAt`으로 흡수 — 도메인 의미 손실
BaseEntity 도입하면서 ReadStatus의 `lastReadAt`, UserStatus의 `lastActiveAt` 필드를 삭제하고 `updatedAt`을 재사용 (`isOnline()`도 updatedAt 기반, ResponseDto도 updatedAt 반환).
- `updatedAt`은 "레코드가 언제 수정됐나"(감사 필드), `lastReadAt`은 "언제 읽었나"(도메인 사실) — **다른 개념**. 다른 이유로 엔티티가 수정되는 순간 "읽은 시간"이 왜곡됨.
- ReadStatus 생성자에서 `markUpdated()` 호출(생성=수정 취급)도 그 부작용.
- 다음 스프린트(DB 스키마 명세)에서 두 필드가 분리되어 요구될 가능성이 높아 되돌리게 될 소지.

### 5. `userUpdate` 프로필 교체 순서 — 기존 삭제 후 신규 저장 실패 시 이미지 유실
`binaryContentRepository.delete(user.getBinaryId())` 를 먼저 하고 새 이미지를 저장. 새 이미지 읽기(`getBytes()`)가 실패하면 **기존 프로필은 이미 삭제된 상태**. 순서를 "새 이미지 저장 성공 → 기존 삭제"로 뒤집으면 안전. 또한 기존 프로필이 없던 유저(binaryId=null)면 `delete(null)`이 호출됨 — null 가드 필요.

---

## 🔵 Minor / Nit

- **`AuthController.login`이 void** — 서비스는 `UserResponseDto`를 반환하는데 컨트롤러가 버림. 로그인 성공 후 클라이언트가 "누구로 로그인됐는지"를 못 받아 화면(app.js)이 별도 조회로 우회. 반환 권장.
- **상태코드**: create가 200 반환(201 Created가 정석), 삭제도 200(204 No Content 고려). 기존 코드의 `ResponseEntity` 사용을 오히려 제거했는데, 상태코드를 제어하려면 다시 필요해짐 (또는 `@ResponseStatus`).
- **`User.update()`가 무조건 `markUpdated()`** — 값이 하나도 안 바뀌어도 updatedAt 갱신. Channel.update / Message.updateMessage는 changed 체크를 하는데 User만 비일관.
- **`findAllByIdIn()` → `findAll()` rename** — "파라미터를 무시하는 가짜 idIn"을 정직하게 정리한 건 좋으나, 스펙상 `findAllByIdIn(List<UUID>)`(여러 id 조회)는 결국 필요한 메서드라 다음 미션에서 제대로 구현 필요 (테스트 주석에도 인지되어 있음).
- **클라이언트가 시간을 보내는 구조** — `PATCH /api/userStatus/{id}`가 `lastActiveAt`을 요청 본문으로 받음. 온라인 상태 같은 서버 관점 사실은 **서버 시계**로 찍는 게 안전 (클라이언트 시계는 신뢰 불가). readStatus의 lastReadAt도 동일 논점.
- **BinaryContent만 BaseEntity 미적용** — 수정 불가 모델이라 updatedAt이 없어야 해서 의도적이라면 타당한 판단 (확인 질문 겸 칭찬 포인트).
- **`discodeit.seed: true`가 기본 커밋** — 시연엔 편하지만 기본값은 false로 두고 로컬에서만 켜는 게 안전.
- PR 본문의 "Postman export가 유료" — Collection 우클릭 → Export(JSON)는 무료 기능. 아마 다른 메뉴(API 문서 publish 등)와 혼동한 듯.

---

## 정리 (우선순위)

| 순위 | 항목 |
|---|---|
| 1 | URL 자원 중심 재설계 (`/delete`·`findAll` 제거, 명사·복수형) |
| 2 | 예외 핸들러 커버리지 (@Valid 400, catch-all 500) |
| 3 | ErrorResponse.code → `type.name()` |
| 4 | lastReadAt/lastActiveAt vs updatedAt 분리 재고 |
| 5 | userUpdate 프로필 교체 순서 + delete(null) 가드 |
| 6 | 로그인 응답 반환, 상태코드(201/204), User.update 변경감지 |

예외 처리 뼈대(ExceptionType + atLevel 로깅 + details)는 이대로 커스텀 예외 체계의 표준이 될 수 있는 수준. 남은 건 대부분 "API를 바깥 세상과의 계약으로 보는 관점"(URL, 상태코드, 응답 포맷 일관성)이며, 이건 딱 이번 스프린트가 가르치려는 주제라 지금 잡아주면 효과가 큼.

---

## 코멘트 위치 가이드 (head: kim-yejunn:김예준, 경로는 `sprint-mission-1/src/main/` 하위)

| 항목 | 파일:라인 |
|---|---|
| URL 메인 코멘트 (/delete 중복) | `user/controller/UserController.java:40` |
| GET /api/user/findAll | `UserController.java:47` |
| 채널 {userId}/findAll 오해 소지 | `channel/controller/ChannelController.java:54` |
| publicChannel 네이밍 | `ChannelController.java:25` (private은 32) |
| message /delete | `message/controller/MessageController.java:35` |
| readStatus /find | `readstatus/controller/ReadStatusController.java:35` |
| 예외 핸들러 커버리지 | `global/exception/GlobalExceptionHandler.java:13` |
| ErrorResponse.code | `global/exception/dto/ErrorResponse.java:11` |
| lastReadAt→updatedAt 흡수 | `readstatus/entity/ReadStatus.java:19` (생성자 markUpdated) |
| isOnline이 updatedAt 의존 | `userstatus/entity/UserStatus.java:29-31` |
| 프로필 교체 순서 + delete(null) | `user/service/UserServiceImpl.java:71` |
| 로그인 void 반환 | `auth/controller/AuthController.java:20` |
| create 201 | `UserController.java:26` |
| User.update 무조건 markUpdated | `user/entity/User.java:36` |
| lastActiveAt 클라이언트 입력 | `userstatus/controller/UserStatusController.java:22` |
| findAllByIdIn 스펙 | `binarycontent/repository/BinaryContentRepository.java:16` |
| seed: true 기본값 | `resources/application.yaml:2` |
| 칭찬: ExceptionType 구조 | `global/exception/ExceptionType.java` enum 선언부 |
| 칭찬: SimpleMultipartFile | `global/init/DataInitializer.java` (record SimpleMultipartFile) |

---

## 후속 커밋 리뷰 (2026-08-23) — 8/18 반영 커밋 3개

**범위**: b0454690 "fix: 전역 에러 처리 추가" / 38a6548d "fix: url 수정 및 ResponseEntity로 감싸서 반환" / 42cbf130 "fix: 비지니스 로직 수정" (1f3e0b74...42cbf130, 11 files, 495줄)
**참고**: 8/19~8/20 커밋(스펙 전환·openapi)은 미션5 범위 → `sprint5/김예준/review-pr69.md`에서 별도 리뷰 완료.

### 지난 리뷰 지적 → 반영 대조표

| 지난 지적 | 반영 | 확인 위치 (42cbf130 시점) |
|---|---|---|
| URL 동사 노출 (/delete, findAll, {userId}/findAll) | ✅ 전부 제거, `/api/v1/*` 자원 중심 + kebab-case (public-channels, read-statuses, binary-contents) | 전 컨트롤러 |
| 핸들러 커버리지 (DiscodeitException만) | ✅ MethodArgumentNotValidException(**필드 단위 메시지 조립**) + TypeMismatch(입력값·필요형식 안내) + catch-all(내부 메시지 비노출, ERROR 로깅+cause) + logMessage 공통화 | GlobalExceptionHandler.java |
| ErrorResponse.code = status.toString() (중복) | ✅ `type.name()`으로 교체 + detail 오버로드 추가 | ErrorResponse.java |
| 프로필 교체 순서 (구 삭제 먼저 → 저장 실패 시 프로필 유실) + delete(null) NPE | ✅ 신규 저장 성공 후 구 삭제 + `Objects.nonNull` 가드 (userDelete도 정리) | UserServiceImpl.userUpdate/userDelete |
| login이 void 반환 | ✅ UserResponseDto 반환 + `/api/v1/auth/login` | AuthController |
| 상태코드 | ✅ 생성 201 Created + ResponseEntity 전면 래핑 | 전 컨트롤러 |

### 이 시점에 남았던 것 (→ 미션5 커밋에서 자체 해결 확인)

- update/delete 일부가 여전히 void 반환(200) — 미션5 커밋(b3f5a388)에서 update는 본문 반환, delete는 204로 정리됨.
- `GET /api/v1/channels/{userId}` 경로변수 의미 충돌 잔존 — 미션5에서 `GET /api/channels?userId=` 쿼리 파라미터로 해결됨.

### 새 지적 사항: 없음

handleValidation의 주석("getMessage 그대로 쓰면 에러 전체 내용이 나와 비효율")처럼 **왜를 이해하고 고친 흔적**이 뚜렷함. 지적 6건이 전부 정확히, 지적한 방식대로 반영됨 — 반영 확인 + 인정 코멘트가 적절.
