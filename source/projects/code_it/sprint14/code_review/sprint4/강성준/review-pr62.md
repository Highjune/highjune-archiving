# 코드 리뷰 — [강성준] 스프린트 미션 4 (PR #62)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/62
- **작성자**: xian980 (강성준)
- **범위**: 미션3 서비스 고도화(DTO 반환 전환, 신규 도메인 서비스) + 미션4 컨트롤러 7개 + 전역 예외 처리. "api테스트·뷰템플릿은 추후 PR" 예고
- **규모**: +1437 / −87, 57 files, 1 commit
- **참고**: 담당 멘티 7명 명단 외 학생. 지각 제출("늦어서 죄송합니다")

> diff 전체(2218줄) 확인 완료. **지금까지 확인한 sprint4 제출물 중 완성도 최고 수준.**

---

## 총평 — 다른 학생들에게 지적한 사항이 전부 이미 반영된 수준 👏

- **예외 체계가 교본 수준**: `DiscodeitException` + `ExceptionType` enum(HttpStatus+메시지, 404/409/401 정확히 구분) + `ErrorResponse(timestamp, status, code, message)`에서 **code = type.name()**. 핸들러도 Discodeit / MissingParameter / **TypeMismatch(UUID 파싱)** / **NotReadable(깨진 JSON)** / catch-all(스택트레이스 로깅, "예외 객체를 두 번째 인자로 넘겨야 스택트레이스가 남는다" 주석까지) — 김예준·김양현·이승현에게 지적한 항목이 전부 이미 들어있음.
- **MultipartFile + @RequestPart 정확 사용**: 프로필/첨부를 `multipart/form-data`로 받고, `resolveProfileRequest`/`resolveAttachmentRequests` 헬퍼로 변환, yaml에 max-file-size 설정까지. (이승현이 못 풀고 미션5로 미룬 문제를 정석으로 해결)
- **상태코드 정확**: 생성 201 Created, 삭제 204 noContent, 조회 200.
- **DTO 완비 + 서비스가 DTO 반환**: 엔티티가 컨트롤러 밖으로 안 나감. `findEntity`/`toDto` private 헬퍼 패턴이 서비스 전체에 일관.
- **삭제 연쇄 정리**: 채널 삭제 → 메시지+첨부+ReadStatus 정리, 메시지 삭제 → 첨부 정리.
- **보안 감각**: 로그인 실패 시 "계정 없음"과 "비번 틀림"을 구분하지 않음 + 이유 주석 (계정 열거 공격 방지). 이 단계에서 매우 드묾.
- **디테일**: 변경 감지 update(null-skip + changed flag), `List.copyOf` 방어적 복사, **Message에 필드 추가하며 serialVersionUID 1L→2L 올림**(직렬화 호환성 인지!), `@ConditionalOnProperty` + matchIfMissing, yaml 주석("잘못된 값이면 부팅 실패 — 의도된 동작").
- 주석이 전부 "왜"를 설명하는 좋은 주석 (what 반복 없음).

---

## 🟡 짚을 점

### 1. 미션 제약 확인 — "@RequestMapping만 사용" 요구인데 @PostMapping류 사용
미션4 기본 요구사항이 "이때 @RequestMapping만 사용해 구현해보세요"인데, 이 제출물은 `@PostMapping`/`@GetMapping`/`@PatchMapping`/`@DeleteMapping` 사용. 실무에선 이쪽이 더 좋은 스타일이지만, **요구사항 제약을 벗어난 건 짚어줘야 함** (제약의 의도 = @RequestMapping의 method 속성을 직접 다뤄보라는 학습 목적). "알고 쓰는지" 확인 겸.

### 2. URL이 RPC 스타일 — 동사 경로 + 모든 id를 쿼리 파라미터로
`POST /api/channel/createPublic`, `GET /api/channel/find?channelId=`, `PATCH /api/channel/update?channelId=`, `DELETE /api/channel/delete?channelId=` — 일관성은 완벽하지만 REST 자원 중심 관례와 다름:
- 행위는 HTTP 메서드가 표현 → 경로의 동사(create/find/update/delete) 불필요
- 자원 식별자는 경로로: `POST /api/channels`, `GET /api/channels/{channelId}`, `PATCH /api/channels/{channelId}`
- (다른 학생들처럼 경로변수 의미 충돌은 없음 — 스타일 선택의 문제. 다음 스프린트 API 스펙 명세에서 어차피 자원 중심으로 요구될 가능성 높음)

### 3. `toDto`의 lastMessageAt 계산 — 목록 조회 시 반복 전체 스캔
`BasicChannelService.toDto`(:125)가 채널마다 `messageRepository.findAllByChannelId()` 호출 → `findAllByUserId`로 채널 N개 조회 시 메시지 저장소를 N번 스캔 (File 레포면 N번 파일 역직렬화). 지금 규모에선 문제없지만 **N+1 패턴의 축소판**임을 인지시키기 — DB 가면 쿼리 한 번으로 바뀔 부분.

