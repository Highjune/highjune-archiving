# 코드 리뷰 — [김양현] 스프린트 미션6 (PR #83)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/83
- **작성자**: yyy2724 (김양현), head `yyy2724:김양현` → base `김양현` ✅
- **규모**: +2112 / −2326, 80 files (JCF/File 레포 삭제 + 정적 자산 교체 포함)
- **라벨**: 시간부족 미완성🛠️ + 재지적 포함 — 본인도 "완성 못 한 것들이 있다"고 명시
- **참고**: 8~13기 인사이트 (`reference/sprint6-past-cohort-review-insights.md`)

> diff 전체(5825줄) 확인 + 핵심 파일 head raw 검증 완료. 라인은 raw 기준.

---

## 총평 — JPA 전환의 방향(객체 참조 연관관계, 변경 감지, cascade)은 맞게 잡았으나, 빌드가 깨져 있고 실행해도 메시지 목록·첨부가 동작하지 않는 상태. "push 전 빌드 1회 + FE로 시나리오 1회" 검증 루틴이 이번에도 핵심 과제

**잘한 방향:**
- 전 엔티티를 UUID FK 필드가 아닌 **객체 참조 + 연관관계 매핑으로 전환** (Message.channel/author, ReadStatus.user/channel, User.profile/userStatus)
- `// 변경 감지` 주석과 함께 save/update 호출 제거 — 영속성 컨텍스트 개념 이해
- 스펙 형태의 DTO 정의: MessageDto(content/author 객체/attachments), UserDto(profile 객체/online), ChannelDto(participants/lastMessageAt), **PageResponse에 hasNext 포함** (스펙 정확)
- sprint5 지적 일부 반영: 테스트 문법 오류 수정 시도, UserStatusDto lastActiveAt 필드명, User 생성 정적 팩토리 유지
- 매핑표·DTO 문서 작성, cascade를 DB(@OnDelete)와 엔티티 양쪽에서 고민한 흔적

**그러나 제출 상태 기준:**
- `./gradlew build` **컴파일 실패** (테스트가 삭제된 클래스 참조) — sprint5 🔴1과 동일한 반복
- 실행해도: 메시지 목록 조회 500(sort 오타) → 첨부 저장 안 됨(storage.put 누락) → 첨부 테이블명 불일치 SQL 오류 → 채널 조회 참여자 쿼리 매핑 오류
- sprint5 재지적 2건 미해결: 로그인 password 노출, MessageUpdateRequestDto.newMessage

---

## 🔴 Critical — 빌드/실행을 막는 것 (우선순위순)

### 1. 테스트 컴파일 실패 → `./gradlew build` 불가 (sprint5 반복)
- `BasicUserServiceTest.java:13-16, 37-38` — 이번 PR에서 **삭제한** `JCFUserRepository/JCFUserStatusRepository/JCFBinaryContentRepository`를 여전히 import·생성
- `BasicUserServiceTest` — BasicUserService 생성자가 4개 인자(BinaryContentStorage 추가)로 바뀌었는데 3개로 호출
- `BasicReadStatusServiceTest.java:90, 120` — `readStatusRepository.findAllByUserId(...).get(0)` — 반환이 Optional로 바뀌어 `.get(0)` 컴파일 에러
- sprint5 때 "형태만 다른 반복"이라고 지적했던 그 패턴. **push 전 `./gradlew build` 1회** 습관이 최우선. JCF 삭제로 테스트가 전부 깨졌으니, 이번 스프린트 범위에선 테스트를 JPA 슬라이스(@DataJpaTest)로 옮기거나 임시로 삭제하는 결단도 방법.

### 2. 메시지 첨부파일의 실제 바이트가 어디에도 저장 안 됨 — `BasicMessageService.java:47-66`
create()에서 BinaryContent 메타(파일명/크기/타입)만 만들고 **`binaryContentStorage.put()` 호출이 없음**. cascade로 DB 행은 생기지만 `.discodeit/storage`에 파일이 없어 **첨부 다운로드가 전부 실패**(UncheckedIOException→500). 유저 프로필 생성 경로(`BasicUserService.java:57-59`)는 put을 정확히 하고 있으니 같은 패턴으로 추가하면 됨.

