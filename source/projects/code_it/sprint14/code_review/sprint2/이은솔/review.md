# 코드 리뷰 — [이은솔] 스프린트2 (PR #12)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/12
- **작성자**: EUNSOLY (이은솔)
- **범위**: Discodeit 콘솔 앱 — BaseEntity 상속, UserStatus enum, Repository/Service 분리, JCF/File 영속화
- **규모**: +2153줄, 36 files, 24 commits
- **라벨**: 매운맛🔥

---

## 총평

`BaseEntity` 상속으로 공통 필드를 뽑아내고, `UserStatus`를 enum으로 제약하고, `Repository` 인터페이스 + `Basic*Service`(생성자 주입)로 저장/비즈니스 로직을 분리한 방향이 좋습니다. `serialVersionUID`를 명시한 점, 메시지의 다양한 조회(findByUserId/ChannelId/둘 다)를 구현한 점도 칭찬할 부분이에요.

다만 구조가 **① 구(舊) `JCF*Service`/`File*Service` + 신(新) `Basic*Service`+`Repository`가 공존**해서 중복이 크고, **② 파라미터 순서 불일치로 인한 실질 버그**, **③ `static` 필드로 인한 상태 공유**, **④ DTO 부재로 엔티티가 전 계층에 노출**되는 점이 핵심 개선 포인트입니다.

---

## 🔴 Critical (버그)

### 1. `findByChannelIdAndUserId` 파라미터 순서 불일치 → 조회 결과가 틀림
인터페이스 / 구현 / 호출부에서 `(channelId, userId)` 순서가 제각각이라, 실제로 잘못된 필터가 걸립니다.

- **인터페이스** `MessageRepository.findByChannelIdAndUserId(UUID channelId, UUID userId)` — 계약은 (channelId, userId)
- **JCFMessageRepository** 구현은 `(UUID userId, UUID channelId)` — **이름이 뒤바뀜**
- **BasicMessageService**(line 1743 부근)는 `messageRepository.findByChannelIdAndUserId(userId, channelId)` 로 **뒤집어서 호출**

지금은 "BasicService의 뒤집힌 호출"과 "JCFMessageRepository의 뒤집힌 구현"이 **우연히 서로 상쇄**돼서 JCF 경로에서만 동작합니다. 하지만 `FileMessageRepository`는 인터페이스 순서(channelId, userId)를 그대로 따르므로, Basic이 File 레포와 결합되면 **필터가 뒤바뀌어 빈 결과/오답**이 나옵니다.

또한 `JavaApplication`의 `JCFMessageService.findByChannelIdAndUserId(UUID channelId, UUID userId)`도 호출은 `(aaron=userId, channel1=channelId)`로 하는데 내부 필터가 파라미터명 기준이라, **"채널1 + 아론 메시지" 조회가 실제로는 빈 리스트**가 됩니다.

> 수정: 인터페이스·구현·호출부의 파라미터 순서를 **하나로 통일**(권장: `(channelId, userId)`). 이런 "같은 타입 인자 2개"는 순서 실수가 잦아서, IDE 파라미터 힌트나 테스트로 잡는 걸 추천합니다.

---

## 🟡 Major (구조/정합성)

### 2. `JavaFileIOApplication` 배선 오류 + `BasicMessageService.save` 검증 누락 (두 버그가 서로 가림)
```java
UserService userService = new BasicUserService(new JCFUserRepository());        // JCF
ChannelService channelService = new BasicChannelService(new JCFChannelRepository());
MessageService messageFileService =
        new BasicMessageService(new FileMessageRepository(), userService, channelService); // ← File인데 JCF 서비스 주입
```
`messageFileService`는 이름은 File인데 검증용 의존성으로 **JCF 기반 `userService`/`channelService`**를 받고 있습니다. `userFileService`/`channelFileService`를 넣어야 맞아요.

