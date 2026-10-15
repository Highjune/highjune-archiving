# 코드 리뷰 — [김승호] 스프린트 미션 4 (PR #63, 심화 X)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/63
- **작성자**: WinLike-dev (김승호)
- **범위**: 레이어드 → **바운디드 컨텍스트 + 헥사고날(포트-어댑터) 전면 재편** + 컨트롤러 + 전역 예외 + 도메인 이벤트
- **규모**: +3936 / −1772, 181 files (A98/D52/M31), 11 commits
- **라벨**: 매운맛🔥, 지각제출⏰
- **참고**: 담당 멘티 7명 명단 외 학생

> diff 전체(7411줄) 확인. 핵심 클래스는 head 파일로 라인 검증.

---

## 총평 — 이번 기수 최상위. 실무 시니어급 설계 요소가 다수

**구조**: user/channel/message/content 모듈(바운디드 컨텍스트) × adapter(in/rest, in/event, out/persistence, out/integration) / application(port, service) / domain / api(공개 계약+이벤트). 모듈 간 직접 의존 대신 **InternalApi + ACL 어댑터**, 삭제 전파는 **도메인 이벤트**(UserDeleted→ReadStatus 정리, ChannelDeleted→메시지 정리, ChannelMessageChanged→lastMessageAt 갱신).

**전문가 수준 디테일**:
- `GlobalExceptionHandler`: 404/409/401/400/500 정확 + Bean Validation **필드 단위 에러 목록** + catch-all에서 **Spring `ErrorResponse` 구현 예외(405/415)의 상태를 보존하고 본문만 통일** — 실무자도 대부분 놓치는 부분. `IllegalArgumentException`→500 처리(도메인 검증은 InvalidValueException으로 분리했으므로 남는 IAE는 코드 결함)라는 논리도 정확.
- `RepositoryTypeCondition`: `@ConditionalOnProperty`만으론 설정 오타 시 "빈 없음"으로만 죽는 문제를 지적하고, **커스텀 Condition을 최우선 순위로 걸어 오타를 fail-fast** + 빈 문자열과 누락 구분. 주석의 분석 수준이 매우 높음.
- REST 정석: `/api/users`, `/api/channels/{id}` 자원 중심 + **201 Created + Location 헤더** + 204.
- `BaseEntity`: updatedAt null 불허 불변조건 + 역직렬화 경로 보정, record 방어적 복사(bytes, List.copyOf), env var 설정(`${DISCODEIT_REPOSITORY_TYPE:file}`).
- 미션 요구 "DiscodeitApplication 테스트 로직 삭제" **정확히 이행**. RepositoryParityTest(JCF/File 동등성)·ServiceWorkflowTest 등 테스트 유지보수.
- 주석 전부 "왜/트레이드오프"를 설명.

---

## 🟡 짚을 점