### 4. (2차 패스) 미션4 기본 요구 위반 — "DiscodeitApplication의 테스트 로직 삭제" 미이행
`setupUser`/`setupChannel`/`messageCreateTest`/`advancedUserServiceTest`가 전부 잔존, main()에서 실행됨 (DTO 스타일로 업데이트까지 하며 유지). 컨트롤러+Postman 검증 단계이므로 삭제 대상. → `DiscodeitApplication.java:48` (main), :30/:37/:41/:67

### 5. (2차 패스) PRIVATE 채널 수정 방어 누락 — 주석으로만 선언된 규칙
`ChannelUpdateRequest` 주석엔 "PUBLIC 채널만 수정 가능"이라 적었지만 `BasicChannelService.update`(:97)에 타입 체크 없음 → PRIVATE 채널에 PATCH 시 이름·설명이 설정됨. ExceptionType에도 해당 타입 없음. "주석 규칙은 코드로 강제" 교육 포인트. → `BasicChannelService.java:97`

### 6. (2차 패스) `Message.update`가 null 체크 없이 덮어씀 — Channel과 비일관
`this.content = content; update();` — newContent가 null인 PATCH면 내용이 null로 덮임 (실질 버그). Channel.update는 null-skip+변경감지 있음. → `entity/Message.java:28`

## 🔵 Minor / Nit

- **(2차) `DiscodeitException.timestamp` dead code** — 필드(:13)에 담지만 핸들러 toResponse는 `Instant.now()`(GlobalExceptionHandler:61)로 새로 찍음. e.getTimestamp() 사용하거나 제거.
- **(2차) ReadStatus 중복 체크** — findAllByUserId+anyMatch 대신 레포 `existsByUserIdAndChannelId` (이은솔 exists 논점과 동일).

- `BinaryContentDto`가 `bytes` 전체 포함 — findAllByIdIn으로 여러 건 조회 시 base64로 응답이 커짐. 요구가 "다운로드"라 지금은 맞지만, 목록엔 메타데이터만 / 다운로드는 단건이라는 분리도 있다는 것 언급.
- 채널/메시지 연쇄 삭제가 건별 `deleteById` — File 레포는 매 건마다 전체 로드+저장. deleteAllByChannelId처럼 배치 메서드로 내리면 저장 1회로 줄음 (ReadStatus는 이미 그렇게 함).
- `UserStatusController`에 요구사항 외 API(find/findAll/update by id)도 노출 — 문제는 아니나 "필요한 것만 여는" 관점 언급 여지.
- 컨트롤러가 lombok 없이 수동 생성자 — 프로젝트 내 일관되면 OK (오히려 명시적).

---

## 정리 (우선순위)

| 순위 | 항목 | 위치 |
|---|---|---|
| 1 | @RequestMapping 제약 확인 (요구사항 벗어남 인지 여부) | 전 컨트롤러 |
| 2 | URL 자원 중심 재설계 (동사 제거 + 경로변수) | 전 컨트롤러 |
| 3 | toDto의 lastMessageAt N+1 인지 | BasicChannelService:125-132 |
| 4 | bytes 포함 DTO / 배치 삭제 / 잉여 API | (Minor) |

칭찬 포인트가 많아 리뷰의 절반은 "왜 잘했는지 명시적으로 인정"에 쓰는 게 좋음 — 특히 로그인 보안 주석, serialVersionUID 증가, 예외 핸들러 커버리지.

---

## 복붙용 코멘트 위치 (head 파일 검증 완료)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| @RequestMapping 제약 + URL 스타일 (메인) | `controller/ChannelController.java:32` | `@PostMapping("/createPublic")` |
| URL 연결 (find 쿼리파람) | `ChannelController.java:42` | `@GetMapping("/find")` |
| 칭찬: multipart 정석 해결 | `controller/UserController.java:37` | `@PostMapping(path="/create", consumes=MULTIPART...)` |
| 칭찬: 첨부 다건 multipart | `controller/MessageController.java:37-40` | `@RequestPart attachments` |
| 칭찬: 예외 핸들러 커버리지 | `exception/GlobalExceptionHandler.java:53` | `@ExceptionHandler(Exception.class)` |
| 칭찬: 로그인 보안 | `service/basic/BasicAuthService.java:29-30` | 계정 열거 방지 주석 |
| lastMessageAt N+1 | `service/basic/BasicChannelService.java:132` | `messageRepository.findAllByChannelId(...)` |
| bytes 포함 DTO | `controller/BinaryContentController.java:29` | `@GetMapping("/findAllByIdIn")` |
| (2차) 테스트 로직 삭제 요구 미이행 | `DiscodeitApplication.java:48` | main의 setupUser/messageCreateTest 호출 |
| (2차) PRIVATE 수정 방어 누락 | `service/basic/BasicChannelService.java:97` | `public ChannelDto update(` |
| (2차) Message.update null 덮어씀 | `entity/Message.java:28` | `public void update(String content)` |
| (2차) timestamp dead code | `exception/DiscodeitException.java:13` | `private final Instant timestamp;` |
