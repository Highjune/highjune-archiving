# 코드 리뷰 — [김양현] 스프린트 미션 4 (PR #61)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/61
- **작성자**: yyy2724 (김양현)
- **범위**: sprint2 잔재 대청소 + Spring Boot 전환 + 도메인 패키지 재편(auth/binaryContent/readStatus/common) + 전역 예외 처리 + 컨트롤러 + 서비스 테스트 + 정적 관리 화면 + Postman 컬렉션
- **규모**: +3742 / −2794, 169 files, 4 commits
- **라벨**: 매운맛🔥
- **참고**: 담당 멘티 7명 명단 외 학생. "늦어서 죄송합니다. 전체적인 흐름 확인 부탁" — sprint3+4 내용이 한 PR에 합쳐진 형태

> diff 전체(7499줄) 확인 완료. head 브랜치 트리 직접 확인으로 패키지 누락 검증함.

---

## 총평

커밋 위생 대청소(.gradle/.idea/build 삭제 + .gitignore 신설), 예외 체계(ErrorCode enum + 계층 예외 + catch-all 핸들러), @ConditionalOnProperty 스위칭, 엔티티별 개별 .ser 파일 저장, 서비스 테스트 7개 작성까지 — **방향과 구조 감각이 좋은 제출물**. 다만 아래 🔴 1번 하나 때문에 **브랜치가 컴파일 자체가 안 되는 상태**라, 리뷰보다 먼저 복구가 필요함.

---

## 🔴 Critical — user/userStatus/channel/message 도메인이 통째로 누락 (컴파일 불가)

**증상**: head 브랜치의 `discodeit/` 패키지에 `auth`, `binaryContent`, `common`, `readStatus`만 존재. 그런데:
- `BasicAuthService`가 `user.domain.User`, `user.repository.UserRepository` import
- `BasicReadStatusService`가 `user.repository.UserRepository`, `channel.repository.ChannelRepository` import
- 테스트들이 `user.application.UserService`, `user.repository.jcf.JCFUserRepository`, `user.repository.jcf.JCFUserStatusRepository` 등 import
- 미션 4 필수 "7개 도메인 컨트롤러" 중 Auth/BinaryContent/ReadStatus **3개만 커밋됨**

→ 존재하지 않는 클래스를 import하므로 `./gradlew build` 전체 실패.

**원인 (범인 찾음)**: 새로 만든 `.gitignore`의 마지막 3줄
```
user/
channel/
message/
```
경로 지정 없는 `user/` 패턴은 **저장소 안 모든 위치의 user 디렉터리**에 매칭됨. 아마 `.discodeit/user/` 같은 **직렬화 데이터 폴더**를 제외하려던 의도였겠지만, 그 바람에 `src/main/java/.../discodeit/user/`(userStatus 포함), `channel/`, `message/` **소스 패키지가 git에서 통째로 무시**되어 로컬에만 존재하고 커밋이 안 된 것.

**해결**:
1. `.gitignore`에서 `user/`, `channel/`, `message/` 3줄 삭제
2. 데이터 폴더 제외가 목적이면 `.discodeit/` 한 줄로 대체 (지금은 `*.ser`만 있고 폴더 지정이 없음)
3. `git add src/main/java` 후 상태 확인 → 누락 패키지가 잡히는지 보고 커밋·push
4. push 후 `./gradlew build` 재확인

---

## 🟡 Major

### 2. `ReadStatusResponseDto`에 id가 없음 → API 사용 흐름이 끊김
응답이 `(channelId, userId)`뿐이라 **create 응답을 받은 클라이언트가 그 ReadStatus의 id를 알 수 없음** → `PATCH /api/readStatus/{id}`를 호출할 방법이 없음. 응답 DTO에 id(+lastReadTime) 포함 필요.

### 3. `BasicReadStatusService.create`가 저장된 엔티티가 아닌 request 값으로 응답 조립
`ReadStatusResponseDto.from(request.channelId(), request.userId())` — 저장 결과(id, 생성시각)가 응답에 반영 안 됨. 2번과 같은 뿌리. `from(readStatus)` 형태로 엔티티에서 변환하는 게 정석.

### 4. `ReadStatusController`의 GET `/{userId}` — PATCH `/{id}`와 경로 패턴 충돌
같은 `/api/readStatus/{...}` 자리에 한쪽은 readStatus id, 한쪽은 userId가 들어가 의미가 모호함 (메서드가 달라 동작은 하지만 읽는 사람이 혼동). "특정 사용자의 읽음 목록"은 `GET /api/users/{userId}/read-statuses` 형태가 명확.

