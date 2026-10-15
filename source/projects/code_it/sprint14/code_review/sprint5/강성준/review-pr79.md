# 코드 리뷰 — [강성준] sprint5 PR (실제: 미션3 엔티티 재구현) (PR #79)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/79
- **작성자**: xian980 (강성준), head `강성준-entity` → base `강성준` ✅
- **규모**: +159 / −2858, 73 files — **기존 구현 64개 파일 전부 삭제 + 엔티티 8개 재작성**
- **성격**: PR 제목은 sprint5지만 본문은 "[미션3 재구현] entity밖에 못하였습니다. repository → service → dto 순으로 작업 예정"
- **톤**: 격려 + 다음 스텝 로드맵 중심 (사용자 요청 — 진도 뒤처짐, 레벨 맞춤)

> diff 전체 확인, 라인은 head(`강성준-entity`) raw 검증 완료.

## 배경 (내부 메모 — 코멘트에 쓰지 말 것)

sprint4 PR #62는 "기수 최고 수준" 완성도였는데, 이번에 그걸 전부 지우고 엔티티부터 다시 쌓고 있음. 본인 손으로 다시 만들어 진짜 이해를 얻으려는 재출발로 보임 — **이 결정 자체를 크게 인정해주는 게 리뷰의 축**. 삭제된 이전 코드(변경감지 update, ONLINE_THRESHOLD 상수, "왜" 주석들)와 비교해 후퇴한 부분이 있지만, 그걸 "예전 게 나았다"가 아니라 "다시 만들면서 스스로 판단해볼 논점"으로 제시.

## 총평 — 재출발의 방향과 순서가 정확함

- **entity → repository → service → dto 순서 계획이 정석** — 의존성 방향 그대로
- 미션4 리뷰 지적 반영: DiscodeitApplication의 테스트 로직 전부 삭제 (main이 3줄) ✅, Message 수정 시 null 덮어쓰기 → updateContent 검증으로 해결 ✅
- `Basic` 공통 부모로 id/createdAt/updatedAt 추출 — 중복 제거 방향 좋음
- **Message.create 정적 팩토리 + 필수값 검증** (content blank, channelId/authorId null) — 이번 재구현에서 가장 좋은 부분
- BinaryContent `bytes.clone()` 방어적 복사 유지, Basic 미상속(수정 불가 도메인) 판단 유지
- User.changeProfile "null이면 프로필 제거" 의도 주석, ReadStatus.readChannel() 도메인 언어 네이밍

## 🟡 짚을 점 (다음 단계 진행에 영향)

### 1. id를 외부에서 받는 설계 — "누가 UUID를 만드나?" (`Basic.java:16`, 전 엔티티 공통)
모든 엔티티가 `super(id)`로 id를 주입받음. 이전엔 엔티티가 `UUID.randomUUID()`로 스스로 생성. 이제 service가 id를 만들어 넘겨야 하는데 — 실수로 null/중복 id 전달 가능. **repository 만들기 전에 결정 필요**: 엔티티(또는 create 팩토리) 안에서 생성 권장. 질문형으로.

### 2. BinaryContent 생성자가 createdAt 파라미터를 받고 무시 — `BinaryContent.java:18,20`
`Instant createdAt`을 받아놓고 `this.createdAt = Instant.now()`. 파일에서 역직렬화가 아닌 재구성 방식을 쓰게 되면 원본 생성시각이 소실됨. 파라미터 삭제 or 할당 — 지금 정리.

### 3. Channel.update가 description을 못 바꿈 + 파라미터명 title — `Channel.java:24-26`
이전 스펙(그리고 미션5 스펙)은 name+description 수정. 필드는 channelName인데 파라미터는 title로 어긋남.

### 4. User.toString에 password 포함 — `User.java:40-41`
로그에 비밀번호가 찍히는 습관 위험. sprint4 제출물엔 로그인 실패 비구분 같은 보안 감각이 있었는데 — username/email 정도만.

### 5. User 필드명 name — 스펙은 username (`User.java:10`)
DTO에서 매핑해도 되지만 스펙 어휘 통일 권장 (미션5 가면 username 고정).

## 🔵 Minor

- `Basic.java:10` — abstract 권장 (직접 생성 방지) + BaseEntity 네이밍 관례 언급
- `ChannelType.java:7-8` — 필드 없는 enum에 @RequiredArgsConstructor/@FieldDefaults 무의미 (복붙 잔재)
- `UserStatus.java:24-30` — `if(cond) return true else false` → `return cond;` 한 줄. 300초 하드코딩 → `ONLINE_THRESHOLD` 상수
- updatedAt 갱신 중복 — 각 메서드마다 `super.updatedAt = Instant.now()` 반복 → Basic에 `protected void touch()` 하나로
- 정적 팩토리 비일관 — Message/Channel은 create(), User/ReadStatus/UserStatus는 public 생성자. 통일
- 자식 클래스 serialVersionUID 없음 (Basic에만), BinaryContent도 없음
- 변경감지: null이 아니면 항상 updatedAt 갱신 — 값이 같아도 수정시각 바뀜 (심화 논점, 나중에)

## 로드맵 (코멘트에 포함할 것)

1. **Repository**: 인터페이스(save/findById/findAll/deleteById) → JCF 구현부터 (파일 IO 없이 로직 검증) → File 구현. User 하나로 패턴 확립 후 복제
2. **Service**: BasicUserService부터 — 여기서 1번(id 생성 주체) 결정이 필요
3. **DTO**: 응답에 password 제외가 첫 원칙
4. **Controller**(스프린트4 진입): UserController 하나 → 나머지 복제
5. 스프린트5 스펙 정합·Swagger는 그 다음 — 지금은 신경 끄기
- 도메인 하나(User)를 세로로 끝까지(엔티티→레포→서비스→컨트롤러) 뚫고 나머지를 복제하는 방식도 추천 — 성취감+패턴 확립

## 복붙용 코멘트 위치 (head 검증 완료, 경로 앞 src/main/java/com/sprint/mission/discodeit/entity/)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| id 주입 설계 질문 | `Basic.java:16` | `public Basic(UUID id)` |
| createdAt 무시 | `BinaryContent.java:20` | `this.createdAt = Instant.now();` |
| description 수정 불가 | `Channel.java:24` | `public void update(String title)` |
| toString password | `User.java:40` | `public String toString()` |
| name vs username | `User.java:10` | `private String name;` |
| enum 어노테이션 잔재 | `ChannelType.java:7` | `@RequiredArgsConstructor` |
| isOnline 단순화 | `UserStatus.java:26` | `if (this.lastActiveAt.isAfter(...)` |
| 칭찬: create 팩토리+검증 | `Message.java:34` | `public static Message create(` |
| 칭찬: 방어적 복사 | `BinaryContent.java:24` | `this.bytes = bytes.clone();` |
| 칭찬: main 정리 | `DiscodeitApplication.java` | 3줄 main |