### 1. 미션 제약 — "@RequestMapping만 사용" vs @PostMapping류 사용
강성준(#62)과 동일. 실무 스타일은 우수하나 요구사항 제약 이탈. 인지 여부 확인.

### 2. PUT + "null이면 유지" 의미 충돌 — PATCH가 맞음
`ChannelUpdateRequest`/`UserUpdateRequest`는 "null = 변경하지 않음"(부분 수정) 계약인데 메서드는 `PUT`. PUT은 "전체 교체" 의미라서, 부분 수정 계약과 결합하면 스펙(HTTP 의미론)과 어긋남. 이 학생 수준이면 PATCH와의 차이를 정확히 논할 수 있을 것 — 질문형으로.

### 3. 아키텍처 비용 — 이 규모에 맞는가 (교육적 핵심 논점)
"채널 생성 시 유저 존재 확인" 하나가 `ChannelUserReader`(포트) → `ChannelUserAclAdapter` → `UserInternalApi` → `UserInternalService` 4단 인다이렉션. 규모 대비 클래스 수 폭증(181파일). 구조 자체는 교과서적으로 옳지만:
- 이 프로젝트 규모에서 이 구조의 **비용(탐색성·수정 파급)과 이득**을 스스로 설명할 수 있는지
- 다음 스프린트(JPA·DB) 전환 때 이 추상화가 도움이 되는지 부담이 되는지
→ 정답 요구가 아니라 **트레이드오프를 언어화하게 하는 질문**으로. (배움 목적의 의도적 과잉이라면 훌륭한 선택)

### 4. `Events` static 버스 — DI 우회의 트레이드오프
`Events.raise()`가 static + AtomicReference로 publisher 보관. 실제 raise 호출부가 application 서비스라면 `ApplicationEventPublisher`를 그냥 생성자 주입하는 게 더 단순하고 테스트 격리도 쉬움(전역 상태 없음). static 버스는 "도메인 엔티티 안에서 이벤트를 올리기 위한" 패턴(최범균 DDD의 Events)인데, 지금 구조에서 그 필요가 있는지 질문.

### 5. 이벤트 기반 삭제 전파의 실패 처리 부재
채널 삭제 → 이벤트 → 메시지 모듈이 정리. `@EventListener`는 동기라 지금은 사실상 메서드 호출과 같지만, **핸들러가 실패하면 채널은 이미 지워지고 메시지는 남는 부분 실패** 상태가 됨 (보상/재시도 전략 없음). 트랜잭션 없는 현 단계의 근본 한계지만, "이벤트로 결합을 끊는 대가로 정합성 책임이 생긴다"는 인지 확인.

## 🔵 Minor

- 첨부파일을 JSON base64(`MessageAttachmentCreateRequest.bytes`)로 수신 — multipart/form-data 대비 대용량 비효율(+33% 크기, 메모리). 스펙상 무방하나 인지.
- record 접근자 `bytes()`의 방어적 복사 — 매 호출 복사 비용. 지금 규모 OK, 의도 확인 겸 칭찬.

---

## 확인 질문 제안 (이해도 검증 — 코멘트로)

1. Events를 static으로 둔 이유와, ApplicationEventPublisher 직접 주입 대비 트레이드오프?
2. ACL 어댑터 4단 인다이렉션이 이 규모에서 주는 이득/비용을 어떻게 판단했는지?
3. PUT vs PATCH — "null이면 유지" 계약과 PUT 의미론의 관계?
→ 답을 잘 하면 진짜 이해, 못 하면 참고 자료 기반 적용일 가능성. 어느 쪽이든 학습 기회.

---

## 복붙용 코멘트 위치 (head 검증 완료)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| @RequestMapping 제약 + 칭찬(201/Location) | `channel/adapter/in/rest/channel/ChannelController.java:39` | `@PostMapping("/public")` |
| PUT vs PATCH | `ChannelController.java:69` | `@PutMapping("/{id}")` |
| 부분수정 계약 | `channel/.../dto/request/ChannelUpdateRequest.java:13` | record 선언 |
| 칭찬: ErrorResponse 상태 보존 | `common/adapter/in/rest/GlobalExceptionHandler.java:141` | `if (e instanceof ErrorResponse...)` |
| 칭찬: IAE→500 논리 | `GlobalExceptionHandler.java:124` | `@ExceptionHandler(IllegalArgumentException.class)` |
| Events static 논점 | `common/event/Events.java:14` | `public final class Events` |
| 칭찬: fail-fast Condition | `config/RepositoryTypeCondition.java:28` | 클래스 선언 |
| 아키텍처 비용 질문 | `channel/adapter/out/integration/user/ChannelUserAclAdapter.java:16` | 클래스 선언 |
| 이벤트 실패 처리 | `message/adapter/in/event/ChannelDeletedEventHandler.java:20` | `@EventListener` |
| base64 첨부 | `message/.../dto/request/MessageAttachmentCreateRequest.java:23` | `byte[] bytes` |