### 3. 프로필 "수정" 경로도 저장 누락 — `BasicUserService.java:106-117`
update()에서 새 BinaryContent를 만들고 `user.updateProfile()`만 호출 — `binaryContentRepository.save` 주석 처리(:117), **storage.put도 없음**. cascade로 행은 저장돼도 파일이 없어 교체된 프로필 이미지가 깨짐. 구 프로필 행·파일 정리도 없음(orphanRemoval은 걸려 있으나 파일은 남음).

### 4. `sort = "createAt"` 오타 → 메시지 목록 조회가 항상 500 — `MessageController.java:50`
Message에 `createAt` 속성이 없어 PropertyReferenceException. `createdAt`으로 수정. **이 한 글자 때문에 채팅 화면 자체가 안 뜸** — FE 켜서 채널 하나 클릭만 해봤어도 잡혔을 버그라, 2번 검증 루틴(시나리오 1회)이 필요한 이유.

### 5. 첨부 조인테이블 이름 불일치 — `Message.java:40` vs `schema.sql:69`
엔티티는 `@JoinTable(name = "message_attachments")`(복수), schema.sql은 `message_attachment`(단수). ddl-auto: none이라 Hibernate가 없는 테이블에 INSERT → "relation does not exist" SQL 오류. 둘 중 하나로 통일 (스펙 ERD 기준 복수 권장). 참고: 이 테이블에 PK/unique도 없음 — `(message_id, attachment_id)` PK 권장.

### 6. ReadStatusRepository 파생 쿼리 시그니처 2건 — `ReadStatusRepository.java:17, 19`
- `:19 Optional<ReadStatus> findAllByUserId(UUID)` — "findAll"인데 Optional. 유저가 **채널 2개 이상 참여하면 IncorrectResultSizeDataAccessException**. 서비스는 `Optional.stream()` 덕에 컴파일되지만 최대 1건만 반환. `List<ReadStatus>`로.
- `:17 List<UUID> findAllByChannelId(UUID)` — 파생 쿼리는 ReadStatus 엔티티를 반환하므로 UUID 리스트로 자동 변환되지 않음(파일 레포 시절 "참여자 userId 목록" 시그니처를 그대로 이식). 참여자 id가 필요하면 `@Query("select r.user.id from ReadStatus r where r.channel.id = :channelId")`로 명시. 사용처: `BasicChannelService.java:55, 73`.

### 7. 재시작마다 데이터 전멸 — `application.yaml:26` + `schema.sql:1-7`
`sql.init.mode: always` + schema.sql 첫 7줄 `DROP TABLE ... CASCADE` → 앱 재시작할 때마다 전체 삭제. DROP 제거 + `CREATE TABLE IF NOT EXISTS`, 또는 스키마 확정 후 `ddl-auto: validate` (11·13기 멘토 공통 권장). ※ 이수찬 PR에도 동일 패턴이 있어 같은 코멘트를 남김.

## 🔴 sprint5 재지적 (미해결 이월)

### 8. 로그인 응답 password 노출 — `AuthLoginResponseDto.java:14`, `BasicAuthService.java:40`
sprint5 #71 🔴3에서 지적한 항목. 이번에 profileId→profile 중첩 객체로 바꾸면서 **password는 그대로 남음**. 이미 만들어둔 UserDto(password 없음, online 포함)를 재사용하면 스펙까지 한 번에 해결.

### 9. `MessageUpdateRequestDto.newMessage` — 스펙은 `newContent` (sprint5 🔴4 이월)
FE가 보내는 newContent는 null 바인딩 → `message.update(null)` → **Message.update에 null 가드가 없어 내용이 null로 덮어써짐**(sprint5 때는 "무시"였는데 지금은 더 나빠짐). 필드명 정정 + update null 가드.

## 🟡 Major

