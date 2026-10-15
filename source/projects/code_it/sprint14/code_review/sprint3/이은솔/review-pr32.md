# 코드 리뷰 — [이은솔] 스프린트 미션3 (PR #32)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/32
- **작성자**: EUNSOLY (이은솔)
- **범위**: Spring Boot 전환 + 신규 도메인(ReadStatus/UserStatus/BinaryContent) + AuthService + DTO 그룹화 + 첨부파일
- **규모**: +2008 / -1027, 82 files, 35 commits
- **라벨**: 매운맛🔥

> 확인한 핵심 파일: `FileStorageUtil`, `FileAbstractRepository`, `BasicChannelService`, `BasicUserService`, `JCFUserRepository`, `application.yaml`. 나머지는 파일 목록으로 파악.

---

## 총평 — sprint2 대비 비약적 성장 👏

- **Spring Boot 전환이 정석적**: `@Service`/`@Repository`/`@Component` + `@RequiredArgsConstructor` **생성자 주입**. 필드/세터 주입 안 쓰고 생성자 주입으로 간 것 아주 좋아요.
- **`@ConditionalOnProperty`로 구현체 스위칭**: `application.yaml`의 `discodeit.repository.type`(jcf|file) 값에 따라 JCF/File 레포가 자동 선택됨(`matchIfMissing=true`로 기본 jcf). 지난 시즌 "싱글턴 vs DI" 고민이 이제 **Spring 컨테이너가 빈 관리**로 자연스럽게 풀린 모습이라 흐름이 좋습니다.
- **Repository가 `Optional` 반환**으로 개선 → 서비스에서 `orElseThrow`로 "없으면 예외" 정책 일관 적용.
- **DTO 그룹화 + `toEntity`/`from` 변환**을 서비스에서 처리 — 지난 리뷰에서 얘기한 방향 그대로.
- 신규 도메인 관계(id 참조), 프로필 이미지(BinaryContent) 저장·삭제 연계, UserStatus 온라인 판정까지 요구사항을 폭넓게 구현.

정말 잘 따라오고 있어요. 아래는 질문 답변 + 다음 단계 다듬을 점입니다.

---

## 멘토 질문 답변

### Q1. `@Value` 필드 주입은 생성자 후에 되니 생성 시점엔 null → `@PostConstruct`가 필수인가? 생성자 파라미터 `@Value` 주입이 적절한가?

**생성자 파라미터 주입이 정석이고, `@PostConstruct`는 필수가 아닙니다.** 은솔님이 나중에 적용한 `FileStorageUtil` 방식이 옳아요.

지금 두 방식이 코드에 공존하고 있어요:
```java
// FileStorageUtil — 생성자 파라미터 @Value (권장 ✅)
public FileStorageUtil(@Value("${file.path}") String uploadFolder) {
    this.uploadFolder = uploadFolder;   // 생성 시점에 값 확정
}

// FileAbstractRepository — 필드 @Value + @PostConstruct (우회)
@Value("${discodeit.repository.file-directory}")
private String uploadFolder;
@PostConstruct
private void initUploadFolder() { ... }
```
- **필드 주입**은 "객체를 먼저 만들고(생성자 실행) → 그다음 필드에 값을 꽂는" 순서라, **생성자 안에서는 아직 null**입니다. 그래서 초기화가 필요하면 `@PostConstruct`(주입 완료 후 실행)로 미루는 우회가 필요했던 거예요.
- **생성자 주입**으로 바꾸면 "값이 이미 채워진 채로 객체가 태어나므로" 그 문제 자체가 사라집니다. 게다가 필드를 `final`로 둘 수 있어 불변이 보장되고, 테스트할 때 `new FileStorageUtil("경로")`로 값을 직접 넣기도 쉬워요.
- 즉 **"@PostConstruct 필수?" → 아니오.** 필드 주입을 고수할 때만 필요한 우회책이고, 생성자 주입이면 안 써도 됩니다.

