# 코드 리뷰 — [김승호] 스프린트 미션5 커밋 (PR #63 후속)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/63 (제목은 미션4 — 미션5 커밋이 같은 PR에 추가됨)
- **작성자**: WinLike-dev (김승호), head `sprint-02-discodeit` → base `김승호` ✅
- **리뷰 범위**: 8/21 커밋 8개 (a4be164 ~ dea01f7) — springdoc, 스펙 정합, multipart, 시각 정책 전환, 파일 잠금, 배포 준비
- **라벨**: 매운맛🔥 + 지각제출⏰
- **참고**: 9~13기 인사이트 반영 (`reference/sprint5-past-cohort-review-insights.md`)

> 범위 diff(소스 2570줄 + docs) 전체 확인, 라인은 dea01f7 raw 검증 완료.

---

## 총평 — 기수 통틀어 가장 검증이 깊은 미션5. 지적할 것은 "버그"가 아니라 "설계 비대칭"뿐

- **oasdiff 리포트를 직접 커밋** (`docs/openapi/oasdiff-report.txt`) — 스펙 준수를 주장이 아니라 도구 실행 결과로 증명. 미션 안내의 도구를 실제로 돌린 유일 사례
- **newman으로 Postman 컬렉션 자동 실행** 결과 커밋 (`docs/postman/newman-run-output.txt`)
- **시각 정책 전환(서버시각→클라이언트 입력) 시 테스트를 삭제하지 않고 의도를 다시 서술** — ReadStatusTest/UserStatusTest를 새 의도("읽은 시각은 클라이언트가 정한다")로 다시 씀 + null 방어 테스트 추가. 김예준 사례(테스트 통삭제→버그 유입)와 정반대 모범
- **FileLockProvider + inEntityLock 템플릿 메서드** — 파일 저장소 동시성 제어. "DB 전환 시 트랜잭션이 대체, 이 클래스도 사라진다"는 소멸 조건까지 주석에 명시. CyclicBarrier 16스레드 동시성 테스트(`FileRepositoryConcurrencyTest`) 동반
- **스펙 정합 정확**: PATCH 전환, newUsername/newContent/newLastReadAt 필드명, part 이름(userCreateRequest 등), kebab→camelCase URL 전환(스펙 우선 판단), 201+Location 유지, 204, `/api/users/{userId}/userStatus` 서브리소스화
- **CreateMessageCommand/MessageAttachmentCommand** — REST DTO를 애플리케이션에 내리지 않는 유스케이스 입력 분리 (11기 멘토 반복 지적을 선제 적용)
- 로그인 실패 시 username 존재/password 오류 비구분 (user enumeration 방지 인식, AuthController:26-27 주석)
- Dockerfile 멀티스테이지+레이어 캐싱, PORT 환경변수, multipart 사이즈 설정 — 전부 "왜"가 주석에
- GlobalExceptionHandler 커버리지 최상급 (MethodArgumentNotValid/TypeMismatch/MissingParam/NotReadable 등 12종)

## 🟡 설계 지적 (매운맛)

### 1. Swagger 어노테이션이 컨트롤러 본문을 삼킴 → `XxxApi` 인터페이스 분리 — `UserController.java:48` (@Tag, 대표)
UserController가 +125줄 — 대부분 @ApiResponses. 9~13기 5개 기수 멘토 공통 칭찬 패턴: 문서 어노테이션을 `adapter/in/rest/.../api/UserApi` 인터페이스에 두고 컨트롤러가 구현. springdoc이 인터페이스 어노테이션을 상속해 읽음. 이 학생의 헥사고날 구조(인바운드 포트/어댑터 분리 사상)와 자연스럽게 맞음. 단 11기 멘토 1명은 "문서는 구현체에" 반대 — 컨벤션 선택지로 소개.

### 2. Channel만 애플리케이션이 REST DTO 의존 — `ChannelControllerService.java:3,30`
CreateMessageCommand 주석에 "REST 요청 DTO를 그대로 쓰지 않는다"고 원칙을 썼고 User도 CreateUserCommand로 분리했는데, **Channel은 application 인터페이스가 `PublicChannelUpdateRequest`(adapter.in.rest DTO)를 그대로 받음** (반환도 rest의 ChannelDto). 헥사고날 의존 방향(adapter→application)이 Channel에서만 역전. Message에서 세운 원칙을 Channel에도 — ChannelCommand 분리.

