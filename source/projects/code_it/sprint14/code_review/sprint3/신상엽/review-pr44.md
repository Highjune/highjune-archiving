# 코드 리뷰 — [신상엽] sprint3 (PR #44)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/44
- **작성자**: Smil-limS (신상엽)
- **범위**: Spring Boot 전환 + 신규 도메인(ReadStatus/UserStatus/BinaryContent) + AuthService + DTO + JCF/File 레포
- **규모**: +2685, 66 files, 69 commits
- **라벨**: 매운맛🔥 / 멘토 질문: 없음(본문 비어 있음)

> 확인한 핵심 파일: `BasicUserService`, `BasicChannelService`, `FileUserRepository`, `application.yaml`. 나머지는 파일 목록으로 파악.

---

## 총평 — 구조는 sprint2에 이어 최상위권 👏

- 계층이 아주 깔끔해요: `entity` / `dto`(record) / `repository`(인터페이스 + `jcf` + `file`) / `service`(인터페이스 + `basic`), 생성자 주입(`@RequiredArgsConstructor`).
- `existsByUsername`/`existsByEmail`로 중복 검증을 레포에 위임, Repository `Optional` 반환 + `orElseThrow(NoSuchElementException)`로 "없으면 예외" 정책 일관.
- DTO를 record로, 엔티티↔DTO 변환을 `toResponse`로 모아둔 것도 좋아요.
- `BasicChannelService.findAllByUserId`에서 "PUBLIC 전체 + 내가 참여한 PRIVATE만" 필터링, `toResponse`에서 마지막 메시지 시각 조립 등 요구사항 처리도 정확.

다만 아래 **실수성 버그 3개는 실제로 잘못 동작**하니 꼭 짚어야 해요.

---

## 🔴 Critical (실제로 잘못 동작하는 버그)

### 1. 회원 생성 시 비밀번호에 이메일이 저장됨
📍 `service/basic/BasicUserService.java` — `create()`
```java
User user = new User(request.username(), request.email(), request.email());
//                                        ↑ 2번째 email    ↑ 3번째(password 자리)에 또 email
```
`User` 생성자가 `(username, email, password)`인데 **세 번째(password) 자리에 `request.email()`을 또 넘겼어요.** 그래서 모든 유저의 비밀번호가 이메일 값으로 저장됩니다. `update()`에선 `request.password()`를 제대로 쓰고 있어서 create만 틀렸어요. → `new User(request.username(), request.email(), request.password())`.

### 2. `update()`에서 기존 프로필을 지울 때 잘못된 id 사용
📍 `service/basic/BasicUserService.java` — `update()`
```java
if (user.getProfileId() != null) {
    binaryContentRepository.deleteById(user.getId());   // ← user.getId() (유저 id)
}
```
프로필 교체 시 **기존 프로필(BinaryContent)을 지우려는 의도**인데, `user.getProfileId()`가 아니라 `user.getId()`(유저 id)로 `deleteById`를 호출해요. 유저 id에 해당하는 BinaryContent는 없으니 기존 프로필이 안 지워지고 orphan으로 남습니다. `delete()`에선 `binaryContentRepository.deleteById(user.getProfileId())`로 제대로 하고 있어서 update만 틀렸어요. → `deleteById(user.getProfileId())`.

### 3. 채널 삭제 시 메시지가 안 지워짐
📍 `service/basic/BasicChannelService.java` — `delete()`
```java
messageRepository.deleteById(channelId);          // ← channelId를 "메시지 id"로 삭제 시도
readStatusRepository.deleteByChannelId(channelId); // 이건 channelId 기준으로 정확
```
채널에 속한 메시지들을 지우려면 **`deleteByChannelId(channelId)`**여야 하는데 `deleteById(channelId)`를 호출했어요. `channelId`를 message의 id로 취급하니 실제 매칭되는 메시지가 없어 **그 채널의 메시지들이 안 지워지고 orphan**으로 남습니다. 바로 아래 readStatus는 `deleteByChannelId`로 잘 했으니, 메시지도 동일하게 맞춰주세요.

---

## 🟡 Major