### 10. Mapper NPE 2곳 — null 가드 필요
- `UserMapper.java:22` — 프로필 없는 유저면 `binaryContentMapper.toDto(null)` → NPE (BinaryContentMapper에 null 체크 없음)
- `MessageMapper.java:30` — 작성자 탈퇴(SET_NULL) 메시지면 `userMapper.toDto(null)` → NPE
- 메시지 목록·채널 참여자 조회가 500으로 터지는 경로. from/toDto에 null → null 반환 가드.

### 11. ChannelDto·ChannelMapper 만들어놓고 미사용 — 스펙 응답 미적용
서비스는 여전히 구 `ChannelResponseDto/ChannelFindResponseDto` 반환. 새 FE는 ChannelDto(participants=UserDto 목록) 형태를 기대하므로 채널 화면이 어긋남. 본인이 말한 "완성 못 한 것"의 핵심 — **채널 서비스가 ChannelMapper.toDto를 쓰도록 연결**하는 것이 주말 작업 1순위. (UserController의 UserResponseDto → UserDto 전환도 동일)

### 12. N+1 + 전체 로드 — `BasicChannelService.java:70-77, 55-61`
findAllByUserId: `findAll()` 후 채널마다 readStatus 쿼리, 그리고 `find()` 재호출로 **채널마다 메시지 전체를 로드해 max 계산**(:58). lastMessageAt은 `findTopByChannelIdOrderByCreatedAtDesc`로, 참여자는 IN 배치로. (전 기수 리뷰 1위 테마)

### 13. Storage에 delete 없음 + 삭제 시 파일·행 고아 — `LocalBinaryContentStorage.java`(put/get/download만)
채널/메시지/유저 삭제를 @OnDelete DB cascade에 위임했는데, message_attachments 행이 지워져도 **binary_contents 행과 실제 파일은 남음**. Storage에 delete(UUID) 추가 + 삭제 흐름에서 정리 (10~11기 공통 지적).

### 14. OSIV 미설정 — `application.yaml`
`spring.jpa.open-in-view: false` 추가 (13기 요구사항). 컨트롤러가 Mapper로 DTO 변환을 이미 하고 있으므로 끄는 비용이 낮은 상태.

## 🔵 Minor

- `.github/workflows/claude.yml` — Claude Code 리뷰 액션이 **조직 레포에 머지되면 전체 PR에 적용**될 수 있음. 개인 실험은 본인 fork에만 두고 이 PR에서는 제외 권장 (secrets가 없어 동작도 안 함).
- `@LastModifiedDate`(Auditing)와 `updateUpdatedAt(Instant.now())` 수동 갱신 공존 (`ReadStatus.updateTime`, `User.update`) — 하나로 통일 (10기 #182 동일 지적). Auditing이 있으니 수동 호출 제거.
- 패키지 정리: `common/entity/base/BaseEntity` vs `common/entity/BaseUpdatableEntity` — 같은 패키지로.
- 주석 처리된 구 메서드 대량 잔존 (UserRepository:3148-3158, UserStatusRepository, ChannelRepository 등) — "삭제까지가 완료".
- `ReadStatusCreateRequestDto.lastReadAt`을 무시하고 항상 `Instant.now()` (`ReadStatus` 생성자) — 요청값 사용.
- 구 설정 잔재 `discodeit.repository.type: file` — JCF/File 삭제했으니 제거.
- DB 비밀번호 하드코딩 + 비표준 포트 54322 — compose 파일이 PR에 없어 멘토가 재현 불가. .env 분리 + docker-compose 포함 권장.
- `defer-datasource-initialization: true`는 data.sql용 — schema.sql은 원래 Hibernate보다 먼저 실행되므로 불필요.
- `@ManyToOne`/`@OneToOne`에 LAZY 미지정 (기본 EAGER) — "기본적으로 안전하게 LAZY" (8기부터 반복).

---

## 주말 완성 로드맵 제안 (우선순위)
1. `./gradlew build` 통과 (테스트 정리) → 4번 오타 수정 → FE로 가입→채널→메시지→첨부 시나리오 1회
2. 2·3번 storage.put 추가, 5번 테이블명 통일, 6번 레포 시그니처
3. 11번 ChannelDto 연결(스펙 응답), 8·9번 sprint5 이월분
4. 여력 되면: Mapper null 가드, OSIV off, N+1
