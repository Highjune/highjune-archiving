# 코드 리뷰 — [김민재] 스프린트 미션3 (PR #35)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/35
- **작성자**: mjdevkim (김민재)
- **범위**: Spring Boot 전환 + 신규 도메인 + DTO + **Application/Domain 서비스 2계층 분리 + 보상 롤백** + CustomException/ExceptionType
- **규모**: +4299 / -1306, 96 files
- **라벨**: 매운맛🔥

> 확인한 핵심 파일: `UserApplicationServiceImpl`, `UserDomainServiceImpl`, 파일 목록 전반. 나머지는 목록으로 파악.

---

## 총평 — 이번 시즌 제출 중 설계 수준 최상위권 👏

- **Application / Domain 서비스 2계층 분리**: `UserApplicationService`(유스케이스 조합 + 순서 결정 + 보상)와 `UserDomainService`(단일 도메인 CRUD + 검증)를 나눈 건 실무의 **Facade / Application Service + Domain Service** 구조와 정확히 일치해요. 이 단계 학생이 스스로 여기까지 도달한 건 드뭅니다.
- **수동 보상 롤백**: `create`/`update`/`delete`에서 중간 단계 실패 시 이미 만든 것들을 역순으로 되돌리고, 롤백 중 난 예외는 `originalException.addSuppressed(...)`로 원 예외에 첨부 — **수동 트랜잭션/Saga 패턴의 축소판**을 정확히 구현했어요. `addSuppressed`까지 쓴 건 인상적.
- **Domain Service의 검증 일원화**: `existsByUsername`/`existsByEmail`로 중복 검증(전체 로드 anyMatch 대신 레포 위임), `findById`의 `orElseThrow`로 조회 실패 처리, `CustomException`+`ExceptionType`로 예외 체계화.
- **`ServiceFactory` 제거 → Spring DI 전환**, Repository `Optional` 반환. 지난 시즌 지적(dead code, 싱글턴 vs DI)이 프레임워크 힘으로 자연스럽게 정리됐어요.

멘토 질문 3개도 전부 "설계를 깊이 고민한" 좋은 질문이라, 답변부터 정리합니다.

---

## 멘토 질문 답변

### Q1. Application Service가 로깅·예외처리·보상까지 담당해 메서드가 길어짐. 괜찮은가? 책임 분리 기준? 현업은?

**메서드가 길어진 진짜 원인은 "DB 트랜잭션이 없어서 롤백을 손으로 하기 때문"이에요.** 민재님도 이미 정확히 짚었죠("Transaction 쓰면 해결"). 즉 지금 길이는 설계가 나빠서가 아니라, **트랜잭션이라는 인프라가 없어서 그 일을 애플리케이션이 대신 떠안은** 정당한 결과예요.

현업 기준으로 정리하면:
- **Application Service가 "여러 도메인을 조합해 유스케이스를 완성 + 트랜잭션 경계 설정"을 맡는 것 자체는 정석**이에요. 지금 구조 방향이 맞습니다.
- 다만 **로깅·예외처리·보상 코드를 성공 흐름과 한 메서드에 섞으면** 핵심(성공 경로)이 묻혀서 설명이 어려워지는 게 맞아요. 이건 다음처럼 나눠요:
  1. **트랜잭션은 프레임워크에 위임** — DB 붙는 다음 스프린트에서 `@Transactional` 하나로 지금의 수동 보상 코드(try-catch + addSuppressed)가 **통째로 사라집니다.** 지금 보상 코드는 "그때까지의 임시방편"으로 이해하면 돼요. (그래서 지금 이걸 더 정교하게 다듬는 데 시간을 많이 쓸 필요는 없어요.)
  2. **성공 경로와 실패(보상) 경로를 메서드로 분리** — 지금 당장 가독성만 올리려면, `create()`엔 순서(성공 흐름)만 남기고 롤백을 `private void rollbackCreate(...)`로 빼면 "핵심 로직만" 남아 설명이 훨씬 쉬워져요.
  3. **로깅은 관심사 분리(AOP 등)로** 뺄 수 있지만 지금 단계엔 과함 — "이런 방법이 있다" 정도만 인지.
  4. **예외 변환/응답 처리는 상위 한 곳**(다음 스프린트 `@ControllerAdvice`)에서.
