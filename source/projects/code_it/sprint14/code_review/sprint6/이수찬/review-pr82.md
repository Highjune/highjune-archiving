# 코드 리뷰 — [이수찬] 스프린트 미션 6 (PR #82)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/82
- **작성자**: lsc0869 (이수찬), head `lsc0869:이수찬` → base `이수찬` ✅ (main 아님)
- **규모**: +1910 / −732, 82 files, 커밋 11개
- **라벨**: 격려🌱 + 실질 지적 (미션3 재제출하던 상황에서 컨트롤러 계층 + JPA 전환까지 한 번에 완주 — 성장 폭 큼. 단 "급하게 했다"는 본인 말대로 마무리 구멍 존재)
- **참고**: 8~13기 인사이트 반영 (`reference/sprint6-past-cohort-review-insights.md`)

> diff 전체(3419줄) 확인, 라인은 head 브랜치 raw 파일 grep 검증 완료.

---

## 총평 — JPA 전환의 뼈대(연관관계·변경 감지·스토리지 분리)는 정확히 잡았다. 그런데 🔴 3개: ①BasicUserService만 @Transactional 누락 → 유저 수정이 DB에 반영 안 됨 ②비밀번호 변경이 조용히 무시됨 ③재시작할 때마다 schema.sql이 전체 데이터를 DROP

