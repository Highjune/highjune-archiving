# 코드 리뷰 — [김예준] 스프린트 미션 5 (PR #69)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/69
- **작성자**: kim-yejunn (김예준)
- **범위**: API 스펙 준수 RESTful 재설계 + springdoc-openapi(Swagger) + 심화(프론트 통합 + Railway 배포)
- **리뷰 범위**: "fix: 코드잇 제공 프론트로 변경, openapi 추가"(44ffc4d) 이후 미션5 커밋 8개만 (본인 안내)
- **라벨**: 매운맛🔥 ("필터 없이")
- **base `main`** ⚠️ / head `kim-yejunn:김예준` @ 7163310, 루트 `sprint-mission-1/`
- **배포**: https://14-sprint-mission-production.up.railway.app

> 미션5 커밋 범위 diff(6377줄, 정적 자산 제외 3437줄) 전체 확인. 라인은 head raw 검증 완료.

---

## 🔴 프로세스 — base가 `main` (머지 금지)

이수찬 #70과 동일. base를 `김예준` 브랜치로 변경 요청.

---

## 총평 — 이전 리뷰 피드백 전부 반영 + 배포까지. 다만 "전환 과정에서 새어 들어온 버그" 3개

**#58 피드백 반영 확인:**
- ✅ RPC 동사 URL → 자원 중심 (`/api/users`, `/api/channels/{channelId}`, 행위는 메서드로)
- ✅ lastReadAt/lastActiveAt을 updatedAt에서 분리해 도메인 필드로 복원 (ReadStatus:15, UserStatus:17-18 신설)
- ✅ 프로필 교체 순서 (신규 저장 성공 후 구 삭제) 유지
- ✅ 핸들러 커버리지 확장: HttpMessageNotReadableException + MultipartException 추가
- ✅ multipart @RequestPart 정석 (DTO에서 MultipartFile 분리 — 스펙 형태)
- ✅ 201/204 + Swagger @Tag/@Operation/@Parameter, alpha 정렬 설정까지

**심화**: 코드잇 프론트 통합 + Railway 배포 완료. 기수 중 배포까지 간 건 처음.

---

## 🔴 실질 버그 3건 (스펙 전환 중 유입)

### 1. `MessageResponseDto.from` — id 자리에 authorId — `message/dto/MessageResponseDto.java:13`
record는 `(UUID id, ..., UUID authorId, ...)`인데 from()의 첫 인자가 `message.getAuthorId()` (13행). 18행에도 또 authorId → **모든 메시지 응답의 id가 작성자 id**. 프론트가 이 id로 수정/삭제 요청하면 MESSAGE_NOT_FOUND. `message.getId()`로 수정.

### 2. `UserResponse`에 password 포함 — `user/dto/UserResponse.java:8,17`
생성·수정·로그인 응답에 **비밀번호 평문 노출**. 스펙 응답 스키마에도 없음. 필드 제거.
**교육 포인트**: 삭제된 ServiceIntegrationTest에 "응답에 패스워드가 포함되지 않는다" 테스트가 있었음 — 테스트를 지우자마자 그 테스트가 막던 버그가 실제로 들어온 사례.

### 3. `BinaryContent.size` 항상 0 — `binarycontent/entity/BinaryContent.java:24`
`private long size;`가 final이 아니라 @RequiredArgsConstructor 대상에서 제외 → 어떤 생성 경로(toBinaryContent 포함)에서도 설정 안 됨 → 응답 size 항상 0. `bytes.length`로 계산하거나 생성자에서 설정.

## 🟡 Major

### 4. ReadStatus 생성 시 lastReadAt 무시 — `readstatus/service/ReadStatusServiceImpl.java:42`
스펙 요청 필드로 lastReadAt을 추가(ReadStatusCreateRequestDto:14)해놓고 생성 시 2-인자 생성자만 호출 → 요청값 버려지고 lastReadAt=null로 시작. 생성자에 전달 필요.

### 5. 테스트 989줄 통삭제 — `ServiceIntegrationTest.java` (deleted)
DTO 개편으로 깨지자 수정 대신 전체 삭제. 위 1·2번 버그 모두 기존 테스트(response_hasNoPassword, message id 검증)가 잡을 수 있던 것들. 스펙 전환 같은 대규모 리네이밍이야말로 테스트가 가장 필요한 순간 — 새 DTO에 맞춰 복원 권장.

### 6. 예외 detail 키 "userId"→"authorId" 일괄 치환 사고
메시지 도메인에서만 맞는 이름인데 유저/상태/읽음 도메인 예외까지 전부 authorId로 바뀜 (UserServiceImpl:70,100,110,116,133,145,151 / UserStatusServiceImpl:30,36,67 / ReadStatusServiceImpl:38 / AuthServiceImpl). 에러 응답 details의 키가 오해 유발. 찾아바꾸기 범위 사고 — userId로 복원.

## 🔵 Minor

- `@ResponseStatus` + `ResponseEntity.status()` 이중 지정 (ChannelController:33 등) — 실제 응답은 ResponseEntity가 결정. springdoc 문서화 목적이면 `@ApiResponse(responseCode="201")`가 정석. 의도 확인 질문.
- 주석 처리된 코드 잔존 — UserStatusServiceImpl:49-51, 70-72.
- `application.yaml:2`의 `seed: true` — DataInitializer 삭제로 dead config (배포 데모용 시드가 사라진 것도 아쉬움 — 의도 확인).
- ChannelDto.from(channel) 1-인자 오버로드 미사용 추정.

---

## 복붙용 코멘트 위치 (head 검증 완료, 경로 앞에 sprint-mission-1/src/main/java/com/sprint/mission/discodeit/)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| id 자리 authorId (메인 버그) | `message/dto/MessageResponseDto.java:13` | `message.getAuthorId(),` (첫 인자) |
| password 노출 | `user/dto/UserResponse.java:8` | record 선언의 `String password` |
| size 항상 0 | `binarycontent/entity/BinaryContent.java:24` | `private long size;` |
| lastReadAt 무시 | `readstatus/service/ReadStatusServiceImpl.java:42` | `new ReadStatus(channelId, userId)` |
| 테스트 삭제 | `src/test/.../ServiceIntegrationTest.java` | (Files changed에서 deleted 파일) |
| authorId 치환 사고 (대표) | `user/service/UserServiceImpl.java:70` | `Map.of("authorId", userId)` |
| @ResponseStatus 이중 | `channel/controller/ChannelController.java:33` | `@ResponseStatus(HttpStatus.CREATED)` |
| 주석 코드 | `userstatus/service/UserStatusServiceImpl.java:49` | `// if (...userId()...)` |
| seed dead config | `src/main/resources/application.yaml:2` | `seed: true` |
| 칭찬: 스펙 URL 전환 | `user/controller/UserController.java:33` | `POST /api/users` multipart |
| 칭찬: lastActiveAt 분리 | `userstatus/entity/UserStatus.java:17` | `private Instant lastActiveAt;` |
