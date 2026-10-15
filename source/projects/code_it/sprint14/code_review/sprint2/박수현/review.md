# 코드 리뷰 — [박수현] sprint 2 (PR #20, 1차만)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/20
- **작성자**: shp02x2 (박수현)
- **범위**: 엔티티(User/Channel/Message) + 서비스 인터페이스 3 + JCF 구현 3 + JavaApplication
- **규모**: +802줄(대부분 gradle 보일러플레이트), 17 files
- **라벨**: 미완성🛠️ / 작성자: "베이스·코딩 실력이 부족하여 1차까지만 완료"

> 작성한 범위(1차 JCF CRUD)만 리뷰합니다. 미구현(File 영속화·Repository 분리·연관관계 검증)은 지적 대상이 아니에요.

---

## 총평 — 1차 기준 아주 깔끔합니다 👍

시작 단계인데도 기본기가 잘 잡혀 있어요:
- **엔티티 일관성**: 세 엔티티 모두 `UUID id` + `createdAt`(final) + `updatedAt` + `update()`에서 `updatedAt` 갱신. 패턴이 통일돼 있음.
- **인터페이스 → 구현 분리**: `UserService`(계약)와 `JCFUserService`(구현)를 나눠, 나중에 File 구현으로 교체할 자리를 미리 만들어 둠. 2차 방향과 잘 맞아요.
- **JCF 저장을 `Map<UUID, T>`로**: id 기반 조회/수정/삭제에 적합한 자료구조를 골랐음. (앞선 다른 제출에서 List로 해서 고생한 부분을 여긴 처음부터 잘 잡음)
- **main 흐름**이 create→find→findAll→update→delete를 도메인별로 차분히 검증.

동작하는 데 문제되는 버그는 없습니다. 아래는 "지금 한 것 안에서" 알아두면 좋은 설명들이에요.

---

## 작성한 코드 안에서 — 짚어둘 점

### 1. `getInstance()` 싱글턴 — 지금은 OK, 다만 두 가지 알아두기
📁 `service/jcf/JCFUserService.java` (Channel/Message도 동일)
```java
private static JCFUserService instance;
public static JCFUserService getInstance() {
    if (instance == null) { instance = new JCFUserService(); }  // lazy init
    return instance;
}
```
- 이게 **싱글턴 패턴**입니다("인스턴스를 하나만 유지"). 개념을 잘 적용했어요.
- 다만 이 `if (instance == null)` 방식은 **여러 스레드가 동시에 부르면 인스턴스가 2개 생길 수 있어요**(지금 콘솔 단일 실행에선 문제 없음). 더 안전한 관용구는 `LazyHolder`입니다:
  ```java
  private static class LazyHolder {
      private static final JCFUserService INSTANCE = new JCFUserService();
  }
  public static JCFUserService getInstance() { return LazyHolder.INSTANCE; }
  ```
- 참고로 2차 심화에선 이 싱글턴 대신 **생성자 주입(DI)**으로 넘어가게 돼요(그때 자연스럽게 바뀝니다). 지금 단계에선 지금 방식으로 충분합니다.

### 2. `find`/`update`가 없는 id면 조용히 `null` 반환
📁 `service/jcf/JCFUserService.java` 등
```java
public User find(UUID userId) { return data.get(userId); }   // 없으면 null
public User update(UUID userId, ...) {
    User user = data.get(userId);
    if (user != null) { user.update(...); }
    return user;                                             // 없으면 null
}
```
지금 main에선 "삭제 후 조회 → null 출력"으로 삭제를 확인하니 의도대로 동작해요. 다만 실무에선 "없는 걸 조회/수정"했을 때 **null을 돌려줄지, 예외를 던질지** 정책을 정해두는 게 좋습니다. 다음 단계에서 이 부분을 한 번 고민해보면 좋아요(정답은 없고, 팀/상황에 따라 다름).

### 3. 검증(validation)은 다음 스텝
`create(name, email)`이 값이 비었는지 등을 확인하지 않아요. 1차 CRUD 흐름 확인이 목적이라 지금은 괜찮지만, 다음에 "빈 이름은 못 만들게" 같은 규칙을 서비스나 별도 검증 지점에 추가해보면 자연스럽게 심화로 이어집니다.

### 💡 아주 사소한 것
- `data.values().stream().collect(Collectors.toList())` → Java 16+에선 `data.values().stream().toList()`로 더 짧게 쓸 수 있어요.

---

## 정리

1차 CRUD로서 구조·일관성이 좋고 버그도 없습니다. 지금은 잘 하고 있으니, 다음엔 **① 없는 id 처리 정책(null vs 예외)**, **② 간단한 입력 검증**부터 하나씩 붙여보면 자연스럽게 2차(File 영속화·Repository 분리)로 넘어갈 수 있어요. 좋은 출발입니다.