이 버그가 지금 안 터지는 이유는 **`BasicMessageService.save()`가 존재 검증을 아예 안 하기 때문**입니다:
```java
public void save(Message user) { messageRepository.save(user); }   // 검증 없음
```
반면 `JCFMessageService.save`/`FileMessageService.save`는 user/channel 존재를 검증합니다. 즉 심화 리팩터링(`Basic*Service`)으로 오면서 **"메시지의 sender/channel이 존재해야 한다"는 비즈니스 규칙이 유실**됐어요. 규칙을 `BasicMessageService.save`로 되살리면, 위 배선 오류도 즉시 드러납니다.

### 3. 구/신 구현 3중 공존 — `service/file/*`는 dead code
현재 서비스가 세 벌입니다:
- `service/jcf/*` (Map 직접 보유 + 검증) — `JavaApplication`에서 사용
- `service/file/*` (File IO 직접 수행 + 검증) — **어디서도 사용 안 됨** (`JavaFileIOApplication`은 `Basic*Service` + `FileRepository`를 씀)
- `service/basic/*` (Repository 주입) — `JavaFileIOApplication`에서 사용

미션 진행 단계상 남은 흔적이지만, 완성 기준으로는 **`Basic*Service` + `Repository`가 정답 구조**이고 `service/file/*`(3개)는 죽은 코드, `service/jcf/*`도 데모 전용입니다. 최종적으로는 `Basic*Service`로 일원화하고 `JavaApplication`도 `Basic`+`Repository`로 맞추는 걸 권장합니다.

### 4. `static` 필드로 인한 상태 공유 (숨은 전역 싱글턴)
- `JCFUserRepository`/`JCFChannelRepository`/`JCFMessageRepository` 모두 `private static final Map data`
- `JCFMessageService`도 `static Map data`

`static`이라 `new`로 몇 개를 만들든 **모든 인스턴스가 같은 데이터를 공유**합니다. 이건 사실상 "숨은 싱글턴"이라, 테스트 격리가 안 되고(한 테스트 데이터가 다음 테스트로 샘) 동작이 직관과 어긋납니다. 인스턴스 필드(`private final Map data = new HashMap<>()`)로 바꾸고, "하나만 유지"가 필요하면 생성 지점(팩토리/메인)에서 참조를 한 번만 만들어 주입하세요. (→ 멘티 Q1 답변과 연결)

### 5. 싱글턴 적용이 도메인마다 불일치
`JCFUserService`·`JCFChannelService`는 `SingletonHolder`+`getInstance()`인데, `JCFMessageService`는 생성자로 의존성을 받는 일반 클래스입니다. `JavaApplication`도 User/Channel은 `getInstance()`, Message는 `new`로 섞여 있어요. 같은 계층이면 생성 방식을 통일하는 게 읽기 좋습니다.

### 6. 예외/반환 정책 혼재
- Repository는 못 찾으면 `null` 반환, Service는 `RuntimeException` throw — 계층 간 정책이 다름
- 모든 예외가 메시지 문자열만 담은 **bare `RuntimeException`** (타입이 없어 호출부가 구분 불가)
- 검증 실패 메시지 복붙: 채널 검증인데 `"잘못된 사용자 ID 입니다"` (FileMessageService/JCFMessageService)
- 커스텀 예외 타입(enum 등)으로 정리하면 일관성과 표현력이 올라갑니다.

### 7. 매 CRUD마다 파일 전체 R/W + 디버그 로그
File 레포는 `save/find/delete`마다 `load()`(전체 역직렬화) → 수정 → `fileSave()`(전체 직렬화)를 반복합니다(멘티 Q3). 게다가 `load()`가 매번 `System.out.println("역직렬화 완료" + map)`를 찍어 콘솔이 매우 시끄럽습니다. 디버그 출력은 제거하고, 개선 전략은 아래 Q3 답변 참고.

---

## 🔵 Minor / 💡 Nit

