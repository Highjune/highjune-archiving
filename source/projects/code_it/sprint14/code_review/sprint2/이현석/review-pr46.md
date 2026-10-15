# 코드 리뷰 — 이현석 sprint2-2 (PR #46)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/46
- **작성자**: giseo1107 (이현석)
- **범위**: sprint2-2 — File IO/직렬화, Repository 계층 분리, Basic(File)Service 주입
- **규모**: +1156, 33 files, 6 commits
- **작성자 메모**: "구조는 짰는데 구현은 거의 못 함. Serializable/transient는 넣어봤으나 실제 직렬화/역직렬화는 미구현" (미완성)

> 미완성 PR이라 "잘못된 코드 지적"보다 **다음에 뭘 채워야 하는지 + 개념 바로잡기** 위주로 정리했어요.

---

## 총평 — 뼈대는 잘 잡았어요 👍

- `service`(인터페이스) → `service/JCF`(구현) 구조로 나눈 것, Repository 인터페이스(`UserRepository` 등)를 선언한 것, Basic(File)Service가 Repository를 **생성자 주입**받게 한 것 — sprint2-2가 원하는 방향을 정확히 잡았어요.
- 엔티티에 `@Serial serialVersionUID`를 이름 정확히 넣은 것도 좋아요(직렬화 준비).

미완성이니, 아래는 "막힐 지점 + 개념" 순서로 봐주세요.

---

## 🔴 1. `id`에 `transient`를 붙이면 안 돼요 (직렬화 개념 핵심)
📍 `entity/User.java`, `Channel.java`, `Message.java`
```java
private transient final UUID id;   // ← transient
```
`transient`는 **"이 필드는 직렬화하지 말라(파일에 저장하지 말라)"**는 뜻이에요. 그런데 `id`는 객체의 **정체성(식별자)**이잖아요. `id`를 transient로 두면:
- 저장(직렬화) 시 id가 파일에 안 써지고,
- 불러오기(역직렬화) 시 id가 **`null`로 복원**돼요.
→ 파일에서 다시 읽으면 모든 객체의 id가 null이 되어, **`findById`로 아무것도 못 찾게** 됩니다. 직렬화 영속화 자체가 무의미해져요.

`transient`는 **저장하고 싶지 않은 것**(예: 비밀번호, 캐시/파생값)에 쓰는 거예요. `id`처럼 반드시 보존해야 하는 값엔 붙이면 안 됩니다. → `id`에서 `transient` 제거하세요. (실험으로 넣어보신 거라 하셨는데, 이 개념만 잡으면 돼요.)

## 🔴 2. Repository "구현체"가 없어서 File 경로가 못 돎
📍 `repository/` — `UserRepository`/`ChannelRepository`/`MessageRepository` **인터페이스만** 있고, 이를 구현하는 **실제 클래스(JCF용/File용)가 없어요.**
- `FileUserService`가 `UserRepository`를 생성자 주입받는데, 주입할 **구체 구현체(예: `FileUserRepository`, `JCFUserRepository`)가 없어서** 실제로 동작시킬 수가 없어요.
- 지금 도는 건 `service/JCF/JCFUserService`뿐인데, 얘는 Repository를 안 쓰고 자기 안에 `List`를 직접 들고 있어요(sprint2-1 방식).

→ 다음 할 일: **`repository/file/FileUserRepository implements UserRepository`**(ObjectOutputStream/InputStream으로 직렬화)와 **`repository/jcf/JCFUserRepository implements UserRepository`**(Map 보관)를 만들어서, 서비스에 주입하면 됩니다. 이게 sprint2-2의 핵심 작업이에요.

## 🔴 3. 컴파일 에러 — 인터페이스 이름으로 인스턴스 메서드 호출
📍 `repository/file/FileUserService.java`, `service/file/FileUserService.java` — `create()`
```java
UserRepository.save(user);   // ← 대문자 UserRepository (인터페이스 타입)로 호출
```
`UserRepository`(인터페이스 타입)로 `save`를 호출하고 있어요. `save`는 인스턴스 메서드라 **주입받은 필드 `userRepository`(소문자)로 호출**해야 해요 → `userRepository.save(user);`. 지금 이대로면 컴파일이 안 됩니다.

---

## 🟡 4. 클래스 위치·중복 정리
- **서비스가 `repository/` 패키지에 들어가 있어요**: `repository/file/FileUserService`, `FileChannelService`, `FileMessageService`는 이름도 동작도 "서비스"인데 repository 패키지에 있어요. 그리고 **똑같은 게 `service/file/`에도 또 있어요**(중복). 하나(`service/file/`)만 남기고 `repository/file/`의 서비스들은 삭제하세요.
- **`repository/JCF/`의 `JCFUserService`/`JCFChannelService`/`JCFMessageService`는 내용이 빈 껍데기**예요. 실제 구현은 `service/JCF/`에 있으니, `repository/JCF/`의 빈 클래스들은 삭제.
- 정리하면: **서비스는 `service/` 아래로, 레포지토리 구현체는 `repository/` 아래로** 역할에 맞게 위치를 맞추면 깔끔해져요.

## 🔵 Minor / Nit
- **미사용 import**: `FileUserService`의 `import java.io.FileReader`, `FileMessageService`의 `Channel`/`ChannelService` import는 안 쓰여요.
- **`.idea/` 커밋**: `.idea/gradle.xml`, `misc.xml`, `vcs.xml` 등 IDE 설정이 올라왔어요(sprint2-1과 동일). `.gitignore`에 `.idea/` 추가 권장.
- **엔티티 모델**: `User(name,age)`, `Message(name,count)`, `Channel(name,channelNum)`는 sprint2-1의 임시 모델 그대로예요. 이후 실제 도메인(예: Message는 content+senderId+channelId)로 발전시키면 좋아요.

---

## 정리 — 다음에 이 순서로

미완성이라 "고칠 것"보다 "채울 것" 위주예요:

| 순위 | 할 일 |
|---|---|
| 1 | `id`의 `transient` 제거 (직렬화 개념) |
| 2 | `JCF*Repository` / `File*Repository` **구현체 작성** → 서비스에 주입 (sprint2-2 핵심) |
| 3 | `UserRepository.save` → `userRepository.save` (컴파일 에러 수정) |
| 4 | 중복/빈 클래스 정리 (repository의 서비스들·빈 JCF 스텁 삭제), 위치 정돈 |
| 5 | 미사용 import, `.idea/` gitignore |

뼈대(인터페이스 + 주입 구조)를 잡아둔 게 좋은 출발이에요. **2번(레포 구현체)**을 채우면 File 저장이 실제로 돌아가고, 그때 **1번(transient)** 개념이 왜 중요한지 바로 체감될 거예요. 하나씩 채워가시면 됩니다.