### 5. `BinaryContentController` — 메서드명 create인데 실제는 GET 조회 + 단건 조회 엔드포인트 없음
```java
@GetMapping
public List<BinaryContentResponseDto> create(@RequestParam List<UUID> ids)
```
이름과 동작 불일치(조회인데 create). 그리고 미션 요구는 "단건·전체(여러 건) 조회"인데 단건 `GET /{id}`가 없음.

### 6. File 레포들의 예외 삼킴 (`e.printStackTrace()` 후 진행)
- `FileReadStatusRepository.save` — 저장 실패해도 printStackTrace만 하고 정상 리턴 → **데이터 유실이 조용히 지나감**
- `FileBinaryContentRepository.findById` — IOException을 삼키고 `Optional.empty()` → "없음"과 "읽기 실패"가 구분 안 됨
- `FileBinaryContentRepository.findAll` — `directory.toFile().listFiles(...)`는 **null 반환 가능** → for문에서 NPE 위험
직접 만든 예외 체계(DiscodeitException)가 있으니 저장/읽기 실패도 그쪽으로 던지는 게 일관됨.

### 7. `ErrorCode.code`가 "409" 같은 상태코드 문자열 — 분기용 코드로 부적합
`DUPLICATE_USERNAME(HttpStatus.CONFLICT, "409", ...)` — code가 HTTP 상태와 중복. 클라이언트가 "같은 409라도 이름 중복 vs 이메일 중복"을 구분하려면 code에 `name()`(DUPLICATE_USERNAME)을 쓰는 게 정석. (김예준 #58과 동일 포인트)

### 8. validation starter를 넣고도 `@Valid`/제약 어노테이션 미사용
`spring-boot-starter-validation` 의존성은 추가됐는데 DTO에 `@NotNull` 등 제약도, 컨트롤러에 `@Valid`도 없음. 붙이게 되면 `MethodArgumentNotValidException` 전용 400 핸들러도 필요 (지금은 catch-all이 500으로 삼킴 — 입력 오류는 400이어야 함).

### 9. 커스텀 `NoSuchElementException` — `java.util.NoSuchElementException`과 이름 충돌
같은 이름의 표준 예외가 있어 import 한 줄 차이로 다른 클래스가 잡힘. 실수 유발 지대라 `ResourceNotFoundException` 등으로 개명 권장.

---

## 🔵 Minor / Nit

- `DiscodeitApplication` — 템플릿 주석 코드 잔재 (셋업/TODO 블록). 삭제.
- `BaseEntity` 필드가 final 아님 + `updateUpdatedAt(Instant)`으로 외부에서 시각 주입 가능 — id/createdAt은 final로, 갱신은 내부 `Instant.now()`로.
- `BasicService<T>` 인터페이스 — 메서드가 delete뿐이고 타입파라미터 T를 안 씀. dead abstraction, 삭제해도 무방.
- `ReadStatusUpdateRequestDto` — 만들어놓고 안 씀 (update가 body 없이 서버 시간 사용 — **서버 시간 사용 자체는 좋은 판단**). dead code 정리.
- 루트에 `Spring 핵심 개념 이해하기.md`(학습 노트), `스프린트 미션 4.postman_collection.json`(한글 파일명) — docs/ 폴더로 정리 권장. Postman 컬렉션 첨부 자체는 👍.
- `application.yaml` — `type: file   # jcf | file\` 주석 끝 `\` 오타(무해), 파일 끝 개행 없음.
- `.gitignore`에 `.claude` 포함 — 의도적이면 OK.

---

## 잘한 점 (코멘트로 남겨줄 것)

- **커밋 위생 대청소**: .gradle/.idea/build 아티팩트 전부 삭제 + .gitignore 신설 — 방향 아주 좋음 (패턴 실수만 복구하면 됨)
- **예외 체계**: 추상 `DiscodeitException` + `ErrorCode` enum(status+message) + `GlobalExceptionController`에 **catch-all Exception 500 + IllegalArgumentException 400까지** — 커버리지 설계가 좋음
- **`@ConditionalOnProperty` jcf/file 스위칭 + `@Value` 생성자 주입** — 정석
- **`FileBinaryContentRepository`가 엔티티별 개별 .ser 파일 저장** — 맵 통짜 직렬화보다 발전된 형태 (부분 읽기/삭제 가능)
- **서비스 테스트 7개 작성** — 이 단계에서 스스로 테스트를 쓴 학생은 드묾
- **readStatus.update가 클라이언트 시간이 아닌 서버 시간 사용**

---

## 정리 (우선순위)

| 순위 | 항목 | 위치 |
|---|---|---|
| 1 | 🔴 .gitignore `user/`,`channel/`,`message/` 3줄 삭제 → 누락 패키지 커밋 (빌드 복구) | `.gitignore:46-48` |
| 2 | ReadStatus 응답에 id 포함 + 엔티티 기반 응답 조립 | ReadStatusResponseDto, BasicReadStatusService.create |
| 3 | File 레포 예외 삼킴 정리 (printStackTrace → 예외 체계로) | FileReadStatus/FileBinaryContent |
| 4 | BinaryContent 단건 조회 추가 + 메서드명 정정 | BinaryContentController |
| 5 | ErrorCode.code → name 기반, GET /{userId} 경로 재설계 | ErrorCode, ReadStatusController |
| 6 | @Valid 적용 + MethodArgumentNotValidException 400 핸들러 | DTO/컨트롤러/GlobalExceptionController |
| 7 | NoSuchElementException 개명, dead code 정리 | common/exception 등 |

---

## 코멘트 위치 가이드 (모두 새 파일이라 diff 라인 = 파일 라인)

| 항목 | 파일:라인 | 앵커 코드 |
|---|---|---|
| 🔴 gitignore 소스 패키지 무시 | `.gitignore:46-48` | `user/` `channel/` `message/` |
| 누락 증거 (import) | `auth/application/basic/BasicAuthService.java:5` | `import ...user.domain.User;` |
| ReadStatus 응답 id 없음 | `readStatus/dto/ReadStatusResponseDto.java:5` | `public record ReadStatusResponseDto(` |
| create가 request로 응답 조립 | `readStatus/application/basic/BasicReadStatusService.java:48` | `return ReadStatusResponseDto.from(request.channelId(), ...)` |
| GET /{userId} 경로 | `readStatus/controller/ReadStatusController.java:30` | `@GetMapping(value = "/{userId}")` |
| BinaryContent 메서드명/단건 없음 | `binaryContent/controller/BinaryContentController.java:22-23` | `@GetMapping public List<...> create(...)` |
| save 예외 삼킴 | `readStatus/repository/file/FileReadStatusRepository.java` save의 `e.printStackTrace()` | catch (IOException e) |
| findAll NPE 위험 | `binaryContent/repository/file/FileBinaryContentRepository.java` findAll의 `listFiles` | `File[] files = directory.toFile().listFiles(...)` |
| ErrorCode.code | `common/exception/ErrorCode.java:11-20` | `DUPLICATE_USERNAME(HttpStatus.CONFLICT, "409", ...)` |
| catch-all 칭찬 + @Valid 보완 | `common/exception/GlobalExceptionController.java:29` | `@ExceptionHandler(Exception.class)` |
| NoSuchElementException 이름 | `common/exception/NoSuchElementException.java:3` | 클래스 선언부 |
| BasicService dead abstraction | `common/application/BasicService.java:5` | `public interface BasicService<T>` |
| 주석 잔재 | `DiscodeitApplication.java:10-23, 27-40` | 주석 블록 |

---

## 복붙용 코멘트 문안 라인 검증 완료 (2026-08-17, head 실제 파일 기준)

- `.gitignore:46-48` — 메인 복구 코멘트 (user/, channel/, message/)
- `BasicAuthService.java:5` — 누락 증거 import
- `ReadStatusResponseDto.java:5` — id 없음
- `BasicReadStatusService.java:48` — request로 응답 조립
- `ReadStatusController.java:30` — GET /{userId} 경로
- `BinaryContentController.java:23` — create 이름 + 단건 없음
- `FileReadStatusRepository.java:42` — save 예외 삼킴 (58, 93, 131 동일)
- `FileBinaryContentRepository.java:58` — listFiles null NPE (+개별 .ser 칭찬)
- `ErrorCode.java:11` — code "409" 문자열
- `GlobalExceptionController.java:29` — catch-all 칭찬 + @Valid 400 핸들러 보완
- `NoSuchElementException.java:3` — 이름 충돌
- `BasicService.java:5` — dead abstraction
- `DiscodeitApplication.java:10` — 주석 잔재

채팅에 각 위치별 복붙용 문안 전문 있음 (2026-08-17 세션).