- **결론**: 길어진 건 정당한 이유(트랜잭션 부재)예요. 지금은 **성공/실패 경로 메서드 분리로 가독성만 개선**하고, 트랜잭션·로깅은 다음 단계에 프레임워크로 위임하세요. 억지로 지금 다 분리하려 하지 않아도 됩니다.

### Q2. 예외를 어느 계층에서 발생/catch? 하나의 ExceptionType에 몰아넣기 vs 분리?

민재님이 정리한 **계층별 throw 분담(DTO=입력검증 / AppService=유스케이스 실패 / DomainService=ID·조회·중복 / FileRepo=직렬화)은 이미 정석에 매우 가까워요.** 짚어드릴 건:

- **발생 위치**: "그 규칙을 아는 계층"이 던진다 → 지금 분담이 맞아요. Domain Service가 존재/중복을 던지는 것도 적절.
- **catch 위치**: **계층마다 잡지 말고, 가장 바깥 한 곳에서 일괄 처리**가 정석이에요. 그래서 지금 대부분 `throw`만 하는 게 **잘하고 있는 것**입니다. 다음 스프린트에서 웹 계층이 생기면 `@ControllerAdvice`/`@ExceptionHandler`가 그 "한 곳"이 돼요. 중간 계층은 **"보상 작업이 필요할 때만" catch** — 지금 Application Service의 롤백 catch가 바로 그 정당한 예외고요.
- **ExceptionType 하나에 몰아넣기 vs 분리**:
  - 지금처럼 enum 하나로 관리하는 건 **소규모에선 오히려 한눈에 보여 편해요.** 지금 규모엔 그대로 둬도 됩니다.
  - 나중에 나눈다면 축을 **"발생 계층(App/Domain)"이 아니라 "예외의 성격/처리 방식"**으로 잡는 게 좋아요. 처리하는 쪽은 "어느 계층에서 났나"보다 **"어떻게 응답할까"**가 궁금하거든요. 특히 HTTP로 가면 자연스럽게: 조회 실패→404, 중복/잘못된 값→400·409, 서버오류→500.
  - 실무에서 흔한 절충안: `NotFoundException`, `DuplicateException`, `ValidationException` 같은 **상위 타입 몇 개**로 묶고, `ExceptionType` enum은 그 안의 상세 코드/메시지로 두는 **하이브리드**. (지금은 여기까진 필요 없고, "나중에 나눌 땐 성격 기준" 정도만 기억)
- **결론**: 계층별 throw 분담 유지(잘함), catch는 바깥 한 곳(지금 throw-only가 맞음 → 다음 스프린트 `@ControllerAdvice`), ExceptionType은 지금 하나로 OK. 분리한다면 계층이 아니라 성격(→HTTP 상태) 기준으로.

### Q3. application.yaml 학습 리소스?

