# 코드 리뷰 — [김민재] sprint2 (PR #10)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/10
- **작성자**: mjdevkim (김민재)
- **범위**: Discodeit 콘솔 앱 — 도메인 모델링(User/Channel/Message), File IO 영속화, DTO/팩토리/싱글턴
- **규모**: +2155줄, 50 files, 6 commits
- **라벨**: 매운맛🔥

---

## 총평

전체적으로 레이어 분리(entity / dto / repository / service), 정적 팩토리 메서드, 커스텀 예외(ExceptionType) 등 설계 의도가 명확하고 일관되게 잡혀 있습니다. 특히 예외 메시지를 detail/description/response 3단으로 나눈 점, DTO에서 입력 검증을 팩토리 메서드로 모은 점은 좋습니다.

다만 **① 실제로 쓰이지 않는 코드(dead code)가 절반 가까이** 되고, **② copy-paste로 인한 실질 버그(잘못된 예외 타입)**, **③ JCF/File 경로 간 예외 처리 불일치**가 있어 이 부분들을 정리하면 완성도가 크게 올라갑니다.

---

## 🔴 Critical (버그 — 반드시 수정)

### 1. `find`/`delete`에서 잘못된 예외 타입 (copy-paste 버그)
`FileChannelRepository`, `FileMessageRepository`가 없는 데이터에 대해 **`USER_NOT_FOUND`**를 던집니다. 채널/메시지를 못 찾았는데 "User를 찾을 수 없습니다"라는 메시지가 나갑니다.

- `FileChannelRepository.find()` — `ExceptionType.USER_NOT_FOUND` → `CHANNEL_NOT_FOUND` 여야 함
- `FileChannelRepository.delete()` — 동일
- `FileMessageRepository.find()` — `USER_NOT_FOUND` → `MESSAGE_NOT_FOUND`
- `FileMessageRepository.delete()` — 동일

> 애써 엔티티별 예외 타입(`CHANNEL_NOT_FOUND`, `MESSAGE_NOT_FOUND`)을 다 만들어 두고 정작 안 쓰고 있어요. 검증 코드를 복붙할 때 자주 나는 실수라, 이런 건 테스트로 잡으면 좋습니다.

### 2. 기본 실행 경로(JCF)에서 예외 메시지가 `null`로 출력됨
`main`은 `RepositoryType.JCF`로 실행되는데, JCF 레포지토리는 `CustomException`이 아니라 `orElseThrow()` / `NoSuchElementException`(메시지 없음)을 던집니다.

- `JCFUserRepository.find()` → `orElseThrow()` (bare `NoSuchElementException`, message = null)
- `JCFChannelRepository`, `JCFMessageRepository`도 동일하게 `NoSuchElementException`

`main`의 "6. 삭제 확인" 블록은 `catch (Exception e) { println(e.getMessage()); }` 이므로, **기본 실행 시 사용자에게 정성껏 만든 안내 메시지 대신 `null`이 출력**됩니다. File 경로(CustomException)와 JCF 경로(NoSuchElementException)의 예외 정책이 서로 달라서 생기는 문제입니다. 두 경로 모두 `CustomException`으로 통일하는 걸 권장합니다.

---

## 🟡 Major (구조 — 정리 강력 권장)

### 3. Service 구현체 6개가 dead code
`ServiceFactory`는 저장 방식(JCF/FILE)과 무관하게 항상 `BasicUserService` / `BasicChannelService` / `BasicMessageService`만 생성합니다. 즉:

- `service/jcf/JCFUserService`, `JCFChannelService`, `JCFMessageService`
- `service/file/FileUserService`, `FileChannelService`, `FileMessageService`

이 **6개 클래스는 어디서도 생성되지 않습니다.** `Basic*Service`가 `Repository 인터페이스`에 의존하고, 팩토리가 주입할 구현체(JCF/File repo)만 바꿔주는 지금 구조가 정답에 가깝습니다. jcf/file 서비스 패키지는 통째로 삭제하면 코드량이 크게 줄고 의도도 더 선명해집니다.

### 4. Singleton(`getInstance`) + 생성자 주입(DI)의 충돌
모든 Repository가 `private 생성자 + LazyHolder`로 싱글턴인데, 동시에 서비스에 생성자로 주입되고 있습니다. 이미 DI를 쓰고 있으므로 싱글턴은 불필요하고, 오히려 해롭습니다.

- 테스트에서 매번 새 인스턴스/목(mock)을 주입하기 어려움 (상태가 공유됨)
- `createFactory`를 여러 번 호출해도 같은 싱글턴 인스턴스라 데이터가 전역 공유됨