### 4. 구현체 선택이 `@Primary` 하드코딩 — yaml 스위칭 요구사항 미충족
📍 `repository/file/FileUserRepository.java` (등 File 레포 전반)
```java
@Primary
@Repository
public class FileUserRepository implements UserRepository { ... }
```
JCF/File 두 구현체가 다 빈으로 등록되니 충돌을 막으려 `@Primary`를 File에 붙이셨는데, 이러면 **항상 File이 고정 선택**돼요. sprint3 심화 요구사항은 "**application.yaml 설정으로 구현체를 선택**"하는 건데, 지금 `application.yaml`엔 app name만 있고 스위칭 설정이 없어요. 같은 스터디 이은솔/김민재님처럼 **`@ConditionalOnProperty(name="discodeit.repository.type", havingValue="file")`** + yaml `discodeit.repository.type: jcf|file`로 바꾸면 요구사항을 충족하고 설정만으로 갈아끼울 수 있어요.

### 5. PRIVATE 채널 수정 예외 타입이 부적절
📍 `service/basic/BasicChannelService.java` — `update()`
```java
if (channel.getType() == ChannelType.PRIVATE){
    throw new NoSuchElementException("PRIVATE 채널은 정보를 수정할 수 없습니다.");
}
```
"찾을 수 없음"이 아니라 **"상태상 수정 불가"**라 `NoSuchElementException`은 의미가 안 맞아요. `IllegalStateException`이 적절합니다. (조회 실패엔 `NoSuchElementException`을 잘 쓰고 계시니, 성격만 구분)

### 6. `findAll`의 userStatus orElseThrow → 목록 전체 실패 위험
📍 `service/basic/BasicUserService.java` — `findAll()`
유저는 있는데 UserStatus가 하나라도 없으면 `orElseThrow`로 **목록 전체 조회가 실패**해요. 지금은 create에서 UserStatus를 항상 같이 만들어 정합성이 보장되지만, 목록 조회는 개별 데이터 하나로 전체가 무너지지 않게 방어적으로(기본값 OFFLINE 등) 두면 안전해요. (은솔/민재님 PR에도 있던 공통 포인트)

---

## 🔵 Minor / Nit

- **import 포매팅 깨짐**: `BasicUserService`의 일부 import가 `;import ...`처럼 한 줄에 붙어 있어요(줄바꿈 누락). IDE 자동 정리(⌥⌘O)로 정돈 권장.
- **File 레포의 `existsByUsername`/`findByUsernameAndPassword`가 `findAll()` 전체 로드 후 스트림** — 파일 기반이라 어쩔 수 없는 면이 있지만, 데이터가 많아지면 매 검증이 전체 역직렬화라 비쌈(인지 포인트).
- **예외가 대부분 `RuntimeException(e)`**(File 레포) — 원인 `e`는 잘 넘기는데(👍) 메시지를 함께 주면(`"유저 파일 저장 실패: " + id`) 로그에서 원인 좁히기 쉬워요.

---

## 정리 (우선순위)

| 순위 | 항목 | 위치 |
|---|---|---|
| 1 | 🔴 비밀번호에 이메일 저장 (`new User(.., email, email)`) | `BasicUserService.create` |
| 2 | 🔴 update의 프로필 삭제가 `user.getId()` (→ profileId) | `BasicUserService.update` |
| 3 | 🔴 채널 삭제 시 `messageRepository.deleteById` (→ deleteByChannelId) | `BasicChannelService.delete` |
| 4 | @Primary 하드코딩 → @ConditionalOnProperty + yaml 스위칭 | `repository/file/*`, `application.yaml` |
| 5 | PRIVATE 수정 예외 IllegalStateException으로 | `BasicChannelService.update` |
| 6 | findAll status 없음 → 목록 전체 실패 방어 | `BasicUserService.findAll` |

구조·완성도는 최고 수준이라, **1~3번(눈에 잘 안 띄는 실수성 버그)만 잡으면** 실제 동작까지 탄탄해져요. 특히 1번(비번=이메일)은 로그인/보안과 직결되니 가장 먼저 고치는 걸 추천해요.