- **`BaseEntity`가 `abstract`가 아님** — 직접 인스턴스화될 일이 없으니 `abstract class`로 두면 의도가 드러남 (→ 멘티 Q2)
- **`BaseEntity`만 수동 getter, `UserStatus`는 Lombok** — `@Getter` 사용 여부를 프로젝트 차원에서 통일
- **파라미터명 오용**: `BasicChannelService.save(Channel user)`, `BasicMessageService.save(Message user)` — Channel/Message인데 `user`
- **메서드 네이밍 불일치**: Repository는 `findById`, Service는 `find` / 엔티티 수정이 `changeName`(Channel), `update`(User), `changeMessage`(Message)로 제각각
- **오타**: `됬습니다` → `됐습니다` (여러 곳)
- **unchecked cast**: `(Map<UUID, X>) readObject()` — `@SuppressWarnings("unchecked")` 명시 권장
- **`Message.java` / `User.java` 파일 끝 개행 없음(No newline at EOF)**
- **`JavaApplication` 마지막 "심화 검증 테스트"**: 잘못된 userId로 `save` → 예외가 `catch(Exception e){ throw new RuntimeException(e); }`로 재던져져 앱이 예외로 종료됨. 의도한 실패 데모라면 메시지만 출력하도록 처리하는 게 깔끔

---

## 멘토에게 남긴 질문 4개 답변

### Q1. `static` 키워드로 인스턴스를 1개만 유지하고 데이터를 공유한 것도 싱글톤으로 볼 수 있나요? (의존성 주입이 필요한 경우 싱글톤 처리 방법)

두 가지를 분리해서 봐야 해요.

- **"`static` 필드로 데이터를 공유"하는 건 싱글톤이 아닙니다.** 싱글톤은 "클래스의 **인스턴스**가 하나임을 보장"하는 패턴이에요. `static Map data`는 인스턴스는 여러 개 만들어질 수 있고 **필드만 공유**되는 거라, 오히려 "전역 변수(global state)"에 가깝습니다. 인스턴스를 `new`로 3개 만들어도 데이터가 같은 걸 공유하니, 의도와 다르게 동작하기 쉽고 테스트 격리가 깨집니다.
- **의존성 주입이 필요하면 싱글턴을 클래스 스스로 관리하지 마세요.** `SingletonHolder`/`getInstance()`는 "인자 없이 스스로 생성"할 때만 쓸 수 있어서, 외부 의존성을 주입받아야 하는 순간 무너집니다(민재님도 같은 벽에 부딪혔어요). 해법은 **생성 책임을 외부로 옮기는 것**입니다. 지금처럼 `new BasicUserService(new JCFUserRepository())`를 한 군데(팩토리 또는 `main`)에서 **딱 한 번** 만들어 주입하면, "인스턴스 1개 유지"는 그 지점이 보장해 줍니다. 클래스 안엔 싱글턴 장치가 전혀 필요 없어요.
- 이게 바로 다음에 배울 **Spring의 싱글톤 빈**의 원리예요. 객체는 평범하게 만들고, "하나만 유지"는 컨테이너가 대신 보장합니다. 즉 *싱글턴은 객체가 하는 게 아니라 컨테이너/조립 지점이 하는 것*이라고 기억하면 됩니다.

### Q2. `BaseEntity`에 추상 메서드가 없어도 추상 클래스로 만드는 게 적절할까요?

네, **`abstract`로 두는 게 더 적절합니다.** 추상 클래스의 핵심 목적은 "추상 메서드를 강제"하는 것만이 아니라 **"이 클래스는 직접 인스턴스화하지 말고 상속해서 쓰라"는 의도를 타입으로 못박는 것**입니다. `BaseEntity`는 그 자체로 의미 있는 객체가 아니라 공통 필드(id/createdAt/updatedAt)를 나눠주기 위한 부모니까, `abstract class BaseEntity`로 선언해 `new BaseEntity()`를 컴파일 단계에서 막는 게 좋습니다. 추상 메서드가 하나도 없어도 추상 클래스는 완전히 정상입니다.

### Q3. 매 CRUD마다 파일을 읽어와 메모리에서 작업하는 방식이 맞나요? 더 나은 방향은?

관찰이 정확해요. 지금은 연산마다 파일 전체를 역직렬화→수정→전체 직렬화라 데이터가 커질수록 O(N) I/O가 매번 발생합니다. 가상 메모리 Map으로 짤 때는 "항상 메모리에 접근"이 자연스러웠지만, 그건 **메모리가 곧 원본**이라 접근 비용이 거의 없기 때문이고, 파일은 접근 자체가 비싸다는 게 차이예요.