객체 생성 책임은 `ServiceFactory`(또는 이후 DI 컨테이너)에 맡기고, Repository는 평범한 `new`로 만드는 걸 권장합니다. "인스턴스를 하나만 유지"는 팩토리가 참조를 한 번만 만들어 넘겨주는 것으로 충분히 달성됩니다.

### 5. File 서비스가 인터페이스가 아닌 구현체에 의존 (DIP 위반)
(dead code라 3번으로 삭제되면 자연 해소되지만, 패턴 자체를 짚어둡니다.)

- `FileUserService`는 `UserRepository`가 아니라 `FileUserRepository`(구현체)를 필드로 가집니다. `FileChannelService`, `FileMessageService`도 동일.

`Basic*Service`처럼 **항상 인터페이스 타입에 의존**해야 저장 방식 교체가 자유로워집니다.

### 6. `Serializable`인데 `serialVersionUID` 없음
`Entity`(및 하위 User/Channel/Message)가 `Serializable`을 구현하지만 `serialVersionUID`가 없습니다. 클래스가 바뀌면 기존에 저장된 `.ser` 파일 역직렬화가 `InvalidClassException`으로 깨질 수 있습니다. File 영속화를 쓰는 이상 명시하는 게 안전합니다.

### 7. 런타임 산출물 `.ser` 파일이 git에 커밋됨
`channels.ser`, `messages.ser`, `users.ser`가 저장소에 포함되어 있습니다. 실행 결과물이므로 `.gitignore`에 추가하고 tracking에서 제거하는 게 맞습니다. (`.gitignore`에 `*.ser` 추가)

---

## 🔵 Minor

### 8. `User` 생성자만 `public` (다른 엔티티와 불일치 + 주석 모순)
`Channel`/`Message`는 생성자가 `private`인데 `User`는 `public`입니다. 심지어 주석은 `// ... 따라서 private으로`라고 되어 있어 코드와 반대입니다. 정적 팩토리 `User.from()`를 강제하려면 생성자를 `private`으로 막아야 합니다.

### 9. DTO 필드 불변성(immutability)이 제각각
- `ChannelCreateRequestDto`, `MessageCreateRequestDto` → 필드가 `private` (가변)
- `UserCreateRequestDto`, `*UpdateRequestDto` → `private final`
- `*ResponseDto` → `@FieldDefaults(makeFinal = true)`

DTO는 전부 불변이 자연스럽습니다. 한 가지 방식(예: `@FieldDefaults(makeFinal=true)` 또는 `private final`)으로 통일하는 걸 권장합니다.

### 10. `settings.gradle` 프로젝트명이 `1-sprint-mission`
sprint2 / 14기인데 `rootProject.name = '1-sprint-mission'`으로 남아 있습니다. (이전 미션 복사 흔적으로 보임)

### 11. unchecked cast 경고
`loadFile`의 `(Map<UUID, X>) objectInputStream.readObject()`는 unchecked 경고가 납니다. 직렬화 특성상 완전히 피하긴 어렵지만, `@SuppressWarnings("unchecked")`로 의도를 명시해두면 좋습니다.

---

## 💡 Nit (사소, 제출 전 정리)

- **미사용 import 다수**: `MessageRepository`의 `User` import, `FileUserRepository`의 lombok `@NoArgsConstructor`, `JCFMessageService`/`JCFChannelService`의 여러 repository import 등.
- **`QQQ`/디버그 주석·죽은 주석 정리**: `JavaApplication`의 주석 처리된 FILE 팩토리, `User.java`/`CustomException`/`JCFUserService`/`ServiceFactory`의 `QQQ`, `JCFChannelService`의 `// 굳이인가요?` 등. 리뷰 요청 지점을 PR 코멘트로 옮기면 코드가 깔끔해집니다.
- **`JCFUserService.update()`는 `save()` 호출이 없음**: JCF는 같은 참조를 in-place 수정해서 우연히 동작하지만, `Basic*Service`처럼 `save()`를 호출해 저장 방식과 무관하게 동일하게 동작하도록 맞추는 게 안전합니다. (단 이 클래스는 dead code라 3번대로 삭제 시 무의미)

---

## 멘토에게 남긴 질문 답변

### Q1. DTO를 Create/Update/Response로 세분화하는 게 적절한가? 오버엔지니어링 아닌가?

지금 규모에선 "약간 과하다"가 맞고, 동시에 "습관으로 들여둘 가치가 있다"도 맞습니다.

