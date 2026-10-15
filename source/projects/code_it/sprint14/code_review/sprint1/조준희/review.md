# 코드 리뷰 — 조준희 sprint1 (PR #2)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/2
- **작성자**: Joonehee-JO (조준희)
- **범위**: Discodeit — 도메인/레포/서비스/컨트롤러 + 콘솔 메뉴(MainApplication)
- **규모**: +2055줄, 57 files, 30 commits
- **비고**: sprint1. 작성자가 "요구사항을 몰라 느낌대로 구현, 2-2부터 요구사항 준수" 라고 밝힘. 인라인 질문 주석 다수.

---

## 총평

Controller/DTO/Service/Repository 계층을 나누고, 입력 검증을 DTO 생성자에 모으고, `CustomException`+`CustomErrorCode`로 예외를 체계화하려는 시도가 좋습니다. 콘솔 메뉴(switch 분기)로 실제 동작하는 앱을 만든 점도요.

다만 지금은 **① 서로 다른 두 구현 트리가 공존**(하나만 실제로 실행됨)하고, **② 파일 레포지토리 쪽에 실행되면 바로 터지는 버그가 여러 개** 있으며, **③ 커밋하면 안 되는 파일(.ser)이 소스 폴더에 포함**돼 있어요. sprint1이라 러프한 건 자연스럽지만, 아래 Critical들은 "동작 자체가 안 되는" 수준이라 짚어둡니다.

---

## 🔴 Critical (실행 시 바로 터지거나 동작 안 함)

### 1. `findAllUser()` 무한 재귀 → StackOverflowError
```java
// BasicUserServiceImpl
public List<User> findAllUser(){
    List<User> userList = findAllUser();   // ← 자기 자신을 호출
    return userList;
}
```
`userRepository.findAllEntity()`를 불러야 하는데 자기 메서드를 재귀 호출해서 **호출 즉시 StackOverflowError**입니다.

### 2. `deleteEntity` — ConcurrentModificationException + 저장 안 됨
```java
public void deleteEntity(UUID uuid) {
    List<Channel> channelList = findAllEntity();
    for (Channel channel : channelList) {
        if(channel.getId().equals(uuid)) channelList.remove(channel);  // (a)
    }
    // (b) 파일에 다시 쓰지 않음
}
```
- **(a)** for-each 도중 `remove` → `ConcurrentModificationException`. (`Iterator.remove()` 또는 `removeIf(...)`를 써야 함)
- **(b)** 설령 지웠어도 `findAllEntity()`로 읽어온 건 파일에서 새로 역직렬화한 리스트라, 수정 후 **다시 저장하지 않으면 파일은 그대로**입니다. 즉 삭제가 영속되지 않아요. (User/Channel/Message 레포 공통)

### 3. `updateEntity`가 저장 안 됨 + 채널은 항상 실패로 처리됨
```java
// BasicChannelCrudRepositoryImpl
public Channel updateEntity(UUID uuid, String updateName) {
    Channel updateChannel = findById(uuid);
    if(updateChannel != null){ updateChannel.update(updateName); }
    return null;    // ← 항상 null 반환 + 파일에 저장 안 함
}
```
- `findById`가 반환한 건 파일에서 역직렬화한 **복사본**이라, 그걸 수정해도 파일엔 반영되지 않습니다(저장 호출 없음).
- 게다가 **항상 `null`을 반환**해서, 이를 받는 서비스가 실패로 판정합니다:
  ```java
  // BasicChannelServiceImpl.updateChannelName
  Channel channel = channelRepository.updateEntity(channelId, updateName);
  if(channel != null) return channel;
  throw new RuntimeException("채널 업뎃 실패");   // ← 무조건 여기로 옴
  ```
  결과적으로 채널 이름 수정은 **항상 예외**로 끝납니다.

### 4. `BasicChannelServiceImpl.makeChannel`이 저장을 안 함
```java
public Channel makeChannel(String channelName) {
    Channel channel = Channel.makeChannel(channelName);
    if(channel != null) return channel;   // 객체만 만들고 끝
    throw new RuntimeException("채널 생성 실패");
}
```
`channelRepository.saveEntity(channel)` 호출이 없어서 **생성한 채널이 저장되지 않습니다.** (User/Message 서비스는 save를 하는데 Channel만 누락) 또한 `Channel.makeChannel`은 절대 null을 반환하지 않으므로 `if(channel != null)` 검사는 항상 참이라 의미가 없습니다.

