# 코드 리뷰 — 스프린트 2-1 [이현석] (PR #23)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/23
- **작성자**: giseo1107 (이현석)
- **범위**: 2-1 JCF CRUD — 엔티티 3(User/Channel/Message) + 서비스 인터페이스 3 + JCF 구현 3 + JavaApplication
- **규모**: +883줄, 21 files

---

## 총평 — 2-1 기준 잘 돌아가는 깔끔한 CRUD 👍

- **인터페이스 → JCF 구현 분리**가 잘 됐고, 서비스 시그니처(`create`가 엔티티 반환, `find(UUID)`, `update(entity)`, `delete(UUID)`)가 일관적이에요.
- **`JavaApplication`에 `main`이 있고 User의 create→update→find→delete→findAll을 실제로 실행**해 확인합니다. (다른 초기 제출들이 놓친 "실행 확인"을 잘 챙김)
- 삭제 후 `find`가 `null`이면 "삭제되었습니다" 출력 — 흐름 검증도 신경 썼어요.

초기 단계인데 골격이 좋아요. 아래는 하나씩 다듬으면 되는 것들입니다.

---

## 🔴 버그

### 1. `Channel.update`가 채널 번호를 갱신하지 못함 (파라미터명 오타)
📁 `entity/Channel.java`
```java
public void update(String name, int channelNUm) {   // 파라미터: channelNUm (U가 대문자)
    this.name = name;
    this.channelNum = channelNum;   // ← 우변 channelNum은 '필드' → 필드=필드 자기 대입(no-op)
    this.updatedAt = System.currentTimeMillis();
}
```
파라미터 이름이 `channelNUm`인데 본문에선 `channelNum`(필드)을 써서, `this.channelNum = channelNum`이 **필드를 자기 자신에 대입**하는 셈이 됩니다. 즉 넘어온 값(`channelNUm`)은 무시되고 **채널 번호가 절대 안 바뀌어요.** 컴파일은 되니 더 찾기 어렵습니다.
→ 파라미터명을 `channelNum`으로 통일하면 해결:
```java
public void update(String name, int channelNum) {
    this.name = name;
    this.channelNum = channelNum;   // 이제 파라미터 → 필드
    this.updatedAt = System.currentTimeMillis();
}
```
(지금 Channel은 main에서 주석 처리돼 안 쓰이지만, 살리면 바로 드러날 버그예요.)

---

## 🟡 짚어둘 점

### 2. `findAll()`이 내부 리스트를 그대로 반환 (캡슐화 누수)
📁 `service/jcf/JCFUserService.java` 등
```java
public List<User> findAll() {
    return users;   // 내부 저장 리스트를 그대로 노출
}
```
호출자가 이 리스트에 `add`/`remove`하면 **저장소가 직접 바뀝니다.** 방어적으로 복사본을 주는 게 안전해요:
```java
return new ArrayList<>(users);
```

### 3. 저장을 `List`로 → id 조회가 매번 전체 탐색
`find(UUID)`가 리스트를 `for`로 훑어요(O(n)). 지금 규모엔 문제없지만, id로 찾고/지우는 게 핵심이라 **`Map<UUID, T>`**가 더 자연스럽고 빨라요. 다음 단계(Repository 도입)에서 바꿔보면 좋습니다.

### 4. `JCFMessageService.update`만 반환값이 다름
`JCFUserService`/`JCFChannelService`의 `update`는 조회된 `found`를 반환하는데, `JCFMessageService.update`는 입력 `message`를 반환해요. 셋을 `found` 반환으로 통일하는 게 일관적입니다.

---

## 🔵 Minor / 💡 Nit

- **`JavaApplication`이 `entity` 패키지 안에 있음**: 실행 진입점이 도메인 패키지에 있는 건 어색해요. `com.sprint.mission` 최상위나 별도 앱 패키지로 옮기는 게 자연스럽습니다.
- **도메인 모델이 아직 placeholder 느낌**: `Message`가 `name`/`count`, `Channel`이 `name`/`channelNum`을 가지는데, 실제 Discodeit에선 `Message = content + senderId + channelId`처럼 **사용자·채널과의 연관**이 있어요. 심화의 연관관계로 이어지니 다음에 이 방향으로 잡아보면 좋아요.
- **`.idea/` 커밋**: `.idea/gradle.xml`, `misc.xml`, `vcs.xml` 등 IDE 설정이 올라갔어요. `.gitignore`에 `.idea/`를 통째로 넣는 걸 권장.
- **`Channel.java` 들여쓰기**: 파일 전체가 한 단계 더 들여써져 있어요(패키지 선언부터). 포맷 정리하면 깔끔.

---

## 정리 (우선순위)

| 순위 | 항목 | 위치 |
|---|---|---|
| 1 | `Channel.update` 파라미터명 오타 → 번호 미갱신 | `entity/Channel.java` |
| 2 | `findAll`이 내부 리스트 그대로 반환 | `JCF*Service` |
| 3 | 저장 `List` → `Map<UUID,T>` 권장 | `JCF*Service` |
| 4 | `JCFMessageService.update` 반환값 불일치 | `JCFMessageService` |
| 5 | JavaApplication 패키지 위치, 도메인 모델, `.idea` 커밋 | 위생/설계 |

2-1 기준으로 실행되는 CRUD를 잘 만들었어요. 1번(눈에 안 띄는 버그)만 잡고, 2·3번으로 저장/캡슐화를 다듬으면 다음(Repository·File) 단계로 매끄럽게 이어집니다.