**잘한 것 (이번 PR의 성과):**
- **연관관계를 처음부터 객체 참조 + LAZY 통일로 매핑** — UUID FK 필드로 갔다가 지적받는 게 과거 기수 단골 패턴(13기 #110 등)인데 처음부터 정석으로. ReadStatus의 `(user_id, channel_id)` unique 제약까지.
- **schema.sql DDL 품질** — FK마다 ON DELETE CASCADE / SET NULL을 구분해서 설계 (`messages.author_id SET NULL`, `read_statuses CASCADE` 등). 8기 때 멘토들이 "스키마 좋은데요" 하던 수준.
- **변경 감지 이해** — `ReadStatusService.java`의 "save() 불필요 - 변경 감지로 자동 반영" 주석. 개념을 정확히 알고 씀 (9기 #130 "dirty checking 하신 점 아주 좋습니다" 칭찬 패턴).
- **@ConditionalOnProperty 스토리지 스위칭 + @Value root-path 외부화** (`LocalBinaryContentStorage`), **제네릭 PageResponseMapper** (9기 멘토들 칭찬 패턴), **@PageableDefault(size=50, createdAt desc)** 스펙 기본값 정확.
- **JCF/File 레포·구 인터페이스·Main.java 전부 삭제** — "삭제까지가 완료" 원칙 이행. docker-compose까지 제공.

---

## 🔴 Critical

### 1. `BasicUserService`만 클래스 레벨 `@Transactional` 누락 → 유저 수정(PATCH)이 DB에 반영 안 됨 — `BasicUserService.java:23-25`
다른 서비스 6개(Channel/Message/ReadStatus/UserStatus/BinaryContent/Auth)에는 전부 클래스 레벨 `@Transactional`이 있는데 여기만 없음. `read`/`readAll`엔 메서드 레벨 `@Transactional(readOnly=true)`가 있지만 **`create`/`update`/`delete`는 트랜잭션 없이 실행**됨.

특히 `update()`(`:70-95`)가 문제: `user.update(...)`로 필드만 바꾸고 `save()`를 안 하는 변경 감지 방식인데, **트랜잭션이 없으면 변경 감지 flush가 보장되지 않는다**. 프로필 없이 이름/이메일만 수정하는 요청은 응답으로는 바뀐 값이 나가지만 DB에는 저장 안 되는(응답 200 + 데이터 유실) 최악의 조합. 프로필을 같이 보내면 `binaryContentRepository.save()`의 커밋에 편승해 우연히 반영될 수도 있어서 "테스트할 땐 됐는데?" 가 나올 수 있는 함정.
- 9기 #137에서 멘토가 정확히 같은 지적: "BasicUserService에 전체적으로 @Transactional이 빠져있는것 같네요"
- **수정**: 다른 서비스와 동일하게 클래스에 `@Transactional` 부여.

### 2. 비밀번호 변경이 조용히 무시됨 — `BasicUserService.java:74`, `User.java:43-46`
`UserUpdateRequestDto`엔 `newPassword`(`:6`)가 있는데 `user.update(requestDto.newUsername(), requestDto.newEmail())`로 **username/email만 전달**. `User.update(String, String)`에 password 파라미터 자체가 없음. 클라이언트가 비밀번호를 바꿔도 에러 없이 그냥 무시 → 스펙 불일치이자 사용자 입장에선 "바꿨는데 옛 비밀번호로 로그인되는" 버그.
- **수정**: `User.update(name, email, password)`로 확장 + null 가드.

### 3. 재시작할 때마다 데이터 전멸 — `schema.sql:1-8` + `application.yaml:18-20`
`sql.init.mode: always` + schema.sql 첫 8줄이 `DROP TABLE IF EXISTS ... CASCADE`. **앱을 재시작하는 순간 모든 테이블이 DROP되고 다시 만들어진다.** 지금은 개발 편의지만 이대로면 "영속화하려고 DB로 옮겼는데 재시작하면 다 날아가는" 자기모순.
- **수정 택1**: ① DROP 제거하고 `CREATE TABLE IF NOT EXISTS` ② 최초 1회 실행 후 `mode: never` ③ (권장) 스키마 확정 후 `ddl-auto: validate`로 정합성 검증 — 11기 #122·13기 #101 멘토들 공통 권장. 참고로 `schema.sql:8`의 `DROP TYPE channel_type`은 만든 적 없는 타입이라 dead line.

---

## 🟡 Major

### 4. `RuntimeException → 404` 매핑 — 모든 서버 오류가 404로 위장됨 — `GlobalExceptionHandler.java:16-18`
NoSuchElementException을 404로 보내려는 의도는 알겠는데, RuntimeException을 통째로 잡으면 **NPE, UncheckedIOException(파일 저장 실패), LazyInitializationException 등 진짜 500짜리 서버 버그가 전부 404 "Not Found"로 나감** → 디버깅할 때 원인을 계속 "없는 리소스"로 오인하게 됨.
- **수정**: `@ExceptionHandler(NoSuchElementException.class)` → 404, 나머지 RuntimeException은 로그 남기고 500. (다음 단계로는 커스텀 예외 — 8기 때부터 멘토들이 "RuntimeException은 의미가 너무 광범위"라고 반복 지적한 항목.)

### 5. `PageResponse`에 `hasNext` 누락 — Slice를 쓰는 이유가 사라짐 — `PageResponse.java:5-10`, `PageResponseMapper.java:13-25`
스펙의 PageResponse는 `content/number/size/hasNext/totalElements`. 지금은 `hasNext`가 없어서 **클라이언트가 다음 페이지 존재 여부를 알 수 없다**. `fromSlice`에서 `slice.hasNext()`를 이미 갖고 있는데 버리는 중 — 필드 하나 추가로 해결.

### 6. Message 응답 DTO 필드명 스펙 불일치 — `MessageResponseDto.java:8-15`
`userId`(스펙 `authorId`), `text`(스펙 `content`), 그리고 `createdAt`/`updatedAt` 누락. createdAt 내림차순으로 페이지네이션하면서 정작 응답엔 시각이 없어서 프론트가 시간순 표시를 못 함. 스펙 필드명 불일치는 프론트 연동 시 에러 없이 조용히 깨지는 유형이라 우선 정리 권장 (sprint5 때부터의 원칙: 스펙 우선).

### 7. 삭제/교체 시 파일·BinaryContent 고아 잔존 — `BinaryContentStorage.java`, `BasicUserService.java:76-80`
- `BinaryContentStorage`에 **delete가 없음** → DB 메타만 지워지고 `.discodeit/storage`의 실제 파일은 영원히 남음 (11기 #124: "Storage에 delete(UUID) 추가해서 함께 정리")
- 유저 프로필 교체 시(`updateProfile`) 옛 BinaryContent 레코드+파일 고아
- 유저/메시지 삭제 시 profile·attachments의 binary_contents 레코드+파일 고아 (DDL의 SET NULL/CASCADE는 연결만 끊지 파일은 못 지움 — 10기 #184 동일 지적)
- **수정**: Storage에 `delete(UUID)` 추가, 서비스 삭제 흐름에서 함께 정리.

### 8. N+1 + 전체 로드 후 메모리 필터 — `BasicChannelService.java:107-131`
`findAllByUserId`가 ①`channelRepository.findAll()`로 전 채널 로드 후 자바에서 필터 ②채널마다 `findTopByChannel_Id...`(마지막 메시지) + `findAllByChannel_Id`(참여자) 쿼리 → 채널 100개면 쿼리 200+개. 전 기수 리뷰 1위 테마.
- **수정 방향**: PUBLIC + 내 ReadStatus 채널만 쿼리로 가져오기("쿼리로 가능한 일은 DB에서" — 11기 #124), lastMessageAt/participants는 채널 ID 목록으로 IN 배치 조회 후 Map으로 조립(2-step). 당장 완벽하지 않아도 되지만 문제 인지는 필수.

### 9. OSIV 미설정 — `application.yaml`
13기에선 명시 요구사항이었던 `spring.jpa.open-in-view: false`가 없음. 지금 이 프로젝트에선 OSIV 기본값(true)이 🔴1의 트랜잭션 누락을 부분적으로 가려주고 있는 상태라, **끄는 순간 숨어 있던 문제가 드러나는 구조**. 🔴1 수정과 세트로 `open-in-view: false` 권장.

### 10. `.ser` 파일 + 업로드 실파일 커밋 — `user.ser`, `userStatus.ser`, `.discodeit/storage/6cb5d3d1-...`
sprint 초기에 지적됐던 `.ser` 커밋이 다시 등장 + 이번엔 스토리지 업로드 파일까지. `.gitignore`에 `*.ser`, `.discodeit/` 추가하고 `git rm --cached`로 제거 (8기 #59 "git history에서도 제거해주시구요").

### 11. 로그인 응답 201 Created — `AuthController.java:24`
로그인은 리소스 생성이 아니므로 200 OK가 맞음 (스펙도 200).

---

## 🔵 Minor

### 12. 패키지/네이밍 컨벤션
- `Controller` 패키지 대문자 (자바 패키지는 소문자: `controller`)
- `IService` 패키지명 + `I` 접두사 혼재: `ChannelService/MessageService/UserService`는 접두사 없고 `IBinaryContentService/IReadStatusService/IUserStatusService`는 있음. 자바 관례는 접두사 없이 인터페이스가 본명(`BinaryContentService`), 구현체가 `BasicBinaryContentService`. 패키지도 기존처럼 `service`에.
- `UserStatusUpdateDto` — 다른 곳은 전부 `*UpdateRequestDto`.
- `findAllByChannelIdOrderBy...` vs `findTopByChannel_Id...` — 언더스코어 표기 혼용(둘 다 동작하지만 한쪽으로 통일).

### 13. 잔재 정리 ("삭제까지가 완료")
- `DiscodeitApplication.java:49` 이하 40줄 주석 블록 + 미사용 `setupUser/setupChannel/messageCreateTest` — 실행 검증용이었다면 삭제
- `MessageService.java:17` — `// ← 이렇게 바꾸기` 작업 메모 잔존
- `UserStatusRepository.java:3` — 미사용 DTO import (Repository가 DTO를 아는 것처럼 보여 오해 소지)
- `@RequestMapping(method=...)` vs `@PostMapping/@GetMapping` 혼용 — 축약형으로 통일 권장

### 14. 가벼운 언급
- 비밀번호 평문 저장/비교 — 다음 스프린트(Security)에서 다루겠지만 인지하고 있을 것 (9기 #125 P1 지적 항목)
- DB 비밀번호 yaml/docker-compose 하드코딩 — 환경변수 분리 습관
- `BasicEntity`의 `@EqualsAndHashCode(of="id")` — `GenerationType.UUID`는 persist 전 id가 null이라 비영속 상태 비교가 깨질 수 있음. 당장 문제는 아니지만 JPA equals/hashCode 함정으로 알아두기
- `BaseUpdatableEntity`는 abstract가 아님 — BasicEntity처럼 abstract로
- Message:BinaryContent를 `@ManyToMany`로 매핑 — "한 첨부가 여러 메시지에 공유되는 경우가 있을까?" 관점에선 `@OneToMany + @JoinTable`이 관계를 더 정확히 표현 (8기 #52·11기 #119 공통 질문). 다만 조인 테이블 스키마가 스펙 그대로라 동작엔 문제 없음

---

## 다음 스텝 제안 (심화 여력이 있다면)
1. 커서 기반 페이지네이션 — 단, createdAt 단독 커서는 동시각 누락 위험, **(createdAt, id) 복합 커서**로 (전 기수 공통 지적)
2. MapStruct 도입 — 수동 `from()` 정적 팩토리도 훌륭하지만, 도입 시 "Mapper에 Repository 주입 금지" 원칙 유지
3. 파일 저장을 트랜잭션 커밋 이후로 분리 (`TransactionSynchronizationManager`) — DB 롤백 시 고아 파일 방지
