# 코드 리뷰 — [신상엽] sprint8 (PR #113)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/113 (#112 닫고 재오픈)
- **작성자**: Smil-limS (신상엽), head `Smil-limS:mission_8` → base `신상엽` ✅
- **규모**: +7,955 / −2,477, **123 files** (sprint8 범위는 ~15파일)
- **라벨**: 미완성🛠️ — 체크: Dockerfile·compose·S3 구현 / 미체크: RDS·ECR·ECS·심화 2개. PR 본문 템플릿 그대로(주요 변경사항·스크린샷·멘토에게 전부 빈칸). **head 브랜치가 컴파일되지 않음(실측)**
- **참고**: `reference/sprint8-past-cohort-review-insights.md`, sprint7 세션(상엽님 패턴: "외부 코드 병합에서 버그 들여옴, 본인이 잘 짰던 부분 후퇴")

> 커밋 5개: `5027ab1 미션 8 베이스 코드 적용 및 초기화` → 컨테이너화 → S3 → `adfd70f 미션 8 베이스 코드로 덮어쓰기` → `fae0de4 upstream 신상엽 브랜치 병합`. **sprint3 시절 베이스 코드(repository/file·jcf, dto/ 평면 패키지, SprintMission3ApplicationTests, HELP.md)가 덮어써져 들어옴.** sprint7과 동일 패턴 재발.

---

## 총평 — 배포 미션의 핵심(Dockerfile·compose·S3 구현)은 작성했지만 ①head가 컴파일되지 않아 이미지 빌드 자체가 불가능하고(체크리스트 "이미지 빌드 및 실행 테스트"는 실제론 미달성) ②요청 DTO를 통째로 로그에 찍어 비밀번호가 평문으로 남으며 ③RDS/ECR/ECS 미수행. 복구 로드맵: 베이스 코드 잔재 제거 → 컴파일 → 로그 민감정보 → 배포

**칭찬 포인트:**
- compose `pg_isready` healthcheck + `condition: service_healthy` + `restart: unless-stopped` — 전 기수 단골 지적 선회피
- `ddl-auto: validate` 전역 + schema.sql 마운트 — prod 안전
- `S3BinaryContentStorageTest`: spy + `protected getS3Client()` 오버라이드로 **S3 없이 단위 테스트** — 12기 jieunhong 권장 패턴, 14기 유일
- `MDCLoggingInterceptor` — requestId/method/uri MDC + 응답 헤더 `Discodeit-Request-ID`, logback 패턴에 `%X{requestId}` — 요청 흐름 추적 기반 마련
- presigned `Duration.ofSeconds` + 설정값 사용, `.env` 가 .gitignore/.dockerignore 양쪽에, `open-in-view: false`
- `determineHttpStatus` switch로 ErrorCode→HTTP 상태 매핑 명시 (CONFLICT/UNAUTHORIZED 구분)

---

## 🔴 Critical