**다만** `FileAbstractRepository`는 여전히 필드 `@Value` + `@PostConstruct`라 두 방식이 섞여 일관성이 없어요. 추상 클래스라 생성자 주입이 약간 번거로운데(자식 생성자에서 `super(...)`로 넘겨야 함), 이럴 땐 **경로 설정을 `@ConfigurationProperties` 클래스로 뽑아 주입**하는 방법이 더 깔끔합니다. "폴더가 없으면 생성"하는 부수효과도 레포가 직접 하기보다 별도 초기화 빈으로 두면 책임이 분리돼요.

### Q2. MultipartFile 첨부파일 + 파일 유틸 클래스 분리가 적절한가? 다른 방식은?

**유틸로 분리한 방향은 좋습니다**(파일 저장/삭제라는 단일 책임을 `FileStorageUtil` 하나로, `@Component` 빈으로 관리). UUID prefix로 파일명 충돌을 막은 것도 잘했어요.

- **MultipartFile**은 사실 "HTTP multipart 요청"을 다루는 **웹 계층 타입**이에요. 지금은 아직 콘솔/컨텍스트 테스트 단계라 살짝 앞서간 감이 있지만, 다음 스프린트에서 Web(Controller) 계층을 붙일 거면 자연스럽게 맞물립니다.
- **대안**: 계층 독립적으로 가려면 서비스는 `byte[]`나 `InputStream`을 받게 하고, "MultipartFile → byte[]" 변환은 Controller에서 하는 방식이 있어요. 그러면 서비스가 웹 타입에 안 묶입니다. 실무에선 파일 바이트는 로컬 FS나 오브젝트 스토리지(S3 등)에 저장하고, 메타데이터(파일명/경로)는 DB에 두는데 — 이미 `BinaryContent` 엔티티로 메타를 관리하는 구조라 방향이 맞아요.
- 개선: 유틸의 `System.out.println("이미지 이름: ...")`는 로깅으로. 저장 실패 시 예외 메시지에 파일명/경로를 포함하면 디버깅이 쉬워요.

### Q3. Repository 직접 주입 때문에 존재 검증(예외)이 여러 Service에 중복됨. Service를 재사용하는 게 낫지 않나? 순환참조 방지 위해 Repository 직접이 권장인가?

아주 좋은 질문이고, **직관은 반은 맞습니다** — 중복은 실제 문제예요. 하지만 해법이 "Service 상호 주입"은 아닙니다.

- **왜 Repository 직접 주입이 권장되나**: `UserService`가 `ChannelService`를 주입받고, `ChannelService`도 `UserService`를 주입받는 식이 되면 **순환 참조**가 생겨요(Spring 기동 실패로 이어지기도). Repository끼리는 서로 참조하지 않으니, Service가 필요한 Repository만 직접 보게 하면 이 고리가 안 생깁니다. 그래서 이 단계 요구사항이 Repository 직접 주입인 거예요.
- **그럼 검증 중복은?**: "Service 상호 주입"으로 풀면 순환참조 + 결합도 상승 + 트랜잭션/책임 경계가 흐려지는 더 큰 비용을 치릅니다. 정석 해법은 **검증 로직을 별도로 추출**하는 거예요:
  - 예: `UserValidator`(또는 각 Service의 private 헬퍼)로 "존재 검증"을 모아 재사용. 여러 Service가 이 Validator를 주입받으면, 중복 없이 + 순환참조 없이 해결됩니다.
  - 또는 "정말 그 Service가 다른 도메인 검증을 매번 해야 하는가?"를 되짚어보기 — 도메인 규칙상 필요한 최소한만 남기면 중복 자체가 줄어요.
- **결론**: 지금 단계에선 **Repository 직접 주입이 맞고**, 중복은 "Service 재사용"이 아니라 **Validator/공통 헬퍼 추출**로 완화하는 게 정석입니다. 나중에 규모가 커지면 Facade/도메인 서비스 같은 패턴으로 발전시킬 수 있어요.

---

## 🟡 다음 단계 다듬을 점

