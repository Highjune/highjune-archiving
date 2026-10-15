# 코드 리뷰 — [이승현] 스프린트 미션5 (PR #78)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/78
- **작성자**: Hanna-log (이승현)
- **범위**: RESTful API 재설계 + springdoc(Swagger) + Postman (심화 X), 미션4 리뷰 반영 포함
- **규모**: +2489 / −240, 84 files, head `Hanna-log:LSH14` → base `이승현` ✅ (base 올바름)
- **라벨**: 미완성🛠️ + 지각제출⏰ → **격려 톤 + 복구 로드맵 중심**
- **참고**: 9~13기 동일 미션 멘토 리뷰 인사이트 반영 (`reference/sprint5-past-cohort-review-insights.md`)

> diff 전체(3681줄) 확인, 라인은 head raw 파일 grep 검증 완료.

---

## 총평 — "미완성" 라벨이 무색하게 골격은 거의 완성. 남은 건 ①스펙 필드명 정합 ②검증 핸들러 ③Swagger 상세 문서화

컨트롤러 6종 + DTO + 서비스 + ConditionalOnProperty 레포 스위칭까지 다 있음. 미션4 피드백(예외 enum 통합, ErrorResponse, 201, @RequestPart, 로그) 성실 반영.
가장 큰 리스크는 **@JsonProperty 커스텀 키가 API 스펙을 조직적으로 깨뜨리는 것** — 프론트 연동 시 전 도메인 바인딩 실패.

**잘한 것들:**
- 예외 15개 클래스 → ErrorCode enum + DiscodeitException + GlobalExceptionHandler 3개로 재설계, 404/409/400/401/500 상태코드 세분화 (미션4 피드백 정확 이행. 11기 멘토가 "실무 정석"이라 한 패턴)
- `@ConditionalOnProperty`(jcf/file, matchIfMissing) + `@Value` 파일 경로 주입 — 싱글턴 getInstance 제거, 테스트 가능 구조
- `Channel.update()`에 PRIVATE 채널 수정 금지 규칙 — 도메인 로직 제자리
- findAllByUserId = 공개 + 참여 중 비공개 채널 정확 구현
- @RequestPart 정석 multipart, 프로필/첨부 선택 처리, 채널 삭제 시 메시지·ReadStatus 연쇄 정리
- BaseEntity/UpdatableEntity 분리 + @FieldDefaults(makeFinal)+@NonFinal 활용

---

## 🔴 스펙 불일치 / 실질 버그

### 1. `@JsonProperty` 커스텀 키 전면 — API 스펙 파괴 (프론트 연동 불가)
- `UserDto.java:11-19` — "user_id", "user_username", "user_email", "user_nickName", "user_profileId"
- `ChannelDto.java:14,16` — "channel_type", "channel_name"
- `MessageDto.java:13` — "message_contents"
- `ReadStatusDto.java:12`, `UserStatusDto.java:12` — "user_id"
스펙은 `id`, `username`, `type`, `name`, `content`… 카멜 키. @JsonProperty 전부 제거하면 record 컴포넌트 이름 그대로 나감.
**요청 쪽도 동일 계열**: `LoginRequest.java:4` `userName`(스펙 `username` — 프론트가 보낸 username이 null 바인딩 → 로그인 항상 401), `UserCreateRequest.java:9` `userName` + `:15` `nickName`(스펙 외 필드), `MessageCreateRequest.java:9` `contents`(스펙 `content`). oasdiff로 본인 스펙과 대조 권장 (미션 안내에도 포함된 도구).

### 2. @Valid 검증 실패가 500으로 응답 — `GlobalExceptionHandler.java:24`
MethodArgumentNotValidException 핸들러가 없어 @NotBlank 위반이 Exception 핸들러로 떨어져 INTERNAL_SERVER_ERROR(500). 정성껏 단 검증 메시지가 클라이언트에 전달 안 됨. 400 핸들러 추가 (10기 멘토 반복 지적 항목). MultipartException/HttpMessageNotReadableException도 함께 고려.

### 3. `BasicBinaryContentService.delete`가 삭제를 안 함 — `BasicBinaryContentService.java:45`
findById().orElseThrow만 하고 `binaryContentRepository.delete(id)` 호출 없음. 존재 확인만 하고 반환.

### 4. 메시지 첨부파일 size 항상 0 — `BasicMessageService.java:51`
BinaryContent.builder()에 `.size()` 누락. 본인이 만든 `BinaryContentService.create`(size 계산 있음)를 재사용하면 중복 코드와 버그가 동시에 사라짐.

### 5. 로그인 응답 online 항상 false — `BasicAuthService.java:36`
UserDto의 online을 false 하드코딩. UserStatus 조회(또는 로그인 시 lastActiveAt 갱신 후 isOnline()) 필요. 로그인 직후 프론트에 오프라인으로 표시됨.

## 🟡 Major

### 6. 삭제 API가 200 반환 — 스펙은 204
`ChannelController.java:62`, `MessageController.java:76`, `UserController.java:79` — void 반환 = 200. `ResponseEntity.noContent().build()`로 (PR 본문에 "생성 201 반영"은 했는데 삭제 204는 누락).

### 7. Swagger 문서화가 @OpenAPIDefinition 하나뿐 (미완성 라벨의 핵심) — 복구 로드맵
DiscodeitApplication의 전역 정보만 있고 @Tag/@Operation/@ApiResponse 없음 → 자동 스캔 수준 문서.
**추천: `XxxApi` 인터페이스 분리 패턴** — 문서 어노테이션은 인터페이스에, 컨트롤러는 implements (9~13기 5개 기수 멘토 공통 칭찬 패턴). 컨트롤러 가독성 유지 + 명세 선정의 가능. 순서: ①UserApi 하나로 패턴 확립 → ②나머지 5개 복제 → ③에러 응답(@ApiResponse + ErrorResponse 스키마)까지.

