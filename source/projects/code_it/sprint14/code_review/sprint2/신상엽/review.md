# 코드 리뷰 — [신상엽] sprint2 (PR #13)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/13
- **작성자**: Smil-limS (신상엽)
- **범위**: Discodeit 콘솔 앱 — BaseEntity(abstract), JCF/File 영속화, AbstractFileRepository, Basic*Service DI
- **규모**: +1547줄, 35 files, 32 commits
- **라벨**: 매운맛🔥

---

## 총평 (잘한 점이 많음)

앞선 제출물들과 비교해 구조 완성도가 눈에 띄게 높습니다. 특히:
- **`BaseEntity`를 `abstract`로 선언** — 직접 인스턴스화 방지 의도가 명확
- **정적 팩토리 `create()` + `private` 생성자**를 User/Channel/Message에 일관 적용
- **`AbstractFileRepository<T extends BaseEntity>`로 직렬화 공통 로직을 한 곳에 추출** — DRY를 제대로 실천 (다른 제출물들이 6곳에 복붙한 걸 여기선 부모 하나로 해결)
- **`Basic*Service` + Repository 생성자 주입**, 메시지 생성 시 user/channel 검증 존재
- **`IllegalArgumentException`(의미 있는 예외) + 에러 메시지 `static final` 상수화**
- `.ser` 파일 미커밋, `settings.gradle` 이름 정상, Lombok 일관 사용

아래는 그럼에도 개선하면 좋은 지점들입니다.

---

## 🔴 Critical — `AbstractFileRepository`가 예외를 삼킴 (데이터 유실 위험)

지금 실제 영속화를 담당하는 `AbstractFileRepository`가 예외를 `printStackTrace()`로 찍고 **삼켜버립니다.** 이게 가장 위험한 지점이에요.

```java
protected Map<UUID, T> loadData() {
    ...
    } catch (IOException | ClassNotFoundException e) {
        e.printStackTrace();
        return new HashMap<>();   // ← 파일이 깨져도 "빈 데이터"로 조용히 진행
    }
}

protected void saveData(Map<UUID, T> data) {
    try (...) {
        oos.writeObject(data);
    } catch (IOException e) {
        e.printStackTrace();      // ← 저장 실패해도 그냥 넘어감
    }
}
```

**왜 위험한가:**
- `loadData()`: 파일이 손상되거나 클래스 버전이 안 맞으면 예외를 삼키고 **빈 `HashMap`을 반환**합니다. 그러면 데이터가 실제로는 있는데 "아무것도 없다"고 인식하고, 심지어 그 상태에서 `save`하면 **기존 파일을 빈 데이터로 덮어써서 진짜로 유실**될 수 있어요.
- `saveData()`: 저장이 실패해도 `save()`는 예외 없이 엔티티를 그대로 반환합니다. 호출부는 **"저장 성공"으로 착각**합니다. 디스크가 꽉 찼거나 권한이 없어도 아무도 모릅니다.
- `printStackTrace()`는 로그를 stderr에 흘릴 뿐 흐름 제어를 못 합니다(실무에선 안티패턴).

**어떻게 고치나:**
복구 가능한 경우(파일 없음)만 조용히 처리하고, 나머지는 원인을 담아 다시 던지세요.
```java
protected Map<UUID, T> loadData() {
    File file = new File(filePath);
    if (!file.exists()) return new HashMap<>();          // 정상: 최초 실행
    try (var ois = new ObjectInputStream(new FileInputStream(filePath))) {
        return (Map<UUID, T>) ois.readObject();
    } catch (IOException | ClassNotFoundException e) {
        throw new RuntimeException("데이터 로드 실패: " + filePath, e);  // 원인 보존
    }
}
protected void saveData(Map<UUID, T> data) {
    try (var oos = new ObjectOutputStream(new FileOutputStream(filePath))) {
        oos.writeObject(data);
    } catch (IOException e) {
        throw new RuntimeException("데이터 저장 실패: " + filePath, e);  // 실패를 숨기지 않음
    }
}
```
> "삼켜도 되는 예외(파일 없음=최초 실행)"와 "삼키면 안 되는 예외(저장 실패, 파일 손상)"를 구분하는 게 핵심입니다.

---

## 🟡 Major