### 3. `readAll()`은 잠금 밖 — 본인이 쓴 Windows 시나리오가 남아 있음 — `AbstractFileRepository.java:104`
inEntityLock(:58) 주석의 근거 둘째("Windows는 열린 파일을 덮어쓰지 못한다 — 읽는 중 이동이 AccessDeniedException")가 **findAll 경로에는 그대로 적용됨**: readAll이 잠금 없이 디렉터리를 순회하며 파일을 여는 동안 다른 스레드의 ATOMIC_MOVE가 실패 가능. FileRepositoryConcurrencyTest도 findAll-동시-쓰기 조합은 미검증. 질문 형태로: 의도된 트레이드오프인지(전역 잠금 비용 회피), 아니면 남은 구멍인지.

### 4. multipart IOException → `UncheckedIOException` → 500 — `MessageController.java:164`, `UserController.java:192`
GlobalExceptionHandler에 UncheckedIOException 전용 핸들러가 없어 Exception.class(:139) → 500. 클라이언트가 업로드를 중단한 경우도 이 경로로 옴 — 정성껏 만든 12종 핸들러 체계에서 유일하게 새는 곳. 400(클라이언트 전송 문제)/500 구분 의도 확인 + 커스텀 예외(과거 기수 반복 제안) 고려.

## 🔵 Minor / 질문

- **응답 네이밍 `-Dto` vs `-Response`** — `channel/adapter/in/rest/channel/dto/response/ChannelDto.java` 요청은 `-Request`인데 응답은 `-Dto`로 비대칭. Request/Response 쌍이 방향을 드러내는 일반 컨벤션 (9기 멘토 반복 지적)이고, #2의 Command/Result 분리와 묶으면 "adapter=Request/Response, application=Command/Result"로 계층별 어휘가 생김. **단서**: 제공 스펙 문서의 응답 스키마 이름이 ChannelDto 등 `-Dto`라서, 스펙 문서와 Swagger 스키마 이름을 맞춘 의도적 선택일 수 있음 → 질문형으로.
- **ReadStatusControllerService 잔여 메서드** — `ReadStatusControllerService.java:19,28` find(userId,channelId)/delete(userId,channelId)는 스펙 정리로 컨트롤러에서 사라졌는데 인터페이스에 남음 (find는 테스트가 사용). delete는 사용처가 있는지 — 없으면 정리.
- **FileLockProvider 잠금 맵 무한 성장** — `FileLockProvider.java:20` 삭제된 엔티티의 락도 맵에 잔존. 본인 주석대로 임시 장치니 인지만 (실무면 Caffeine/WeakRef 또는 삭제 시 정리).
- **newman-run-report.json 14,426줄 커밋** — 생성 리포트는 .gitignore 대상 (과거 기수 반복 지적: 생성 파일 커밋 금지). output.txt 요약이면 충분.
- **프로세스**: 미션5 작업이 미션4 PR에 이어짐 — 제목 갱신 or 미션5는 별도 PR 분리가 리뷰 단위에 좋음.

## 복붙용 코멘트 위치 (dea01f7 검증 완료)

| 항목 | 파일:라인 | 앵커 |
|---|---|---|
| Swagger Api 분리 | `user/adapter/in/rest/user/UserController.java:48` | `@Tag(name = "User"` |
| Channel REST DTO 의존 | `channel/application/channel/ChannelControllerService.java:30` | `update(UUID id, PublicChannelUpdateRequest` |
| readAll 잠금 밖 | `common/repository/file/AbstractFileRepository.java:104` | `protected final List<T> readAll()` |
| UncheckedIOException 500 | `message/adapter/in/rest/message/MessageController.java:164` | `throw new UncheckedIOException` |
| 잔여 메서드 | `channel/application/readstatus/ReadStatusControllerService.java:28` | `void delete(UUID userId, UUID channelId)` |
| 락 맵 성장 | `common/repository/file/FileLockProvider.java:20` | `private final Map<Path, ReentrantLock> locks` |
| 칭찬: oasdiff | `docs/openapi/oasdiff-report.txt` | (파일 자체) |
| 칭찬: 테스트 재서술 | `channel/domain/readstatus/ReadStatusTest.java:14` | `creationAndUpdateKeepGivenTime` |
| 칭찬: 동시성 테스트 | `integration/FileRepositoryConcurrencyTest.java:39` | `concurrentReadAndWriteOnSameEntityStaysConsistent` |
| 칭찬: 로그인 비구분 | `user/adapter/in/rest/auth/AuthController.java:26` | `// 존재하지 않는 username과` |
