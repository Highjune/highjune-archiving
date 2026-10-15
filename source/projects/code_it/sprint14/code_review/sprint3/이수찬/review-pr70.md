# 코드 리뷰 — [이수찬] 스프린트 미션3 재제출 (PR #70)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/70
- **작성자**: lsc0869 (이수찬)
- **범위**: 스프린트3 전체 재작성 — 신규 도메인 3종(ReadStatus/UserStatus/BinaryContent) + 서비스 DTO 고도화 + AuthService + 신규 서비스 3종 (심화 x 표기)
- **규모**: +2596 / −0, 66 files 전부 신규, head `lsc0869:이수찬` → **base `main`** ⚠️
- **참고**: PR #66(미완성)의 재도전. #66의 크리티컬 이슈 전부 해소됨

> diff 전체(2991줄) 확인 완료. 코멘트 라인은 head raw 파일 grep으로 검증.

---

## 🔴 프로세스 — base가 `main`! 머지 금지

PR base가 `codeit-bootcamp-spring:main`으로 되어 있음. 머지하면 부트캠프 공용 main에 학생 코드가 들어감. **base를 `이수찬` 브랜치로 변경 요청** (PR 페이지 Edit → base 변경). #66도 열려 있다면 정리 안내.

---

## 총평 — #66의 숙제를 전부 해냄. 이번엔 "완결된" 제출

이전 PR의 컴파일 에러 4종이 모두 해결됨:
- ✅ UserService 인터페이스 DTO 시그니처로 재선언 (구현체와 정합)
- ✅ UserStatusRepository/BinaryContentRepository 메서드 선언 + File/JCF 구현 완비
- ✅ 파일명 분리 (channel.ser, message.ser, readStatus.ser…) — user.ser 충돌 해소
- ✅ UserStatus.lastActiveAt 갱신 가능 (final 제거 + update 메서드)
- ✅ Main.java 삭제, 생성자 호출부 정리

**추가로 잘한 것들:**
- 프로필/첨부 **선택적 등록** 정확 구현 (profileRequest null 허용 분기) — BasicUserService:38, BasicMessageService:33
- **연쇄 삭제**: user 삭제 → 프로필+상태 정리, message 삭제 → 첨부 정리, channel 삭제 → 메시지+ReadStatus 정리
- 중복 검증 레포 위임 유지 (existsByEmail/Name, existsByUserIdAndChannelId)
- `Optional` 활용 (findByName, findByUserId + orElseThrow)
- `UserStatus.isOnline()` 5분 규칙을 엔티티 메서드로 (도메인 로직 제자리)
- File 레포: 엔티티 수정 후 `save()` 재호출 습관 정확 (File 레포에선 필수)

---

## 🔴 실질 버그 5건

### 1. `BasicChannelService.delete`가 **채널 자체를 안 지움** — `BasicChannelService.java:96`
메시지·ReadStatus는 지우는데 `channelRepository.deleteById(id)` 호출이 없음. 삭제 후에도 채널이 계속 조회됨.

### 2. `find()`의 lastMessageAt이 **전체 채널의 메시지** 기준 — `BasicChannelService.java:59`
`messageRepository.findAll()`로 모든 채널의 메시지 중 최신 시각을 뽑음. 다른 채널에 메시지가 달려도 이 채널의 lastMessageAt이 바뀌어 보임. `findAllByChannelId(id)`로 (update()는 이미 올바르게 함 → :75와 비교).

### 3. `FileUserRepository.existsByEmail`이 **이름과 비교** — `FileUserRepository.java:53`
`user.getName().equals(email)` — 복붙 흔적. File 레포 사용 시(현재 @Primary) 이메일 중복 검증이 무력화됨. JCF 버전(:37)은 올바름.

### 4. `createPublic`의 중복 체크가 항상 통과 — `BasicChannelService.java:34`
`channelRepository.findById(entity.getId())` — 방금 생성한 새 UUID로 조회하므로 항상 null. 이름 중복을 막으려던 의도라면 `existsByName` 같은 메서드가 필요 (혹은 스펙상 불필요하면 제거).

### 5. JCF 레포 3개가 `data` 맵 초기화 누락 → NPE
`JCFBinaryContentRepository:12`, `JCFReadStatusRepository:12`, `JCFUserStatusRepository:13` — `protected Map data;`만 선언, 생성자 없음. 인스턴스화하는 순간 모든 메서드 NPE. JCFUser/Channel/Message는 생성자에서 `new HashMap<>()` 하는데 새로 만든 3개만 누락. **테스트 질문과 직결** (아래).

## 🟡 Major