### 1. `update()`가 null로 덮어쓰고, 없는 id는 조용히 무시
```java
// BasicUserService.update
public void update(UUID id, String name, String email, String nickname) {
    User user = userRepository.findById(id);
    if (user != null){
        user.changeName(name);       // name이 null이면 이름을 null로 지워버림
        user.changeEmail(email);
        user.changeNickname(nickname);
        userRepository.save(user);
    }
    // else: 아무 일도 안 일어남 — 없는 id를 수정해도 성공한 것처럼 조용히 넘어감
}
```
두 가지 문제가 있어요:
- **null 덮어쓰기**: "이메일만 바꾸고 싶어서 name=null"로 넘기면 이름이 지워집니다. 부분 수정이 필요하면 `if (name != null)` 가드가 있어야 하고, 전체 교체(full replace)가 의도라면 그 계약을 문서/이름으로 명확히 해야 합니다.
- **없는 id 무시**: `create`는 검증 후 예외를 던지는데 `update`/`delete`/`read`는 없는 id에도 조용히 no-op/null입니다. 계층 전반의 "없을 때 어떻게 할지" 정책을 통일하는 게 좋아요(예: 없으면 예외).

추가로, `changeName/changeEmail/changeNickname`이 각각 `newUpdatedAt()`을 호출해서 **한 번의 update에 updatedAt이 3번** 갱신됩니다(무해하지만 군더더기).

### 2. `service/jcf/*`, `service/file/*` 6개가 dead code
`JavaApplication`은 `Basic*Service` + `File*Repository`(`getInstance`)만 씁니다. `JCF*Service`, `File*Service`는 main에서 주석 처리돼 있고 실제로 아무도 안 써요. 게다가 `File*Service`는 `AbstractFileRepository`가 이미 한 곳으로 모아둔 직렬화 로직을 **다시 복붙**하고 있어서 이중으로 불필요합니다. `Basic*Service` + `Repository`로 일원화하고 두 패키지는 삭제 권장.

### 3. `File*Repository` 싱글턴 — 스레드 안전하지 않고, 도메인마다 불일치
```java
private static FileChannelRepository instance;
public static FileChannelRepository getInstance() {
    if (instance == null){ instance = new FileChannelRepository(); }  // check-then-act 경쟁 조건
    return instance;
}
```
- 이 lazy init은 **스레드 안전하지 않습니다**(멀티스레드에서 인스턴스가 2개 생길 수 있음). 다른 코드에서 쓰던 `LazyHolder` 관용구가 이 문제를 깔끔하게 피합니다.
- `FileChannelRepository`/`FileMessageRepository`는 생성자가 `public`이라 싱글턴이 강제되지 않는데, `FileUserRepository`만 `private`입니다(불일치).
- JCF 레포는 싱글턴이 없고 File 레포만 있습니다(불일치).
- 무엇보다 이 레포들은 어차피 `BasicService`에 주입되므로, **싱글턴을 클래스가 스스로 관리할 필요가 없습니다.** 생성은 조립 지점(main)에서 한 번만 하고 주입하면 "인스턴스 1개"는 자연히 보장됩니다.

### 4. `FileRepository<T>` 네이밍/설계
- 공통 인터페이스 이름이 `FileRepository`인데 **`JCFChannelRepository`도 이걸 구현**합니다(`ChannelRepository extends FileRepository<Channel>` 경유). 즉 "JCF 레포가 File 레포다"라는 모순이 생겨요. 저장 매체 중립적인 이름(`Repository<T>`, `CrudRepository<T>`)이 맞습니다.
- 또 `UserRepository`가 `save/findById/findAll/deleteById`를 다시 선언하는데, 이미 `FileRepository<T>`에서 상속받는 메서드라 **중복 선언**입니다(제거 가능).

---

## 🔵 Minor / 💡 Nit

- **`serialVersionUID` 없음**: `BaseEntity implements Serializable`인데 미지정. 클래스 변경 시 기존 `.ser` 역직렬화가 깨질 수 있으니 명시 권장.
- **`*.ser` gitignore 부재**: 지금은 커밋 안 됐지만(👍), `.gitignore`에 `*.ser` 추가해두면 실수로 커밋되는 걸 예방.
- **미사용 import**: `JCF*Repository` 3개가 `import java.io.File`을 쓰지 않음. `JavaApplication`의 주석 처리된 import들.
- **unchecked cast**: `AbstractFileRepository`의 `(Map<UUID, T>) ois.readObject()` — `@SuppressWarnings("unchecked")` 명시 권장.