### 5. `saveEntity`가 매번 리스트에 append (중복 누적)
```java
// AbstractCrudRepository
public T saveEntity(T entity) {
    List<T> savedList = findAllEntity();
    savedList.add(entity);              // 항상 추가만, id 기준 교체 없음
    objectOutputStream.writeObject(savedList);
    return entity;
}
```
같은 엔티티를 다시 저장해도 교체가 아니라 **계속 추가**됩니다. 재실행할 때마다 데이터가 쌓이고, 저장 구조가 `List`라 id 기반 갱신/삭제가 비효율적이에요. `Map<UUID, T>`로 바꾸면 이 문제들이 한 번에 정리됩니다.

### 6. `.ser` 파일이 `src/main/java/`에 커밋됨
`channel.ser`, `user.ser`가 **소스 루트 안에** 들어가 있습니다. 원인은 파일 경로를 `"src/main/java/"`로 하드코딩했기 때문이에요. 런타임 산출물이므로 (1) 저장 경로를 프로젝트 밖(예: `data/`)이나 상대 경로로 빼고, (2) `.gitignore`에 `*.ser` 추가, (3) 이미 커밋된 것은 `git rm --cached`로 제거하세요.

---

## 🟡 Major

### 7. 서로 다른 두 구현 트리가 공존 (가장 큰 구조 이슈)
- `com.sprint.mission.discodeit.*`: `UUID` 식별자 + 파일 영속화 + `Abstract/File CrudRepository`. **테스트에서만 사용됨.**
- `sprint0.*`: `Long` 자동증가 식별자 + `ConcurrentHashMap` 인메모리 + Controller/DTO + **실제 실행되는 `MainApplication`**.

`User`, `Message`, `Channel`, `CrudRepository`가 두 트리에 각각 존재하고 설계도 다릅니다(UUID vs Long, 파일 vs 메모리). 실제로 도는 건 `sprint0`뿐이고 `discodeit` 트리는 테스트만 건드려요. **하나로 합쳐야** 합니다. 미션이 지향하는 방향(UUID 엔티티, Repository 계층)은 `discodeit` 쪽에 가깝지만, 작동하는 앱은 `sprint0`이라 지금은 둘 다 어중간합니다.

### 8. `sprint0`의 채널엔 도메인/레포가 없음 — 서비스가 저장까지 담당
```java
// ChannelServiceImpl
private final Map<Long, Long> struct = new ConcurrentHashMap<>();  // <유저, 채널번호>
```
채널이 엔티티가 아니라 "1~10 숫자"로만 존재하고, 저장 로직이 서비스 안에 들어가 있습니다. (작성자도 주석으로 이 점을 고민) User/Message처럼 Channel도 도메인+레포로 일관되게 두는 게 좋아요.

### 9. CRUD 인터페이스가 두 개로 갈라지고 서로 안 맞음
`discodeit`에 `CrudRepository<T,ID>`(`updateEntity(ID id)` 1개 인자, `Optional` 반환)와 `FileCrudRepository<T,ID>`(`updateEntity(ID id, String updateName)` 2개 인자, `T` 반환)가 따로 있고, 실제 구현은 `FileCrudRepository`만 씁니다. `CrudRepository`는 사실상 방치돼요. 또 `updateEntity(ID id)`는 인자에 바꿀 값이 없어 아무것도 수정할 수 없습니다. 인터페이스를 하나로 정리하세요.

### 10. 레포지토리가 "이름 수정"에 종속됨
`updateEntity(UUID id, String updateName)`는 제네릭 레포인데 "수정 대상이 name"이라고 가정합니다. Message 구현은 이 `updateName`을 content로 재활용하고요. 저장소는 어떤 필드가 바뀌는지 몰라야 자연스럽습니다. 갱신은 "수정된 엔티티를 통째로 저장"(`save(entity)`)하는 형태가 더 일반적이에요.

---

## 🔵 Minor / 💡 Nit

- **테스트 두 개가 서로 뒤바뀜**: `BasicChannelCrudRepositoryImplTest`가 실제로는 **User** 레포를 테스트하고, `BasicUserCrudRepositoryImplTest`가 **Channel**을 테스트합니다(내용이 스왑됨). 이름과 대상이 어긋나 있어요.
- **파일 테스트가 실제 `src/main/java/*.ser`를 오염**: 테스트가 진짜 저장 파일에 쓰고 정리(teardown)가 없어, 실행 순서에 따라 결과가 달라지고 커밋 파일이 더럽혀집니다. 임시 경로 + `@AfterEach` 정리 권장.
- **`UserRepositoryImplTest.유저_입력_실패`는 지금 실패함**: 중복 id 예외를 기대하지만 `UserRepositoryImpl.create`의 중복 검사가 주석 처리돼 있어 예외를 안 던집니다(테스트-구현 불일치).
- **전부 주석 처리된 파일**: `service/file/FileChannelService.java`는 100% 주석. 삭제하세요.
- **`//궁금`/`//해야하나..?`류 주석·죽은 코드 다수**: 커밋 전 정리하고, 궁금한 점은 코드가 아니라 PR 코멘트로. (작성자도 인지하고 있는 부분)
- **네이밍**: 정적 팩토리 `makeUser/makeChannel/makeMessage` vs 서비스 `create*`/`init*` 혼재. 한쪽으로 통일 권장.