1. **예외가 전부 bare `RuntimeException`** — "찾으시는 채널이 존재하지 않습니다" 등이 모두 `RuntimeException`이에요. 지난 시즌부터 이어지는 부분인데, Spring으로 왔으니 이제 **의미 있는 커스텀 예외**(예: `NotFoundException`)로 두면, 나중에 `@ExceptionHandler`/`@ControllerAdvice`로 한곳에서 처리하기 좋아집니다.
2. **`System.out.println` 디버그 다수** (`FileStorageUtil`, `FileAbstractRepository`의 "객체 직렬화 완료" 등) → slf4j 로깅으로. (다른 학생 코드에도 반복되는 포인트예요.)
3. **`FileAbstractRepository.load()`의 `ClassNotFoundException` catch가 원인 `e`를 안 넘김** — `throw new RuntimeException("...", e)`로. (같은 파일 `IOException`은 잘 넘기고 있어 둘을 통일)
4. **N+1 스타일 조회** — `BasicUserService.findAll`이 유저마다 `userStatusRepository.findByUserId` + `binaryContentRepository.findById`를 반복 호출하고, `BasicChannelService.find/findAllByUserId`도 채널마다 message/readStatus를 조회해요. 메모리 저장이라 지금은 괜찮지만, "목록 조회 시 연관 데이터를 건건이 다시 조회"하는 패턴은 DB로 가면 성능 이슈(N+1)로 직결되니 인지해두면 좋아요.

## 🔵 Minor / Nit

- **파일명 오타**: `MessageRespnoseDto`(→`MessageResponseDto`), `BasicStatusUserService`(→`BasicUserStatusService`). 클래스명은 API로 굳어지니 초기에 교정.
- **`findAll`의 `userStatus` orElseThrow**: 유저는 있는데 UserStatus가 없으면 **목록 전체 조회가 예외로 터져요.** 생성 시 UserStatus를 항상 같이 만들고 있으니 지금은 괜찮지만, 데이터 정합성에 강하게 의존하는 구조라 방어적으로 다루면 안전.
- **중복 검증에서 `findAll` 두 번 스트림** (이름/이메일 각각) — 한 번 순회로 합치거나, 레포에 `existsByName`/`existsByEmail` 같은 메서드를 두면 더 깔끔하고 효율적이에요.

---

## 정리

Spring 전환의 핵심(생성자 주입, 조건부 빈, Optional, DTO 변환)을 제대로 소화했고 요구사항 구현 범위도 넓어요. 남은 건 대부분 "실무로 갈 때 다듬을" 성격입니다.

| 우선순위 | 항목 |
|---|---|
| 1 | 커스텀 예외 도입 (bare RuntimeException 정리) |
| 2 | `@Value` 생성자 주입으로 통일 (FileAbstractRepository) |
| 3 | 검증 중복 → Validator/헬퍼 추출 (Q3) |
| 4 | println → 로깅, 예외 원인 e 전달 |
| 5 | N+1 인지, 클래스명 오타, 중복 검증 정리 |

질문 3개는 전부 "설계를 스스로 고민한" 좋은 질문이라, 답을 남겨주면 학습에 큰 도움이 될 거예요.

---

## 추가 질문 답변 (2026-08-16) — exists 별도 함수의 최적화 의미

**학생 질문**: "레포에 별도 함수(exists류)로 변경했는데, Map 자료형에선 최적화 차이가 거의 없어 보여요. 실제 DB에선 쿼리단으로 처리되니 최적화가 좋다는 말씀인가요?"

**답변 요지** (학생 추측이 정확함을 확인 + 한 가지 추가):
1. 맞음 — JCF(Map)에선 어차피 메모리 순회라 성능 차이 거의 없음. 스스로 짚어낸 것 칭찬.
2. DB에선 차이 큼: `findAll().anyMatch()` = 테이블 전체 SELECT 후 앱 메모리에서 검사 (10만 건이면 10만 건 전송) vs `existsByUsername` = `SELECT EXISTS(... WHERE username=?)` 한 방 + 인덱스, boolean만 반환.
3. 성능 외 이유 — **의도를 인터페이스에 드러내면 구현체마다 최적화 가능**: JCF는 순회로, DB는 쿼리로. 서비스 코드는 불변. findAll().anyMatch 방식이면 "전체를 가져온다"는 방식 자체가 서비스에 박혀 이 여지가 없음.
4. Spring Data JPA에선 `boolean existsByUsername(String)` 선언만으로 해당 쿼리 자동 생성 — 지금 구조가 그대로 이식됨.