개선 방향(난이도순):
1. **시작 시 1회 로드 → 메모리 Map을 원본으로 유지 → 특정 시점에만 flush**: `find/findAll`은 메모리에서 바로 반환(디스크 안 감), `save/delete`는 메모리 수정 후 원하는 시점에만 파일 쓰기.
2. 이때 **내구성 vs 성능** 트레이드오프가 생깁니다. 매 변경마다 쓰면(write-through) 안전하지만 느리고, 모아서 쓰면(write-back) 빠르지만 크래시 시 유실 위험. "이 데이터를 잃으면 얼마나 치명적인가"로 정합니다.
3. 더 나가면 변경분만 기록(append-only 로그), id별 파일 분리 등이 있고, 이걸 정석으로 푼 게 결국 **DB**(버퍼 풀=메모리 캐시, WAL=append 로그, checkpoint=flush 타이밍)입니다. 다음 스프린트 JPA로 가면 이 계층이 사라집니다.

이번 미션은 **1번(1회 로드 + flush)**만 적용해도 충분히 좋은 개선이에요.

### Q4. 이런 간단한 예제에서도 MVC로 DTO/Controller/Service를 나누는 기준은? 엔티티↔DTO 변환 로직은 DTO 안에 두는 게 맞나, 별도 변환 메서드가 맞나?

먼저 현재 코드는 **DTO가 전혀 없고 엔티티(`User`/`Channel`/`Message`)를 서비스 안팎으로 그대로 주고받고 있어요.** `messageService.save(message)`, `find`가 `Message`를 반환하는 식이죠. 그래서 지금은 "엔티티가 모든 계층에 노출"된 상태입니다. 기준을 정리하면:

- **나누는 기준 = 책임(계층별 관심사)**:
  - **Controller/View**: 외부 입출력 경계(콘솔 문자열 파싱, 결과 표현). "콘솔→HTTP로 바꾸면 바뀌는 코드"면 여기.
  - **Service**: 도메인 규칙(예: "메시지는 sender/channel이 존재해야 저장"). 입출력 수단을 몰라야 함.
  - **DTO**: 계층 간 "데이터 운반" 전용. 엔티티를 그대로 노출하지 않기 위한 방패.
- **DTO를 왜 두나(지금 규모에서도 의미 있는 이유)**: 엔티티를 그대로 반환하면 `password` 같은 민감 필드나 내부 구조가 그대로 새어 나갑니다. 또 엔티티에 외부 표현용 로직이 끼어들며 오염돼요. Request/Response를 분리하면 "받을 값"과 "보여줄 값"을 독립적으로 통제할 수 있습니다. 지금은 규모가 작아 체감이 덜하지만, 습관으로 들일 가치가 큽니다.
- **변환 로직 위치**: 권장은 **"DTO가 자신을 만드는 책임을 갖는" 정적 팩토리 메서드**예요.
  - `UserResponseDto.from(User user)` (엔티티 → 응답 DTO)
  - `dto.toEntity()` 또는 `User.from(createDto)` (요청 DTO → 엔티티)

  이렇게 하면 변환 규칙이 DTO 한곳에 모여 응집도가 높아집니다. 규모가 커져 변환이 복잡해지면 별도 Mapper(또는 MapStruct 같은 도구)로 분리하는 단계로 넘어가면 됩니다. 지금 단계에선 **DTO 안의 `from`/`toEntity` 정적 메서드**가 가장 실용적이에요.

---

## 우선순위 요약

| 순위 | 항목 | 성격 |
|---|---|---|
| 1 | #1 findByChannelIdAndUserId 파라미터 순서 불일치 | 버그 |
| 2 | #2 File 배선 오류 + BasicMessageService 검증 유실 | 버그 |
| 3 | #4 static 필드 상태 공유 | 구조 |
| 4 | #3 구/신 3중 구현 정리 (service/file dead code) | 구조 |
| 5 | #6 예외/반환 정책 통일 | 정합성 |
| 6 | #7 파일 전체 R/W + 디버그 로그 제거 | 효율·위생 |
| 7 | Minor/Nit (BaseEntity abstract, 네이밍, 오타 등) | 위생 |
