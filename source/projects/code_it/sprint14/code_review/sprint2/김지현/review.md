# 코드 리뷰 — [김지현] sprint2 (PR #22)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/22
- **작성자**: pengji-dev (김지현)
- **범위**: 엔티티 3 + Repository 인터페이스 3 + JCF/File 레포 각 3 + JCF/File 서비스 각 3 + Application
- **규모**: +1623줄, 36 files
- **라벨**: 미완성🛠️ (실제로는 1차 CRUD가 JCF·File 양쪽으로 거의 완성됨)

---

## 총평 — 미완성 표시보다 훨씬 완성도 높음 👍

- **계층 분리가 정석**: `Repository`(인터페이스) → `JCF*/File*Repository`(구현), 서비스는 **Repository를 생성자 주입**받아 사용. "저장 방식은 주입되는 Repository로 교체"라는 미션 핵심을 잘 잡았어요.
- **엔티티 일관성**: User/Channel/Message 모두 `UUID id` + `createdAt`/`updatedAt` + `update()` + `toString()` 패턴 통일.
- **File 레포가 `Map<UUID,T>` 기반**으로 load→put→save 흐름이 깔끔. `findById`도 `loadData().get(id)`로 명확.
- **서비스 조회/수정/삭제에서 `Optional.orElseThrow`로 "없으면 예외"** 정책을 일관되게 적용 — 앞선 다른 제출들이 놓친 부분을 여긴 잘 처리했어요.

아래 두 개는 **실행은 되지만 의도대로 동작하지 않는** 숨은 버그라 꼭 짚어둡니다.

---

## 🔴 Critical (조용히 잘못 동작)

### 1. `serialVersionID` 오타 → 직렬화 버전 필드로 인식 안 됨
📁 `entity/User.java`, `Channel.java`, `Message.java`
```java
private static final long serialVersionID = 1L;   // ← 이름 틀림
```
정확한 이름은 **`serialVersionUID`**(U가 빠짐)예요. 이름이 다르면 Java는 이걸 직렬화 버전 필드로 **인식하지 못하고 그냥 안 쓰는 일반 상수**로 취급합니다. 결국 JVM이 UID를 자동 계산하게 되어, **클래스가 조금만 바뀌어도 기존 `.dat` 역직렬화가 `InvalidClassException`으로 깨질 수 있어요**(명시한 의미가 사라짐). `serialVersionUID`로 정확히 고쳐야 합니다.

### 2. `update` 해도 `updatedAt`이 갱신되지 않음
엔티티엔 `updatedAt`을 갱신하는 `update()` 메서드가 있는데, **서비스는 이걸 안 쓰고 `@Setter`로 필드만 바꿉니다.**
```java
// 예: FileUserService.update / JCFUserService.update
updatedUser.setName(user.getName());
updatedUser.setAge(user.getAge());
updatedUser.setEmail(user.getEmail());   // setter는 updatedAt을 안 건드림
```
`User.update(name, age, email)`은 `updatedAt = now`를 해주지만, 서비스가 `setXxx`를 호출해서 **수정해도 `updatedAt`이 `createdAt` 그대로**입니다. "수정 시각"이 항상 "생성 시각"과 같아지는 버그예요.
→ 서비스에서 setter 대신 **엔티티의 `update()`를 호출**하면 해결됩니다:
```java
updatedUser.update(user.getName(), user.getAge(), user.getEmail());
```
(이러면 엔티티가 "수정 시 updatedAt 갱신" 규칙을 스스로 지키게 되고, 지금 dead code인 `update()`도 제 역할을 하게 됩니다.)

---

## 🟡 Major

### 3. `JCF*Service`와 `File*Service`가 완전히 동일 (중복)
`JCFUserService`와 `FileUserService`의 코드가 **글자 하나까지 똑같습니다.** 둘 다 주입받은 `Repository`에 위임할 뿐이라, 유일한 차이는 main에서 어떤 Repository를 넣느냐예요:
```java
UserService userService     = new JCFUserService(new JCFUserRepository());
UserService fileUserService = new FileUserService(new FileUserRepository());
```
즉 **서비스를 jcf/file로 나눌 이유가 없습니다.** `BasicUserService` 하나만 두고 주입 Repository만 바꾸면 됩니다(6개 → 3개). 이게 바로 "구현 교체는 서비스가 아니라 Repository로"라는 미션 의도이기도 해요.

### 4. `.DS_Store` / `.dat` 파일 커밋
`.DS_Store`, `channels.dat`, `messages.dat`, `users.dat`가 저장소에 포함됐습니다. 런타임 산출물/OS 파일이므로 `.gitignore`에 `*.dat` 추가(+ `.DS_Store`는 이미 목록에 있으나 이미 커밋된 상태라) `git rm --cached`로 제거하세요.

### 5. File 레포 `loadData`가 예외를 삼키고 빈 Map 반환
```java
} catch (IOException | ClassNotFoundException e) {
    return new HashMap<>();   // 파일 손상/버전 불일치도 "빈 데이터"로 처리
}
```
파일이 깨져도 조용히 빈 데이터로 진행하고, 그 상태로 `save`하면 기존 파일을 덮어써 **데이터가 유실**될 수 있어요. "파일 없음(최초 실행)"만 빈 Map으로 처리하고(이미 `file.exists()`로 잘 거르고 있음), 나머지 예외는 원인을 담아 다시 던지는 게 안전합니다.

---

## 🔵 Minor / 💡 Nit

- **서비스가 `System.out.println("등록 완료")`**: 표현(출력) 관심사가 서비스에 섞여 있어요. 출력은 호출부(main/뷰)에서 하고 서비스는 로직에 집중하는 게 계층 분리에 맞습니다.
- **File 레포 `loadData`/`saveData`가 3곳 복붙**: `AbstractFileRepository<T>`로 추출하면 중복이 사라집니다(#3 정리와 함께 하면 좋음).
- **엔티티 `@Setter` + `update()` 공존**: setter를 열어두면 아무 데서나 `updatedAt` 없이 필드가 바뀔 수 있어요. `@Setter`를 빼고 변경은 `update()`로만 하도록 좁히면 #2 같은 실수가 원천 차단됩니다.
- **`MessageService`가 `User` import**하지만 미사용.
- **`settings.gradle` name이 `mission`**, `application.properties`는 `1-sprint-mission` — 이름 정리.

---

## 정리 (우선순위)

| 순위 | 항목 |
|---|---|
| 1 | 🔴 `serialVersionID` → `serialVersionUID` 오타 |
| 2 | 🔴 update 시 `updatedAt` 미갱신 (setter 대신 `update()` 호출) |
| 3 | 🟡 JCF/File 서비스 완전 중복 → `Basic*Service` 하나로 |
| 4 | 🟡 `.DS_Store`/`.dat` 커밋 정리 |
| 5 | 🟡 loadData 예외 삼킴 |
| 6 | 🔵 서비스 println, File 레포 DRY, @Setter 정리 |

미완성으로 표시했지만 구조·일관성이 좋아서, 위 2개 버그만 잡으면 1차 완성도로는 충분합니다. 잘 하고 있어요.
