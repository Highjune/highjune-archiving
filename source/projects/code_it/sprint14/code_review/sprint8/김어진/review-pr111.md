# 코드 리뷰 — [김어진] sprint8 (PR #111)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/111
- **작성자**: rladjwls02 (김어진), head `rladjwls02:김어진-sprint8` → base `김어진` ✅
- **규모**: +614 / −159, 34 files
- **라벨**: 성실 반영🙂 — 기본 요구사항 전부 완료(RDS·S3·ECR·ECS 배포, 공인 IP 서비스 중), **sprint7 로그 토론 내용을 코드로 반영**. 심화(멀티스테이지·CI/CD) 미수행, "멘토에게" 질문은 추후 작성 예정
- **참고**: 8~13기 인사이트 `reference/sprint8-past-cohort-review-insights.md`, 김예준 #109 리뷰(같은 스프린트 비교)

> diff 1554줄 전체 + head raw 라인 검증(`rladjwls02/14-sprint-mission@김어진-sprint8`) 완료. CI 체크 0건(워크플로우 자체 없음). deploy/CI 파일 없음 — 수동 배포.

---

## 총평 — 기본 미션 완주 + 지난 로그 토론을 코드로 소화한 PR. 다만 (1) 스토리지 쓰기가 트랜잭션 안에 있어 롤백 시 고아 파일, 삭제 시 파일 미삭제 (2) prod `ddl-auto: update` + schema.sql 모순 (3) 기본 프로파일 prod — 이 셋이 우선 수정. 심화 2개(멀티스테이지·CI/CD)가 다음 스텝

**칭찬 포인트:**
- **로그 리팩토링이 지난 디스코드 토론 그대로**: 컨트롤러 "완료" 로그 전부 제거 → 서비스 진입 "요청" 로그 + 식별자(key=value), orElseThrow 안 warn 제거(전역 핸들러가 담당), `log.atLevel(errorCode.getLevel())` 활용. 교과서적으로 반영
- `ENTRYPOINT ["sh","-c","exec java ..."]` — **exec 이미 적용**(김예준 PR에서 지적한 SIGTERM 문제 선회피), alpine 베이스, `@PreDestroy`로 S3Client/Presigner close
- `STORAGE_TYPE` 기본값 **local** (안전한 기본값), compose 볼륨 `/app/storage` = `STORAGE_LOCAL_ROOT_PATH` 일치(11기 단골 버그 회피), `.env`를 .gitignore/.dockerignore 양쪽에
- presigned `Duration.ofSeconds(expirationSeconds)` + 설정값 실제 사용
- `InvalidPasswordException(user.getPassword())` → `getUsername()` — **비밀번호가 예외 메시지로 새던 버그 수정**
- 전역 Exception 핸들러가 `e.getMessage()` 대신 고정 메시지 반환(내부 정보 노출 차단), 검증 실패 시 fieldErrors를 details로
- update 중복 검사에서 자기 자신 제외(`!newEmail.equals(user.getEmail())`) — 기존 버그 수정
- DB BYTEA 저장 → 스토리지 분리 + 응답 DTO에 첨부/프로필 객체 추가로 FE 이미지 미표시 해결
- 배포 env의 `JVM_OPTS=-Xmx256m -Xms128m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC` — 프리티어 메모리를 의식한 튜닝

---

## 🔴 Critical

### 1. 스토리지 쓰기가 트랜잭션 안 + 롤백 시 고아 파일 / 삭제 시 파일 미삭제 — `BasicUserService.java:65,131,153` · `BasicMessageService.java:78,135` · `BasicBinaryContentService.java:35`
`binaryContentStorage.put()`이 `@Transactional` 메서드 안, `repository.save()` **전**에 실행. 이후 DB 저장/커밋이 실패하면 S3·디스크에는 파일이 남고 DB에는 없음(고아). 반대로 user/message delete는 `binaryContentRepository.delete`만 하고 **스토리지 파일은 안 지움** → S3에 영원히 축적(요금). `BinaryContentStorage` 인터페이스에 `delete`가 없음. **지난 AFTER_COMMIT 토론이 실제로 필요한 곳이 바로 여기** — 업로드는 커밋 후(`@TransactionalEventListener(AFTER_COMMIT)`), 삭제는 커밋 후 스토리지 delete(실패해도 DB는 이미 정리됨 → 로그만). 10기 #260·12기 hagyutae #118 동일 지적.

### 2. prod `ddl-auto: update` + schema.sql 모순 2건 — `application-prod.yaml:12` · `schema.sql:7,35`
prod에서 Hibernate가 RDS 스키마를 수정하는 구조(전 기수 공통: prod는 `validate`). 그러면서 schema.sql엔 ①엔티티에서 지운 `bytes BYTEA`가 남아 있고(:7) ②`author_id UUID NOT NULL ... ON DELETE SET NULL`(:35) — NOT NULL 컬럼을 NULL로 만들라는 모순(유저 삭제 시 제약 위반). 엔티티 `Message.java:36-37`의 `nullable=false` + `@OnDelete(SET_NULL)`을 그대로 받아 적은 것. schema.sql을 진실(SSOT)로 정리하고 prod는 validate.

### 3. `spring.profiles.default: prod` — `application.yaml:7`
아무 설정 없이 띄우면 prod로 뜸(이전엔 dev). 로컬에서 `bootRun`만 치면 `DB_URL` 없음 + prod 설정으로 기동 실패/오동작. 기본값은 피해가 작은 쪽(dev/local) — 김예준 #109의 storage.type과 같은 원칙. 배포 환경에서만 `SPRING_PROFILES_ACTIVE=prod` 주입(이미 .env에 있음). `application-prod.yaml:5-9` datasource는 `application.yaml:12-16`과 완전 중복 — 제거.