- **프로필 교체 시 이전 프로필 고아** — `BasicUserService.java:82` 새 BinaryContent 저장 후 `updateProfileId`로 갈아끼우지만 이전 profileId의 BinaryContent는 삭제 안 함 → 참조 없는 파일 누적.
- **요구사항 대비: `findAllByUserId` 부재 + 엔티티 반환** — `ChannelService.java:18` `List<Channel> findAll()`이 유일하게 엔티티를 그대로 반환 (DTO 전환 누락). 스펙의 "특정 사용자가 볼 수 있는 채널 목록(공개 + 참여 중 비공개)" = findAllByUserId 구현 필요.
- **`createPrivate` 참여자 존재 검증 없음** — `BasicChannelService.java:41` userIds가 실제 유저인지 확인 안 함 (ReadStatusService.create는 검증함 → 비일관). 유령 유저의 ReadStatus 생성 가능.
- **bare RuntimeException 전면** (#66 반복 피드백) — 조회 실패 = `NoSuchElementException`, 중복/잘못된 인자 = `IllegalArgumentException` 표준 예외로. create의 IllegalArgumentException(BasicUserService:33-37)은 이미 잘 씀 — 그 기준을 전체로.
- **delete 시 상태 없으면 삭제 불가 + 부분 실패** — `BasicUserService.java:108` orElseThrow라서 UserStatus가 없는 유저는 영원히 삭제 불가. 게다가 프로필(:104)은 이미 지워진 뒤라 부분 삭제 상태로 중단됨. `ifPresent(... delete)` + 삭제 순서(자식 먼저, 본체 마지막) 정리.

## 🔵 Minor

- `UserService.java:12` — **인터페이스에 @Service** 는 효과 없음 (구현체에만).
- `Message.java:12-13` — `user_id`/`channel_id` 스네이크 케이스 (#66 반복 피드백). DTO(MessageCreateRequestDto, MessageResponseDto)까지 전파됨.
- `Channel.java:37,42` — `setName`/`setUpdatedAt` public setter 잔존 (#66 반복). update() 있으니 setter 제거, updatedAt 갱신은 BasicEntity에 `markUpdated()` 공통화 (ReadStatus/UserStatus.update는 updatedAt 갱신 안 하는 비일관도 해결됨).
- `UserResponseDto.java:11` — `onlined` → `online` (형용사형).
- 네이밍/패키지 혼재 — 패키지 `service.IService`(대문자), 인터페이스 I-접두사 혼재(IBinaryContentService vs UserService), 구현체 Basic- 접두사 혼재(BasicUserService vs ReadStatusService). 한 가지 규칙으로 통일 권장 (자바 관례: 접두사 없는 인터페이스 + 소문자 패키지).
- 미사용 import 다수 (FileBinaryContentRepository의 User, ReadStatusRepository의 Channel, BinaryContentService의 ReadStatus, DiscodeitApplication의 entity/repository 다수 등) — IDE Optimize Imports.
- `BinaryContentResponseDto` — data만 있고 id가 없어 클라이언트가 파일을 다시 참조할 수 없음. id·createdAt 포함 권장.
- `BasicUserService.readAll`(:115) — 유저마다 userStatus 파일 전체 로드 (N+1 축소판, 인지만).

## 학생 질문 답변 준비 — "리뷰 때 테스트 코드도 보나요? 모든 기능 테스트가 필요한가요?"

1. 테스트 코드도 리뷰 대상 — 그런데 **이 PR엔 테스트 파일이 안 들어 있음** (커밋 누락 추정 → 확인 요청).
2. "JCF는 테스트 못 하고 File만 가능"의 원인 = JCF 레포가 빈이 아니라서가 아니라, **단위 테스트는 스프링 없이 `new JCFUserRepository()`로 하면 됨**. 오히려 JCF가 파일 I/O 없어 테스트에 더 적합. 지금 안 되는 진짜 이유는 위 버그 5번(3개 레포 data 미초기화 NPE).
3. 모든 기능 테스트는 필수 아님 — 분기 있는 핵심 로직(중복 검증, 연쇄 삭제, isOnline 경계) 위주로. File 레포 테스트는 `@TempDir`로 경로 주입 가능해야 하는데 현재 filePath가 하드코딩이라 어려움 → 생성자 주입으로 바꾸면 테스트 용이 (심화 yaml 스위칭과도 연결).

---

## 복붙용 코멘트 위치 (head 검증 완료)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| 채널 미삭제 (메인 버그) | `service/basic/BasicChannelService.java:96` | `public void delete(UUID id)` |
| lastMessageAt 전체 스캔 | `BasicChannelService.java:59` | `messageRepository.findAll()` |
| createPublic 중복 체크 무력 | `BasicChannelService.java:34` | `findById(entity.getId())` |
| createPrivate 유저 검증 없음 | `BasicChannelService.java:41` | `public ChannelResponseDto createPrivate` |
| existsByEmail 이름 비교 | `repository/file/FileUserRepository.java:53` | `user.getName().equals(email)` |
| JCF data 미초기화 | `repository/jcf/JCFBinaryContentRepository.java:12` (+ JCFReadStatus:12, JCFUserStatus:13) | `protected Map<...> data;` |
| 이전 프로필 고아 | `service/basic/BasicUserService.java:82` | `user.updateProfileId(...)` |
| 상태 없으면 삭제 불가 | `BasicUserService.java:108` | `orElseThrow` in delete |
| findAll 엔티티 반환 | `service/IService/ChannelService.java:18` | `List<Channel> findAll();` |
| 인터페이스 @Service | `service/IService/UserService.java:12` | `@Service` |
| 스네이크 케이스 | `entity/Message.java:12-13` | `user_id`, `channel_id` |
| setter 잔존 | `entity/Channel.java:42` | `setUpdatedAt` |
| onlined 네이밍 | `dto/user/UserResponseDto.java:11` | `boolean onlined` |
| 칭찬: 선택적 프로필 | `BasicUserService.java:38` | `if(profileRequest!= null)` |
| 칭찬: isOnline 도메인 로직 | `entity/UserStatus.java:17` | `public boolean isOnline()` |
