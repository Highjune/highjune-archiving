# 코드 리뷰 — [김양현] 스프린트 미션5 (PR #71)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/71
- **작성자**: yyy2724 (김양현), head `yyy2724:김양현` → base `김양현` ✅
- **규모**: +3198 / −1351, 78 files
- **라벨**: 매운맛🔥
- **범위**: 미션4 리뷰(#61) 반영 + 미션5 스펙 정합 + Railway 배포
- **참고**: 9~13기 인사이트 반영 (`reference/sprint5-past-cohort-review-insights.md`)

> diff 전체(5671줄) 확인, 라인은 head 브랜치 raw 파일 grep 검증 완료.

---

## 총평 — 미션4 피드백 이행률은 최상급. 그런데 🔴 3개가 성과를 가림: ①빌드 불가(테스트 컴파일 깨짐) ②예외 핸들러 삭제로 전 커스텀 예외가 500 ③로그인 응답 password 노출

**미션4 지적 반영 (전부 확인됨):**
- 🔴 .gitignore `user/`,`channel/`,`message/` 3줄 삭제 + `.discodeit/`로 대체 — **제안 그대로 정확히 복구**, 누락됐던 user/channel/message 패키지 전부 커밋됨
- ReadStatus 응답에 id 포함 + request가 아닌 저장된 엔티티로 응답 조립
- BinaryContent 단건 조회 `GET /{binaryContentId}` 추가 + create→findAllByIds 메서드명 정정
- ErrorCode의 `"409"` 문자열 code 필드 제거, ErrorResponse가 `errorCode.name()` 사용
- FileReadStatusRepository의 printStackTrace 예외 삼킴 → RuntimeException 전파로 수정
- ReadStatus URL 재설계: `/api/readStatuses` + GET 쿼리 파람 (경로 충돌 해소)

**미션5 새 성과:**
- @RequestPart part 이름 스펙 정확 (`userCreateRequest`, `profile`, `messageCreateRequest`, `attachments`) + consumes 명시
- User 생성 201 Created, PATCH `/{userId}/userStatus` 서브리소스 경로
- `User.create` 정적 팩토리 + 도메인 내부 검증 (12기 멘토 칭찬 패턴)
- UserResponseDto: password 없이 online 포함 — 스펙 정합 (로그인 응답만 이걸 안 씀 → 🔴 3)
- 로그인 성공 시 lastAccessAt 갱신 → online 판정 연동
- BinaryContent에 fileName/size/contentType 확장, multipart 사이즈 설정
- 채널 삭제 시 메시지·ReadStatus cascade, 메시지 삭제 시 첨부 정리
- Railway 배포 + 테스트 7종 유지보수 시도 (완주는 못 함 → 🔴 1)

---

## 🔴 Critical

### 1. 테스트 4개 파일이 컴파일 불가 → `./gradlew build` 실패
- `BasicReadStatusServiceTest.java:122,131` — `readStatusService.update(readStatus.getId(), );` **문법 오류** (두 번째 인자 자리 비움)
- `BasicUserServiceTest.java:88` — `new UserUpdateRequestDto(created.profileId(), "새김양현", "new@naver.com", "password")` — 4개 인자, record는 3개(newUsername/newEmail/newPassword)
- `BasicUserStatusServiceTest.java:122,130` — `updateByUserId(userId, Instant.now())` — 시그니처는 `(UUID, UserStatusUpdateRequestDto)`; `:138,146` — `delete(new UserStatusUpdateRequestDto(id, Instant.now()))` — delete는 UUID를 받고, record 생성자도 1개 인자
- `BasicMessageServiceTest.java:73` — `found.userId()` — MessageResponseDto에 없는 접근자(authorId)

미션4 때 "브랜치가 빌드부터 안 된다"(gitignore 사건)와 형태만 다른 반복. main 소스는 컴파일되므로 Railway 배포(테스트 스킵)는 됐지만 `./gradlew build`는 compileTestJava에서 실패. **push 전 로컬 build 1회** 습관 제안.

### 2. `DiscodeitException` 핸들러가 삭제됨 → 커스텀 예외 전부 500 — `GlobalExceptionController.java:21`
이번 PR에서 `handleDiscodeitException`이 지워지고 IllegalArgumentException(400)과 Exception(500)만 남음. NoSuchElementException, AuthenticationFailedException, Duplicate*, PrivateChannelUpdateNotAllowedException 전부 DiscodeitException 상속 → **Exception.class로 떨어져 500 "INTERNAL_ERROR"**:
- 로그인 실패: 스펙 401 → 실제 500
- 중복 username/email: 409 → 500
- 없는 리소스 조회: 404 → 500
- PRIVATE 채널 수정: 403 → 500

같은 PR에서 ErrorCode를 다듬은(code 제거, name() 사용) 정성이 전부 사장됨 — ErrorCode의 status 필드를 읽는 코드가 사라진 상태. 리팩터링 중 실수 삭제로 추정, 핸들러 복원이 1순위.

### 3. 로그인 응답에 password 노출 — `AuthLoginResponseDto.java:12`, `BasicAuthService.java:37`
`user.getPassword()`를 응답에 그대로. 10~12기 멘토들이 P1(최우선 보안)으로 다룬 항목. **본인이 만든 UserResponseDto를 재사용하면 한 번에 해결** — password 빠지고, 스펙이 요구하는 `online` 필드까지 충족(로그인 직후 lastAccessAt 갱신했으니 true로 나옴). AuthLoginResponseDto는 삭제 가능.

### 4. 스펙 필드명 불일치 3종 — 프론트 연동 시 조용히 깨짐
- `MessageUpdateRequestDto.java:8` — `newMessage` (스펙 `newContent`) → 프론트가 보낸 newContent는 null 바인딩, update가 null 가드로 무시 → **수정 요청이 에러 없이 무시됨**
- `UserStatusResponseDto.java:11` — `lastAccessAt` (스펙 `lastActiveAt`)
- `ReadStatusResponseDto.java:12` — `lastReadTime` (스펙 `lastReadAt`)
oasdiff/스펙 문서와 1:1 대조 권장 (9~13기 공통: 스펙 정합이 이번 미션 핵심 평가축).

### 5. 시각 갱신이 요청값을 무시하고 서버 시간 사용 — `BasicUserStatusService.java:73-75`
`updateByUserId`가 `request.newLastActiveAt()`를 꺼내지도 않고 `updateLastAccessAt()`(서버 now). 11·12·13기 반복 지적 패턴. 같은 PR에서 ReadStatus는 클라이언트 값(`newLastReadAt`)을 반영하도록 고쳐놓고 UserStatus만 옛 방식 — 비대칭. `ReadStatusCreateRequestDto.java:13-14`의 toEntity도 `lastReadAt`을 받아놓고 버림 (생성 시 lastReadTime=null로 시작).

## 🟡 Major

### 6. Swagger 문서화 미착수 — 의존성만 추가됨 (`build.gradle:26`)
springdoc 2.8.6은 넣었지만 @Tag/@Operation/@ApiResponse/OpenAPI 설정이 0개 — 자동 스캔 문서뿐. 미션5 필수 요구사항. 로드맵: ①`UserApi` 인터페이스에 문서 어노테이션, 컨트롤러는 implements (9~13기 5개 기수 공통 칭찬 패턴, springdoc이 인터페이스 어노테이션 상속) → ②나머지 도메인 복제 → ③에러 응답까지. (11기 멘토 1명은 "문서는 구현체에" 반대 — 컨벤션 선택지)

### 7. Channel 생성/수정 응답이 스펙 ChannelDto와 다름 — `ChannelResponseDto.java:9`
스펙 응답은 `{id, type, name, description, participantIds, lastMessageAt}`인데 create/update는 `{id, createdAt, updatedAt, type, name, description}` 반환. private 채널을 만들어도 응답에 참여자가 없음. find용 ChannelFindResponseDto는 스펙과 일치하므로 **응답 DTO를 하나로 통일**하면 해결 (privateChannelCreate에서 이미 readStatus를 다 만들어놓고 응답에만 안 씀).

### 8. 삭제 3종이 200 반환 — 스펙 204
`ChannelController.java:36`, `UserController.java:43`, `MessageController.java:37` — void 반환은 200. `@ResponseStatus(HttpStatus.NO_CONTENT)` 또는 `ResponseEntity.noContent().build()` (생성 201은 붙였는데 삭제 204만 누락 — 미션4 #61의 201 지적과 짝).

### 9. File 레포 findById가 "없음"을 RuntimeException으로 — `FileChannelRepository.java:46-51`
없는 id면 FileInputStream이 FileNotFoundException → RuntimeException → (2번 고쳐도) 500. Optional 계약 위반: "없음"은 `Optional.empty()`, 호출부 orElseThrow가 404 결정. `Files.exists()` 선확인 또는 FileNotFoundException만 empty 반환. FileUserRepository/FileMessageRepository/FileUserStatusRepository(:88, 이쪽은 NoSuchElementException 직접 던짐) 동일.

### 10. FileUserStatusRepository만 미션4 지적 잔존 — `:44,110` printStackTrace, `:63` listFiles null 미체크
save/update가 여전히 예외 삼킴(데이터 유실 무음), findAll의 listFiles null 체크도 없음(`FileChannelRepository.java:59`도 동일). PR 본문 "listFiles에 앞서서 npe 처리"가 User/Message에만 적용됨 — 한 군데 고칠 때 같은 패턴 전체 검색(Find in Files) 습관.

### 11. 업로드 IOException → NoSuchElementException(404) — `BasicBinaryContentService.java:35` (+BasicUserService:64,95, BasicMessageService:36)
파일 읽기 실패가 "해당 값이 존재하지 않습니다 404"로 응답 — 의미 불일치. FileProcessingException 같은 전용 예외 + ErrorCode 추가 (10·12기 반복 지적: bare 래핑/오용 금지).

## 🔵 Minor

- `build.gradle:7,34-38` — spring-ai-bom import 잔재 (사용하는 spring-ai 의존성 없음). start.spring.io 잔재면 삭제.
- `BasicChannelService.java:115` — `List<UUID> list` 만들고 미사용 (dead code), `:73` `channel1` 네이밍, `:66` findAllByUserId가 채널마다 find() 호출 → 채널당 메시지 전체 로드 (file 레포면 N×전체 파일 읽기)
- `User.java:27` — `private UserStatus userStatus` 필드 선언만 되고 어디서도 사용 안 함 (직렬화에도 섞임). 삭제.
- `BasicUserService.delete` — `binaryContentRepository.deleteById(user.getProfileId())` profileId null 가드 없음 (create/update는 있음)
- `MessageUpdateResponse.java` — 미사용 dead code
- `GlobalExceptionController.java:23` — 오타 "에상치 못한 오류 발행" → "예상치 못한 오류 발생"
- `ChannelRepository.java:19` "// 업데이트 가읎어", `FileChannelRepository.java:85` "// 중복ㅋ" — 혼잣말 주석 정리
- UserService 인터페이스가 `Optional<User>`(도메인 엔티티) 노출 — findByUsername/findByEmail은 내부용이면 인터페이스에서 제외 고려

---

## 복붙용 코멘트 위치 (head 검증 완료, 경로 앞 src/main|test/java/com/sprint/mission/discodeit/)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| 테스트 문법 오류 (대표) | `test .../BasicReadStatusServiceTest.java:122` | `update(readStatus.getId(), );` |
| 테스트 인자 불일치 | `test .../BasicUserServiceTest.java:88` | `new UserUpdateRequestDto(created.profileId()` |
| DiscodeitException 핸들러 부재 | `common/exception/GlobalExceptionController.java:21` | `@ExceptionHandler(Exception.class)` |
| password 노출 | `auth/dto/AuthLoginResponseDto.java:12` | `String password,` |
| password 노출 (조립부) | `auth/application/basic/BasicAuthService.java:37` | `user.getPassword()` |
| newMessage 필드명 | `message/dto/MessageUpdateRequestDto.java:8` | `String newMessage` |
| lastAccessAt 필드명 | `user/dto/userStatus/UserStatusResponseDto.java:11` | `Instant lastAccessAt,` |
| lastReadTime 필드명 | `readStatus/dto/ReadStatusResponseDto.java:12` | `Instant lastReadTime` |
| 요청 시각 무시 | `user/application/basic/BasicUserStatusService.java:75` | `userStatus.updateLastAccessAt();` |
| Swagger 로드맵 | `build.gradle:26` | `springdoc-openapi-starter-webmvc-ui` |
| Channel 응답 스펙 | `channel/dto/ChannelResponseDto.java:9` | `public record ChannelResponseDto(` |
| 삭제 204 (대표) | `channel/controller/ChannelController.java:36` | `public void delete` |
| findById RuntimeException | `channel/repository/file/FileChannelRepository.java:46` | `public Optional<Channel> findById` |
| printStackTrace 잔존 | `user/repository/file/FileUserStatusRepository.java:44` | `e.printStackTrace();` |
| IOException→404 | `binaryContent/application/basic/BasicBinaryContentService.java:35` | `throw new NoSuchElementException();` |
| spring-ai 잔재 | `build.gradle:36` | `spring-ai-bom` |
| dead code | `channel/application/basic/BasicChannelService.java:115` | `List<UUID> list =` |
| 칭찬: gitignore 복구 | `.gitignore` | `.discodeit/` |
| 칭찬: User.create | `user/domain/User.java:36` | `public static User create` |
| 칭찬: part 이름 | `user/controller/UserController.java:31` | `@RequestPart(value = "userCreateRequest")` |