### 8. UserUpdateRequest @NotBlank vs 서비스 null 체크 모순 — `UserUpdateRequest.java:6,8`
둘 다 @NotBlank인데 BasicUserService.update는 `if (request.nickName() != null)` 부분 수정 로직 — @NotBlank가 null을 거부하므로 부분 수정 불가능, null 체크는 죽은 코드. PATCH 의미론에 맞게 검증 제거(선택 필드) or 정책 결정.

### 9. UserStatus/ReadStatus 갱신 요청 null 방어 없음 → NPE — `UserStatusUpdateRequest.java:6`
lastActiveAt에 @NotNull 없음(2번과 결합하면 500 두 겹). null이 들어오면 updateLastActiveAt(null) 저장 → 이후 `UserStatus.java:35` `lastActiveAt.isAfter(...)`에서 NPE. ReadStatusUpdateRequest.lastReadAt 동일.

### 10. 유저 삭제 시 ReadStatus 정리 누락 — `BasicUserService.java:131`
프로필+UserStatus는 정리하는데 유저의 ReadStatus는 잔존(채널 쪽 삭제는 정리함 — 비대칭). 고아 데이터.

### 11. 본인이 만든 findByUserId 안 쓰고 findAll 스캔 — `BasicUserService.java:139,150`
isOnline()과 delete()에서 `userStatusRepository.findAll().stream().filter(...)` — UserStatusRepository.findByUserId가 이미 있음. file 레포면 유저 목록 조회마다 전체 파일 N회 로드 (10·11기 멘토 반복 지적: 전용 조회 메서드 활용).

### 12. 컨트롤러에서 orElseThrow — `BinaryContentController.java:43`
서비스가 Optional을 반환하고 컨트롤러가 예외를 만들어 던짐. 예외 판단은 서비스 책임으로 (다른 컨트롤러들과도 비일관). BinaryContentService가 엔티티를 반환하는 것도 이 기회에 DTO로 통일 권장.

## 🔵 Minor

- `UserCreateRequest.java:19-63` — 45줄 학습 주석 잔존 (PR 본문 "공부 주석 전부 제거 완료"와 불일치. 학습 노트는 별도 저장소/노션으로!)
- `GlobalExceptionHandler.java:18` — `log.warn("[{}] {}", errorCode, errorCode)` 같은 인자 2번, 메시지 누락 → 두 번째는 `exception.getMessage()`.
- `MessageController.java:45` — IOException을 bare RuntimeException 래핑 → 5번 계열. 커스텀 예외(ErrorCode 활용)로 (10·12기 반복 지적).
- `UserController.java:52` — @PostMapping과 메서드 사이 빈 줄. DiscodeitApplication·UserStatus 끝의 빈 줄 뭉치. IDE 포매터 일괄 적용 권장.
- `.gitignore`에 `*.ser` 추가한 것 좋음 (13기 지적 사항 선제 반영).
- (참고·실무 예고) `BinaryContentDto`의 `byte[] bytes` — 스펙에 있으니 지금은 유지. 실무에선 메타데이터/다운로드 분리(Base64 팽창·메모리) — 다음 스프린트 storage와 연결.

---

## 복붙용 코멘트 위치 (head 검증 완료, 경로 앞 src/main/java/com/sprint/mission/discodeit/)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| JsonProperty 스펙 파괴 (대표) | `dto/user/UserDto.java:11` | `@JsonProperty("user_id")` |
| LoginRequest userName | `dto/auth/LoginRequest.java:4` | `String userName,` |
| 검증 500 | `exception/GlobalExceptionHandler.java:24` | `@ExceptionHandler(Exception.class)` |
| BinaryContent 미삭제 | `service/basic/BasicBinaryContentService.java:45` | `public void delete(UUID id)` |
| 첨부 size 0 | `service/basic/BasicMessageService.java:51` | `BinaryContent.builder()` |
| 로그인 online false | `service/basic/BasicAuthService.java:36` | `false,` |
| 삭제 200 (대표) | `controller/ChannelController.java:62` | `public void delete` |
| Swagger 로드맵 | `DiscodeitApplication.java:9` | `@OpenAPIDefinition` |
| NotBlank 모순 | `dto/user/UserUpdateRequest.java:6` | `@NotBlank ... nickName` |
| lastActiveAt NPE | `dto/userstatus/UserStatusUpdateRequest.java:6` | `Instant lastActiveAt` |
| ReadStatus 잔존 | `service/basic/BasicUserService.java:131` | `public void delete(UUID id)` |
| findAll 스캔 | `service/basic/BasicUserService.java:150` | `userStatusRepository.findAll()` |
| 컨트롤러 orElseThrow | `controller/BinaryContentController.java:43` | `.orElseThrow(` |
| 학습 주석 | `dto/user/UserCreateRequest.java:19` | `/*` |
| log.warn 중복 인자 | `exception/GlobalExceptionHandler.java:18` | `log.warn("[{}] {}"` |
| RuntimeException 래핑 | `controller/MessageController.java:45` | `throw new RuntimeException(` |
| 칭찬: 예외 재설계 | `exception/ErrorCode.java:5` | `public enum ErrorCode` |
| 칭찬: 레포 스위칭 | `repository/file/FileUserRepository.java:11` | `@ConditionalOnProperty` |
| 칭찬: PRIVATE 수정 금지 | `entity/Channel.java` update() | `PRIVATE_CHANNEL_UPDATE` |