---

## 멘토에게 남긴 내용 답변

### ① "실행 반복하면 데이터가 덮어써지지 않고 추가돼서 findAll() 출력에 문제 → deleteAll()로 해결"

먼저 짚으면, **그건 버그가 아니라 영속화(persistence)가 정상 동작하는 증거**예요. 파일에 저장하는 이유가 바로 "프로그램을 껐다 켜도 데이터가 남아 있게" 하는 것이니, 두 번째 실행에서 첫 실행 데이터가 그대로 보이는 게 정상입니다. (메모리 Map만 썼다면 매번 사라졌겠죠.)

그럼 왜 "문제"처럼 보였나 하면, **매 실행마다 똑같은 고정 테스트 데이터를 `create`하기 때문**이에요. 그래서 실행할수록 같은 성격의 데이터가 쌓여 보인 겁니다. `deleteAll()`을 main 앞에 넣어 매번 비우는 건 동작은 하지만, **영속화를 스스로 무력화**하는 방법이라 방향이 살짝 어긋나요(저장하는 의미가 없어짐).

더 나은 접근:
- **테스트/시연 코드와 영속 데이터를 분리**: "매번 초기화하고 시연"이 목적이면 지금처럼 초기화하되, 그건 "테스트 편의"이지 "정상 운영 방식"이 아니라는 걸 구분.
- **id 기반 upsert의 특성 이해**: 지금 `save`는 `Map.put(id, entity)`라 **같은 id면 덮어쓰기**입니다. 실행마다 데이터가 "추가"된 건 매번 `create`가 **새 UUID**를 만들었기 때문이에요. 같은 논리적 데이터를 갱신하려면 고정 id로 다루거나 update를 쓰면 됩니다.
- 정리하면: `deleteAll()`은 "시연을 깨끗하게 보려는 임시 장치"로만 쓰고, "데이터가 쌓이는 것"을 버그로 여기지 않는 게 맞아요.

### ② "커밋 메시지 형식 — 개발자들이 쓰는 표준이 있나요?"

네, 널리 쓰이는 관례가 있습니다. 대표적인 게 **Conventional Commits**예요.

**형식**: `type: 요약` (필요하면 본문에 상세)
```
feat: 메시지 생성 시 유저/채널 존재 검증 추가

- BasicMessageService.create에서 senderId/channelId 유효성 검사
- 유효하지 않으면 IllegalArgumentException
```
**자주 쓰는 type:**
- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 동작 변화 없는 구조 개선
- `docs`: 문서
- `test`: 테스트 추가/수정
- `chore`: 빌드/설정 등 잡무
- `style`: 포맷팅(로직 변화 없음)

**핵심 원칙 몇 가지:**
- **제목은 명령문(imperative)**: "추가함/added"보다 "추가"("add") — "이 커밋을 적용하면 ~한다"로 읽히게.
- **제목은 50자 내외, 무엇을/왜에 집중** (어떻게는 코드가 말해줌).
- **한 커밋 = 한 논리적 변경**: 여러 기능을 한 커밋에 섞지 않기.

AI에게 대신 쓰게 하는 것도 좋지만, "내가 무엇을·왜 바꿨는지"를 한 줄로 요약하는 연습 자체가 설계를 돌아보게 해서 도움이 됩니다. 처음엔 `type: 요약` 한 줄만 지켜도 충분해요.

---

## 우선순위 요약

| 순위 | 항목 | 성격 |
|---|---|---|
| 1 | 🔴 AbstractFileRepository 예외 삼킴(데이터 유실) | 버그/신뢰성 |
| 2 | update null 덮어쓰기 + 없는 id 무시 | 버그 |
| 3 | service/jcf·file 6개 dead code | 구조 |
| 4 | File 레포 싱글턴(스레드 비안전·불일치·vs DI) | 구조 |
| 5 | FileRepository<T> 네이밍/중복 선언 | 설계 |
| 6 | serialVersionUID / *.ser gitignore / 미사용 import | 위생 |
