# 코드 리뷰 — 미션 2-1 CRUD [조예준] (PR #24)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/24
- **작성자**: joyejun (조예준)
- **범위**: 2-1 JCF CRUD — 엔티티 3(User/Chennel/Message) + 서비스 인터페이스 3 + JCF 구현 3 + JavaApplication
- **규모**: +719줄, 19 files, 1 commit
- **작성자 메모**: "CRUD 구현까지 완료, 점차 수정해나가겠습니다" (초기 단계)

---

## 총평

초기 단계인데 계층(entity / service 인터페이스 / jcf 구현)을 나누고, `Map<UUID, T>`로 저장하고, 각 연산에서 존재 여부를 검사해 예외를 던지는 골격은 잘 잡았어요. 다만 지금 상태로는 **실행해서 확인할 수가 없고(메인 없음), 일부 조회/수정이 항상 실패하는** 버그가 있어서, 아래를 잡으면 "실제로 도는 CRUD"가 됩니다. 초기이니 편하게 하나씩 고쳐가면 돼요.

---

## 🔴 먼저 잡아야 실제로 동작함

### 1. `JavaApplication`에 `main` 메서드가 없음 → 아무것도 실행되지 않음
📁 `JavaApplication.java`
```java
public class JavaApplication {
    JCFUserServie jcfUserServie = new JCFUserServie();   // 인스턴스 필드일 뿐
    User user1 = new User("yejun", ...);
    // main 메서드가 없음
}
```
지금은 필드 선언만 있고 `public static void main(String[] args)`가 없어서 CRUD가 한 번도 실행되지 않아요. main을 만들어 create→read→update→delete를 호출해봐야 동작을 확인할 수 있습니다. (user1~3이 전부 같은 값인 것도, 확인용이라면 서로 다르게 만드는 게 좋아요.)

### 2. `JCFMessageService`의 `messageRead`/`messageUpdate`가 항상 실패
📁 `service/jcf/JCFMessageService.java` (+ 인터페이스 `MessageService.java`)
```java
public Message messageRead(Integer id) {              // 파라미터가 Integer
    if(!messageMap.containsKey(id)) { ... 예외 ... }   // 맵 key는 UUID
}
```
맵은 `Map<UUID, Message>`인데 `id`가 `Integer`라, `containsKey(Integer)`는 **UUID 키와 절대 일치하지 않아 항상 false** → 늘 "없습니다" 예외가 납니다. 파라미터를 `UUID id`로 바꿔야 해요(다른 서비스처럼).

### 3. `JCFChennelService.read`가 항상 `null`
📁 `service/jcf/JCFChennelService.java`
```java
public Chennel read(Chennel chennel) {
    ...
    return chennelMap.get(chennel);   // ← Chennel 객체를 key로 조회
}
```
맵 key는 `UUID`인데 `get(chennel)`은 Chennel 객체를 키로 넘겨서 **항상 null**입니다. `chennelMap.get(chennel.getId())`로 고쳐야 해요.

### 4. `JCFUserService.read`가 저장된 유저가 아니라 입력값을 반환
📁 `service/jcf/JCFUserServie.java`
```java
User userRead = userMap.get(user.getId());
...
return user;      // ← 조회 결과(userRead)가 아니라 파라미터를 반환
```
`return userRead;`가 맞아요. 지금은 조회해놓고 입력받은 객체를 그대로 돌려줍니다.

---

## 🟡 설계/구조

### 5. `Message`에 User/Channel 연관이 없음
📁 `entity/Message.java` — 필드가 `sendMessage`, `receiveMessage`(문자열 2개)뿐이라, **메시지가 어떤 사용자/채널에 속하는지** 표현이 없어요. 보통 메시지는 `content` + `senderId(UUID)` + `channelId(UUID)`를 가집니다. 심화의 "연관관계 검증"으로 이어지는 부분이라, 도메인 모델을 이 방향으로 잡아두면 좋아요.

### 6. 서비스 인터페이스를 전부 `default`(예외 던짐)로 선언
📁 `service/UserService.java`, `ChennelService.java`, `MessageService.java`
```java
default void create(User user){
    throw new RuntimeException("... 디폴트 메세지입니다.");
}
```
인터페이스 메서드를 `default`로 두면 **구현체가 실수로 하나를 안 오버라이드해도 컴파일 에러가 안 나고, 런타임에 예외**가 납니다. 계약(반드시 구현해야 할 메서드)은 그냥 **추상 메서드**로 두는 게 맞아요:
```java
public interface UserService {
    void create(User user);
    User read(UUID id);
    void update(UUID id, String name, String email, String password);
    void delete(UUID id);
}
```
이러면 안 만든 메서드는 컴파일 단계에서 바로 잡힙니다.

---

## 🔵 Minor / 💡 Nit

- **클래스·메서드 이름 오타**: `Chennel`(→Channel), `JCFUserServie`(→Service), `JCFChennelService`, `getpassword()`(→getPassword). 이름은 API로 굳어지니 초기에 바로잡는 게 좋아요.
- **복붙 메시지**: 채널·메시지 서비스인데 로그가 `"유저를 생성했습니다"`, `"생성하시려는 유저가 이미 있습니다"`로 유저용 문구예요.
- **서비스가 `System.out.println`으로 출력**: 표현(출력)은 호출부에서, 서비스는 로직에 집중하는 게 계층 분리에 맞아요.
- **`.DS_Store` 커밋 + 루트 `.gitignore`가 이상함**: `.study0726/Member.java` 같은 항목이 들어가 있어요. `.DS_Store`는 ignore(+`git rm --cached`), 불필요한 항목 정리.
- **프로젝트가 `codeit/` 하위에 중첩**: 보통 저장소 루트에 gradle 프로젝트를 두는데 한 단계 들어가 있어요(동작엔 지장 없지만 관례상).
- **`updateAt` 초기값 `null`**: 다른 필드처럼 `createAt`으로 초기화하면 이후 null 처리 걱정이 줄어요.

---

## 정리 (우선순위)

| 순위 | 항목 | 파일 |
|---|---|---|
| 1 | `main` 없음 → 실행 불가 | `JavaApplication` |
| 2 | messageRead/Update `Integer` key → 항상 실패 | `JCFMessageService` |
| 3 | `read`가 `get(chennel)` → 항상 null | `JCFChennelService` |
| 4 | `read`가 입력값 반환 | `JCFUserServie` |
| 5 | Message 연관관계 없음 / 인터페이스 default 남용 | 설계 |
| 6 | 이름 오타·복붙 로그·.DS_Store 등 | 위생 |

초기 단계라 골격은 좋아요. **1~4번(실행/조회가 안 되는 것)부터** 잡으면 CRUD가 실제로 도는 걸 눈으로 확인할 수 있고, 그다음 5번(도메인/인터페이스)으로 넘어가면 자연스럽게 다음 미션과 이어집니다.