---

## 남긴 인라인 질문들에 대한 답 (골라서)

작성자가 코드 곳곳에 남긴 질문 중 학습에 도움되는 것들에 답합니다.

**Q. `@EqualsAndHashCode(of = "id")` — 해야 하나?**
엔티티의 동등성을 **식별자(id) 기준**으로 볼 거라면 하는 게 맞습니다. 두 User가 이름이 같아도 id가 다르면 다른 사용자니까요. 다만 지금 저장 구조가 `List`라 `contains`/`remove`가 `equals`에 의존하는데, `Map<UUID, T>`로 바꾸면 id가 키가 되어 이 고민이 상당 부분 사라집니다.

**Q. `@Retention(SOURCE)`로 `@Comment` 만든 것 — 맞나? 메모리 절약?**
retention을 `SOURCE`로 둔 판단 자체는 맞아요(컴파일 후 사라져 런타임에 안 올라옴). 다만 "문서용 주석"을 굳이 커스텀 애노테이션으로 만들 필요는 거의 없습니다. 일반 주석이나 Javadoc이 더 관례적이고 도구 지원도 좋아요. 메모리 절약 효과도 실질적으로 무시할 수준입니다.

**Q. (sprint0 CrudRepository 주석) 추상클래스로 뼈대를 만들지, 인터페이스만 둘지?**
"공통 CRUD 로직(직렬화 등)을 실제로 공유"하려면 추상클래스가 유용하고, "계약만 정의"하려면 인터페이스가 맞습니다. 둘은 배타적이지 않아서 **인터페이스(계약) + 추상클래스(공통 구현)**를 같이 쓰는 게 정석이에요. 실제로 `discodeit` 트리에서 이미 `FileCrudRepository`(인터페이스) + `AbstractCrudRepository`(공통 구현)로 그 형태를 시도했습니다 — 그 방향이 맞아요. "각 레포에 기능이 추가되면?"은, 공통은 부모에 두고 개별 기능만 자식/전용 인터페이스(예: `MessageRepository.findAllMessageByChannel`)에 추가하면 됩니다.

**Q. (ChannelServiceImpl 주석) 리포지토리 기능을 서비스에 구현했는데 실무에서도 이런가?**
아니요, 실무에선 저장 책임은 Repository로 분리합니다. 지금처럼 서비스가 `Map`을 직접 들고 있으면 "비즈니스 규칙"과 "저장"이 섞여 테스트·교체가 어려워져요. 채널도 도메인+레포로 빼서 User/Message와 계층을 맞추는 게 좋습니다.

**Q. (DTO 주석) `@Valid` 역할처럼 DTO에서 검증, 타입/표현식 체크는 어떻게?**
입력 검증을 DTO 생성자에 모은 접근은 좋습니다. 콘솔 앱에선 "문자열 → 타입 변환"에서 실패할 수 있으니(예: 숫자가 아닌 입력) 변환 지점(컨트롤러/뷰)에서 `NumberFormatException`을 잡아 사용자 메시지로 바꾸는 게 자연스러워요. 형식(정규식) 검증도 DTO의 `validXxx`에서 같이 하면 됩니다. Spring으로 가면 `@Valid` + `@NotBlank/@Size` 같은 선언적 검증으로 이 로직이 대체됩니다.

---

## 우선순위 요약

| 순위 | 항목 | 성격 |
|---|---|---|
| 1 | findAllUser 무한 재귀 | 버그(치명) |
| 2 | delete/update 저장 안 됨 + CME + 채널 update 항상 실패 | 버그 |
| 3 | makeChannel 저장 누락 | 버그 |
| 4 | 두 구현 트리(discodeit vs sprint0) 통합 | 구조 |
| 5 | .ser 소스폴더 커밋 + 경로 하드코딩 | 위생 |
| 6 | saveEntity append 누적(List→Map) | 설계 |
| 7 | 테스트 스왑/오염/실패, 주석·죽은 코드 정리 | 위생 |