- **Spring Boot 공식 문서** — "Core Features → Externalized Configuration" 섹션이 가장 정확하고 최신이에요. (yaml/properties, profile, 우선순위)
- 꼭 잡을 개념 4가지: **`@Value`**(단일 값), **`@ConfigurationProperties`**(관련 설정 묶음, 실무 표준), **profile**(`application-dev.yaml` / `application-prod.yaml` 분리), **relaxed binding**(yaml의 `file-directory`가 필드 `fileDirectory`로 자동 매핑).
- 실전 예시로는, 같은 스터디의 이은솔님 PR(#32)에서 `@ConfigurationProperties`로 경로 설정을 빈으로 뽑은 방식이 좋은 참고가 돼요. `@Value` 여러 개보다 `@ConfigurationProperties` 한 클래스로 묶는 게 관리가 편합니다.

---

## 🟡 몇 가지 짚을 점

1. **`findAll`의 `USER_STATUS_NOT_FOUND` throw** — `UserApplicationServiceImpl.findAll`에서 유저는 있는데 UserStatus 매핑이 없으면 `throw` → **목록 전체가 실패**해요. 지금은 `create`에서 항상 UserStatus를 같이 만들어 정합성이 보장되니 괜찮지만, 목록 조회는 개별 데이터 하나 때문에 전체가 무너지지 않게 방어적으로(기본값 OFFLINE 등) 두면 더 안전해요. (같은 스터디 은솔님 PR에도 있었던 포인트)
2. **수동 보상 롤백의 한계** — 롤백 자체가 실패하면 `addSuppressed`로 "기록"만 되고 데이터는 부분 성공 상태로 남을 수 있어요. 이건 손으로 하는 롤백의 근본 한계라 민재님 잘못이 아니고, **DB `@Transactional`로 넘어가면 원자성(all-or-nothing)이 보장되며 이 코드가 사라집니다.** "지금은 최선의 임시방편"으로 이해하면 돼요.

## 🔵 Minor / Nit

- **`@Qualifier("userService")`가 `UserDomainServiceImpl`에 붙어 있음** — 같은 인터페이스 구현체가 여럿일 때 구분하려는 용도인데, 지금 Domain 서비스는 구현체가 하나라 불필요해 보여요. 의도가 없으면 제거 권장(확인 필요).
- **`update`에서 `User.create(...)`를 "수정값 그릇"으로 재사용** — 새 `User`(새 id/시간 생성)를 만들어 값 전달용으로만 쓰는 게 살짝 어색해요. 업데이트 전용 DTO/메서드로 값을 넘기면 의도가 더 명확합니다.

---

## 정리

Application/Domain 분리, 보상 롤백, 예외 체계, DI 전환까지 이 단계에서 보기 드문 완성도예요. 남은 건 대부분 "다음 스프린트(DB/트랜잭션·웹 계층)에서 자연스럽게 정리될" 것들입니다.

| 우선순위 | 항목 |
|---|---|
| 1 | (Q1) 성공/보상 경로 메서드 분리로 가독성 개선 — 트랜잭션은 다음 단계 위임 |
| 2 | (Q2) throw-only 유지 + 다음 스프린트 @ControllerAdvice, ExceptionType은 지금 하나로 OK |
| 3 | findAll의 status 없음 → 목록 전체 실패 방어 |
| 4 | @Qualifier 불필요 여부 확인, update 값 전달 방식 |

질문 3개가 전부 "정답이 하나가 아닌" 설계 질문이라, 위 기준으로 답을 남겨주면 학습에 크게 도움이 될 거예요.

---

## 추가 질문 답변 (2026-08-16) — update 재설계: copy + Entity 전달

**학생 질문**: "App→Domain 간엔 DTO보다 Entity가 일관성 있어 보여서, ① App에서 id로 User 조회 → ② copy 생성(rollback용) 후 copy에 .update → ③ DomainService.update(copy) 방식으로 재설계. 괜찮은가?"

**새 코드 확인 결과**:
- `User.copy()`는 id/createdAt을 보존하는 진짜 복사본 (이전 지적이던 "User.create 값 전달용 재사용 → 새 id/시간 버려짐" 문제 해결됨)
- `update()`: `originalUserState = user.copy()`(롤백 스냅샷) + `updatingUser = user.copy()`(작업용) 분리, copy에만 `updateAccountDetails` 적용 후 `userDomainService.update(updatingUser)` (replace 방식, 내부에서 재조회 + 변경된 필드만 unique 검증)
- 롤백은 `userDomainService.update(originalUserState)`로 복원

**답변 요지** (승인):
1. 방향 좋음 — 원 지적사항이 copy()로 정확히 해결됨.
2. **원본을 직접 수정하지 않은 게 핵심 방어**: JCF 레포는 맵 안의 객체를 참조 그대로 반환하므로, 원본에 직접 update했다면 save 실패 시에도 메모리 원본이 이미 오염됨. copy가 이를 막고 롤백 스냅샷도 자연스럽게 확보.
3. App→Domain에 Entity 전달은 자연스러움 — DTO는 바깥 경계(컨트롤러↔App)용, Domain Service는 도메인 객체를 다루는 계층.
4. 트레이드오프 인지: ① replace 방식이라 Domain은 "무엇이 왜 바뀌었는지" 모름(호출자가 완전한 객체를 넘겨야 하는 계약) — JPA 가면 dirty checking으로 다시 바뀔 부분. ② 조회 2회(App findById + Domain update 내부 재조회) — 지금 규모에선 무시 가능.