### 1. head 브랜치 컴파일 실패 — `repository/file/*`, `repository/jcf/*` (12파일), 예: `FileUserRepository.java:22`
`./gradlew compileJava` 실측: `FileUserRepository is not abstract and does not override abstract method findAllWithProfileAndStatus() in UserRepository`, `FileUserStatusRepository ... <S>findAll(Example<S>,Sort) in JpaRepository`, `Message.getChannelId()` cannot find symbol 등 다수. `UserRepository extends JpaRepository`인데 sprint3 시절 File/JCF 구현체가 되살아나 이를 구현하려 함. **Dockerfile의 `./gradlew clean bootJar`도 같은 이유로 실패 → 이미지 빌드 불가**. 같이 들어온 잔재: `dto/*` 평면 패키지 16개(미사용, `dto/request`와 중복), `SprintMission3ApplicationTests.java`, `HELP.md`, `fe_bundle_1.2.3.zip`(바이너리), `api.json` 삭제. 커밋 "미션 8 베이스 코드 적용/덮어쓰기"가 원인. 조치: 위 파일 전부 삭제 → 컴파일 → PR 파일 목록이 sprint8 범위(~15개)인지 확인 후 재푸시. (8기 본인 #85 "PR 올린 후 어떤 파일 올라갔는지 확인")

### 2. 요청 DTO 통째로 로그 → 비밀번호 평문 기록 — `UserController.java:48,68` · `BasicUserService.java:42,102`
`log.info("사용자 생성 요청: {}", userCreateRequest)` — record toString이 `password=...`까지 출력. 수정도 동일(`userUpdateRequest`의 newPassword). 로그는 파일(`.logs/`)에도 남아 컨테이너·호스트에 평문 비밀번호 축적. 식별자(username/email)만 찍거나 record에 toString 오버라이드로 마스킹. **민감정보는 로그에 절대 금지** — 어진님 토론과 같은 원칙.

### 3. `discodeit.storage.type: s3` 하드코딩 + compose `STORAGE_TYPE` 미바인딩 — `application.yaml:51` · `docker-compose.yml:36`
yaml이 `s3` 고정이라 로컬/compose에서 local 스토리지로 못 뜸. compose가 `STORAGE_TYPE` env를 넘기지만 yaml에 `${STORAGE_TYPE:...}` 플레이스홀더가 없어 **아무 효과 없음**(relaxed binding은 `DISCODEIT_STORAGE_TYPE`이어야 함). `type: ${STORAGE_TYPE:local}`로 — 기본값은 피해 작은 쪽(local). 같은 이유로 `application.yaml:16-18` `profiles.active: [dev]` 하드코딩도 제거(미션7 공통 지적, 실행 환경 주입).

## 🟡 Major

### 4. S3Client/Presigner를 매 호출 생성 + get()은 close도 안 함 — `S3BinaryContentStorage.java:56,72,96-102,104-109`
HTTP 커넥션 풀 가진 무거운 객체를 put/get/presign마다 생성. `get()`의 클라이언트는 try-with-resources도 아니라 누수. 전 기수 최다 지적(10기 8건·11기 7건). 생성자에서 1회 생성 + `@PreDestroy` close. 테스트의 `getS3Client()` 스파이 패턴은 필드 주입으로도 유지 가능.

### 5. Static 자격증명 → DefaultCredentialsProvider — `S3BinaryContentStorage.java:97-100,105-108`
`.credentialsProvider(...)` 제거 시 로컬=CLI 프로필, ECS=태스크 롤 자동. 키 자체를 안 만드는 것이 현업 1원칙(김예준·김어진 PR과 동일 안내). 추가로 `@Value` 필드 주입(`:38-39`)과 생성자 주입 혼용 — 통일.

### 6. 전역 핸들러: 일반 Exception 메시지 그대로 응답 + 404/검증 실패를 ERROR 로그 — `ErrorResponse.java:24-26` · `GlobalExceptionHandler.java:22,31,41`
`new ErrorResponse(e, 500)`이 `e.getMessage()`를 그대로 내려 NPE/SQL 메시지 등 내부 정보 노출(sprint7 버전은 고정 메시지였음 — 후퇴). 모든 `DiscodeitException`을 `log.error(..., exception)` 스택트레이스 포함 → 404 한 건마다 ERROR 알람. 4xx는 WARN(스택 없이), 5xx만 ERROR. 검증 실패(`:41`)도 WARN.

### 7. Dockerfile: `sh -c` SIGTERM 미전달 + 단일 스테이지 + 버전 이중 — `Dockerfile:29` · `:11-14` · `:23`+`build.gradle:9`
exec 없음(김어진은 적용), `COPY . .` + 이미지 안 빌드(심화 미수행 항목), `PROJECT_VERSION=1.2-M8` 이중 관리 → `bootJar { archiveFileName }`. 주석의 "~하세요"는 과제 템플릿 문구 — 제출 전 정리.

### 8. AWSS3Test: @TestMethodOrder + 고정 키 + .env 가드 없음 + 클린업 없음 — `AWSS3Test.java:28,31,40-44`
`@TestMethodOrder(OrderAnnotation)`로 테스트 간 순서 의존(8기 본인: "귀찮아서 그렇게 하신 건 아니시죠!?"), `TEST_KEY="test-file.txt"` 고정 → 병렬/반복 실행 시 충돌, `.env` 없으면 `FileNotFoundException`으로 **실패**(스킵 아님 — 김어진·김예준은 `@EnabledIf` 가드), 업로드 객체 미삭제. `@EnabledIf` + 랜덤 키 + `@AfterAll` delete + 각 테스트 독립.

## 🔵 Minor

### 9. `LocalBinaryContentStorage.java:69` `e.printStackTrace()` + RuntimeException 래핑 — `:41,55,70`
printStackTrace는 로그 체계 밖(MDC requestId도 안 붙음). 도메인 예외로 통일(`BinaryContentException` 계열 있음).

### 10. logback FILE appender 컨테이너 기록 — `logback-spring.xml:19-28,33`
`.logs/`에 롤링 파일 → 컨테이너 재배포 시 소실·디스크 점유. stdout만 + CloudWatch. (김예준·김어진 동일)

### 11. (파일에만) `application-dev.yaml:6-8` DB 비번 평문(dev 한정이라 허용 범위) / `EXPOSE 80` + root / compose `env_file: .env` + `environment:` 중복 / `.dockerignore`가 `Dockerfile` 자체도 제외(빌드 컨텍스트엔 무관하나 의도 확인)

---

## 복구 로드맵 (문안용)
1. 베이스 코드 잔재 삭제(repository/file·jcf, dto/ 평면 16개, SprintMission3ApplicationTests, HELP.md, fe_bundle zip) → `./gradlew compileJava` 통과 → PR 파일 목록 ≤ 20개 확인
2. 로그 민감정보(🔴2) + storage.type 플레이스홀더(🔴3)
3. S3 클라이언트 싱글톤(🟡4) + 핸들러 메시지/레벨(🟡6)
4. RDS → ECR → ECS 배포 (기본 미션 완료)
5. exec + 멀티스테이지 + CI (심화)

## 게시 현황
- [ ] 인라인 ~10건 + 총평(격려+로드맵) 문안 전달 (게시는 사용자)
