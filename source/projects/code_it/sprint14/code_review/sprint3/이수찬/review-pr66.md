# 코드 리뷰 — [이수찬] 스프린트 3 미완성 (PR #66)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/66
- **작성자**: lsc0869 (이수찬)
- **범위**: Spring 전환 + 신규 엔티티 뼈대 + User DTO 착수 (본인 표기: 미완성)
- **규모**: +1463, 39 files 전부 신규, 8 commits
- **라벨**: 미완성🛠️
- **참고**: 담당 멘티 명단 외 학생. base 이수찬 브랜치가 initial commit 상태 (첫 제출)

> diff 전체(1696줄) 확인 완료. **미완성 PR → 격려 + 로드맵 원칙 적용. 단, 컴파일 에러 다수라 복구 순서 안내가 핵심.**

---

## 총평 — 방향은 잡혔고, "전환 중간에 멈춘" 상태

- **Spring 전환의 뼈대는 됨**: `@Service`/`@Repository` + `@RequiredArgsConstructor` 생성자 주입, ApplicationContext에서 getBean.
- **좋은 시도들**: `Service<T>` 제네릭 공통 인터페이스로 CRUD 중복 제거 시도, 중복 검증을 `existsByEmail`/`existsByName`으로 레포에 위임(정석!), File 레포의 loadData/saveData 분리 + try-with-resources + `Files.exists` 체크, User부터 DTO 전환 착수(UserCreate/Update/Response + toEntity/from 패턴).
- 다만 **"엔티티 기반 UserService → DTO 기반"으로 전환하다 중간에 멈춰서**, 인터페이스와 구현체가 서로 다른 언어를 쓰는 상태 → 컴파일 불가.

---

## 🔴 Critical — 컴파일이 안 되는 원인 4가지

### 1. `BasicUserService`가 `UserService` 인터페이스와 시그니처 불일치
- 인터페이스(`UserService extends Service<User>`): `void create(User)`, `User read(UUID)`, `void update(User, String, String)`
- 구현체: `UserResponseDto create(UserCreateRequestDto, BinaryContentCreateRequestDto)`, `UserResponseDto read(UUID)`, `UserResponseDto update(UUID, ...)`
→ @Override 불일치 + 미구현 추상 메서드로 컴파일 에러. **DTO 전환을 구현체에만 하고 인터페이스에 반영 안 한 것.** UserService를 `Service<User>` 상속에서 떼어내고 DTO 시그니처로 재선언해야 함.

### 2. `BasicUserService.update()`의 유령 변수 `user`
```java
public UserResponseDto update(UUID id, String updatedname, String updatedemail) {
    read(user.getId());   // ← user 변수가 없음 (파라미터를 User→UUID로 바꾸다 만 흔적)
    ...
    return UserResponseDto.from(user);  // ← from(user, boolean) 시그니처라 1인자 버전도 없음
}
```
(BasicUserService.java:70~)

### 3. 빈 인터페이스에 없는 메서드 호출
`UserStatusRepository`, `BinaryContentRepository`가 **빈 인터페이스**인데 BasicUserService가 `save()`, `findByUserId()`를 호출. 인터페이스에 메서드 선언 + 구현체(JCF/File) 작성 필요.

### 4. `new User("민준", "minjun@naver.com")` — 생성자 인자 불일치
User 생성자는 (name, email, profileId) 3개. `DiscodeitApplication.setupUser`(:21)와 `Main.java` 모두 2개로 호출 → 컴파일 에러. (User에 profileId 추가하면서 호출부 미수정)

## 🔴 심각 (컴파일 복구 후 바로)

### 5. `FileChannelRepository.filePath = "user.ser"` — 유저 파일을 덮어씀!
FileUserRepository와 **같은 파일명**. 채널 저장이 유저 데이터를 통째로 덮어쓰고, 역직렬화 때 ClassCastException. `"channel.ser"`로 수정 (복붙 후 미수정 흔적).

## 🟡 Major

- **`UserStatus.lastActiveAt`이 final** — "온라인 상태 업데이트" 요구사항을 구현할 수 없는 구조. 갱신 메서드 필요.
- **JCF 레포들이 빈 등록 안 됨** (@Repository 없음) — 지금은 File만 빈이라 우연히 동작. 심화(yaml 스위칭)에서 `@ConditionalOnProperty` 세트로.
- **`Main.java` 정리** — DiscodeitApplication과 중복 + `static void main()`(파라미터 없음)은 엔트리포인트가 아님 + IntelliJ TIP 주석 잔재. 삭제 권장.
- **예외가 전부 bare `RuntimeException`** — 조회실패=NoSuchElementException, 잘못된 인자/중복=IllegalArgumentException 표준 예외로.
- **application.yaml 부재** — sprint3 심화(스위칭 설정)의 전제.

## 🔵 Minor

- `Message.user_id`, `channel_id` — 스네이크 케이스, 자바는 camelCase (userId, channelId). attachmentIds는 선언만 되고 미사용.
- `Channel.setUpdatedAt(Instant)` — updatedAt을 외부에서 주입받는 setter는 위험. 각 setter의 `this.updatedAt = Instant.now()` 중복도 BasicEntity에 `markUpdated()` 하나로.
- Repository 인터페이스의 불필요한 `public` 한정자, 미사용 `import User` (Channel/Message 레포), `UserCreateRequestDto`의 미사용 lombok import.
- File 레포가 호출마다 전체 역직렬화 — 추후 캐시 고려 (지금은 OK).

---

## 로드맵 (학생 안내용 우선순위)

| 순서 | 할 일 |
|---|---|
| ① | UserService 인터페이스를 DTO 시그니처로 재선언 (Service<User> 상속 해제) |
| ② | BasicUserService.update 완성 (id로 조회한 User 변수 사용) |
| ③ | UserStatusRepository/BinaryContentRepository 메서드 선언 + JCF 구현 |
| ④ | setupUser 등 호출부 생성자 인자 수정 → **`./gradlew build` 성공 확인** |
| ⑤ | FileChannelRepository 파일명 `channel.ser`로 |
| ⑥ | UserStatus 갱신 메서드, Channel/Message DTO 확장, yaml 스위칭 |

---

## 코멘트 위치 (새 파일 → diff 라인 = 파일 라인)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| 인터페이스 불일치 (메인) | `service/UserService.java:9` | `void update(User, ...)` |
| 유령 변수 user | `service/basic/BasicUserService.java:71` | `read(user.getId());` |
| 빈 인터페이스 | `repository/UserStatusRepository.java:3` | 인터페이스 선언 |
| 생성자 인자 | `DiscodeitApplication.java:21` | `new User("민준", ...)` |
| user.ser 충돌 | `repository/file/FileChannelRepository.java:23` | `Path.of("user.ser")` |
| lastActiveAt final | `entity/UserStatus.java:9` | `private final Instant lastActiveAt` |
| Main 정리 | `Main.java:54` | `static void main()` |
| 스네이크 케이스 | `entity/Message.java:12-13` | `user_id`, `channel_id` |
| 칭찬: exists 위임 | `repository/jcf/JCFUserRepository.java:40` | `existsByEmail` |
| 칭찬: Service<T> 시도 | `service/Service.java:6` | 제네릭 인터페이스 |