- **Response와 Request를 나눈 건 정답입니다.** `UserResponseDto`가 `password`를 빼고 내보내는 것처럼, 노출 필드와 입력 필드는 애초에 목적이 달라서 엔티티와 1:1이 아니게 됩니다. 이 차이는 지금 프로젝트에서도 이미 드러나고 있어요.
- **Create/Update를 나눈 것도 근거가 있습니다.** Create엔 id가 없고 Update엔 id가 필수, 또 Update에서 어떤 필드를 부분 수정 허용할지가 달라집니다. 실제로 `MessageUpdateRequestDto`는 `content`만 받죠 — 이게 바로 분리의 이유입니다.
- **분리 기준**: "필드 구성이 달라지는가 / 검증 규칙이 달라지는가"입니다. 완전히 같다면 합쳐도 되고, 하나라도 다르면 나누는 게 유지보수에 유리합니다.
- 다음 단계로 Spring MVC/JPA에 들어가면 이 분리가 "오버"가 아니라 "기본"이 됩니다. 지금 감을 잡아두는 건 좋은 투자예요.

### Q2. `save`/`find`/`delete` 때마다 스트림을 열고 파일 전체를 읽고 쓰는데 비효율적이지 않나?

맞습니다. 지금은 매 연산마다 전체 Map을 역직렬화→수정→전체 직렬화하고 있어서 O(N) 디스크 I/O가 매번 발생합니다. 실무에서 쓰는 접근을 단계별로 소개하면:

1. **인메모리 캐시 + 시점 flush**: 애플리케이션 시작 시 파일을 한 번 로드해 Map을 메모리에 유지하고, 변경은 메모리에 반영한 뒤 종료 시점(또는 주기적으로) `flush`. 지금 코드의 `channelMap` 필드가 매번 재할당돼 사실상 캐시 역할을 못 하고 있는데, 이걸 "로드는 1회, 이후 메모리 우선"으로 바꾸면 됩니다.
2. **레코드 단위 저장**: 전체를 한 파일에 직렬화하는 대신 id별 파일 또는 append-only 로그로 나눠 변경분만 기록.
3. **결국은 DB**: 이 문제를 정석으로 푼 게 DBMS입니다. 인덱스, 버퍼 풀, WAL(write-ahead log)이 정확히 이 "매번 전체 쓰기" 문제를 해결하려고 존재합니다. 다음 스프린트에서 JPA로 넘어가면 이 고민이 자연스럽게 해소됩니다.

지금 미션 수준에선 **1번(로드 1회 + 종료 시 flush)**만 적용해도 충분히 좋은 개선이고, 배우는 포인트도 큽니다.

### Q3. Controller와 Service의 역할 구분, 콘솔 앱에서 MVC 적용 방향은?

"Controller가 Service랑 똑같아진다"는 관찰은 아주 정확합니다. 지금 단계에선 실제로 그렇게 보이는 게 정상이고, 역할이 갈리는 기준은 이렇습니다:

- **Controller = 입출력 경계 담당**: 외부 입력(콘솔 문자열, 나중엔 HTTP 요청)을 파싱해서 DTO로 만들고, 어떤 Service를 호출할지 라우팅하고, 결과를 표현 형식으로 변환. **"무엇을 어떻게 보여줄지/받을지"**를 압니다.
- **Service = 비즈니스 규칙 담당**: "메시지를 보내려면 sender와 channel이 존재해야 한다" 같은 도메인 규칙. **입출력 수단(콘솔인지 HTTP인지)을 몰라야** 합니다.

구분 테스트: *"콘솔을 HTTP로 바꾸면 이 코드가 바뀌어야 하나?"* → 바뀌면 Controller, 안 바뀌면 Service.

지금처럼 CRUD를 그대로 흘려보내는 단계에선 Controller가 얇아서 Service와 닮아 보이지만, 입력 검증/파싱/에러 표현/여러 Service 조합이 들어가기 시작하면 자연스럽게 분리됩니다. 제안하신 `InputView → Controller → Service → OutputView` 구조가 정석이니 그대로 가면 됩니다. 억지로 로직을 만들어 채우기보다, **"경계 변환은 Controller/View, 규칙은 Service"** 원칙만 지키면 충분합니다.

---

## 우선순위 요약

| 순위 | 항목 | 성격 |
|---|---|---|
| 1 | #1 잘못된 예외 타입(USER_NOT_FOUND) | 버그 |
| 2 | #2 JCF 경로 예외 메시지 null | 버그 |
| 3 | #3 Service 구현체 6개 dead code 삭제 | 구조 |
| 4 | #4 Singleton vs DI 정리 | 구조 |
| 5 | #6/#7 serialVersionUID / .ser gitignore | 안정성·위생 |
| 6 | #8~ Minor/Nit 정리 | 위생 |