## 🟡 Major

### 4. `FileError()`가 원인 예외를 버림 + 500인데 WARN — `LocalBinaryContentStorage.java:42,51,63` · `S3BinaryContentStorage.java:62,72` · `ErrorCode.java:70-72`
`catch (SdkException e) { throw new FileError(); }` — cause 미전달이라 로그에 "파일 입출력 도중 문제" 한 줄만 남고 S3 권한/네트워크/키 문제인지 알 수 없음. `super(message, cause)` 체인 필요. 또 `ERROR_FILES_STORE`가 `Level.WARN` + `HTTP_SERVER_ERROR` — 5xx(우리 문제)는 ERROR가 맞음(본인 로그 토론: "에러 로그 = 우리 문제"). `DiscodeitException(ErrorCode)` 생성자의 `details = null`도 `Map.of()`로.

### 5. Static 자격증명 → DefaultCredentialsProvider — `S3BinaryContentStorage.java:44-49`
`.credentialsProvider(...)` 제거 시 로컬=CLI 프로필, ECS=태스크 롤 자동. 김예준 #109 답변과 동일(키를 안 만드는 것이 1원칙). `AWSS3Test.java:47-60`도 .env 직접 파싱 대신 같은 체인 사용 가능.

### 6. Dockerfile 단일 스테이지 + 버전 이중 관리 — `Dockerfile:10-12` · `Dockerfile:6` + `build.gradle:8`
`COPY . .` 후 이미지 안 `gradlew bootJar` → 소스·gradle 캐시·JDK가 최종 이미지에. 심화 "이미지 최적화"가 정확히 이것. `PROJECT_VERSION=1.2-M8`이 build.gradle과 중복 → `bootJar { archiveFileName='app.jar' }`.

### 7. `depends_on`만으로 DB 준비 보장 안 됨 — `docker-compose.yml:33-34`
postgres 컨테이너 시작 ≠ 접속 가능. 앱이 먼저 떠서 connection refused로 죽는 전 기수 단골(10기 7건·11기 5건). `pg_isready` healthcheck + `condition: service_healthy`. `SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE}` 기본값 없음 → .env 없으면 빈 값 → 3번과 결합해 prod로 뜸.

### 8. CI/CD 없음 (심화 미수행) — 일반 코멘트
`.github/workflows` 없음, ECR push·ECS 배포 수동. 다음 스텝 1순위. 주의: 조직 레포 PR은 base가 `김어진`이라 `branches: [main]` 제한 걸면 안 돎(김예준 #109에서 실증).

## 🔵 Minor

### 9. AWSS3Test 테스트 간 의존 + 클린업 없음 — `AWSS3Test.java:74,82`
`download()`/`presignedUrl()`이 `upload()`를 직접 호출. 업로드한 `test/` 객체 미삭제 → 버킷 축적. @BeforeEach + @AfterAll deleteObject. `System.out` → log.

### 10. logback: 컨테이너 파일 로그 + ANSI 색상 + test 프로파일 CONSOLE 미정의 — `logback-spring.xml:26-41`
①`TIME_BASED_FILE`이 root에 항상 → 컨테이너 안 `.logs/` 기록(재배포 시 소실, 5GB cap까지 디스크 점유). stdout만 → CloudWatch. ②`%highlight`/`%magenta` ANSI 이스케이프가 CloudWatch에 깨진 문자로. ③CONSOLE이 dev/prod `springProfile` 안에만 정의 → `test` 프로파일(application-test.yaml)에선 "Could not find an appender named [CONSOLE]" — 테스트 콘솔 로그 사라짐.

### 11. 메시지 목록 N+1 — `MessageDto.java:28-30` · `BasicMessageService.java:106-113`
`MessageDto`에 `author`(UserDto → profile까지)·`attachments` 추가로 메시지 50건 조회 시 author 지연로딩 + profile + `findAllByMessageId` 각각 N회. 기존에도 attachmentIds N+1은 있었으나 이번에 author가 더해짐. `@EntityGraph` 또는 fetch join + 첨부 in절 일괄 조회. (sprint8 범위 밖이라 참고)

### 12. (파일에만) 기타
- `EXPOSE 80` + root 실행 — 8080 + non-root USER (김예준 C와 동일)
- RDS 엔드포인트가 PR 첨부 env에 공개 + 공인 IP 서비스 — RDS **퍼블릭 액세스 여부**와 SG 5432 소스 확인 질문 가치
- `BasicBinaryContentService.create`는 `@Transactional` 없음 → put 후 save 실패 시 역시 고아(🔴1과 동일)
- S3 `get()` ResponseInputStream 호출자 close 책임 (S3 경로에선 presigned라 미사용)

---

## 다음 스텝 (우선순위)
1. 🔴1 (스토리지 쓰기 AFTER_COMMIT + delete 추가) — 지난 토론 연계, 학습 효과 최대
2. 🔴2·3 (prod validate + schema.sql 정리, 기본 프로파일)
3. 🟡4 (예외 cause·레벨) → 🟡6·7 (멀티스테이지·healthcheck)
4. 🟡8 CI/CD (심화)

## 게시 현황
- [ ] 인라인 ~10건 + 총평 문안 전달 (게시는 사용자). "멘토에게" 질문은 멘티가 추후 작성 예정
