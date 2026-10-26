# 코드 리뷰 — [김예준] sprint8 (PR #109)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/109
- **작성자**: kim-yejunn (김예준), head `kim-yejunn:김예준` → base `김예준` ✅
- **규모**: +592 / −49, 21 files
- **라벨**: 모범 반영🏆 — **미션7 리뷰 지적 4건 전부 반영** + 전 기수 단골 버그 다수 선회피. 다만 설정 레이어에 기동을 깨뜨리는 🔴 2건
- **참고**: 8~13기 인사이트 (`reference/sprint8-past-cohort-review-insights.md`, 2026-10-26 신규 수집)

> diff 전체(904줄) + head raw 라인 검증 + fork 브랜치/CI 체크 실사 완료.

---

## 총평 — 미션7 피드백(JpaConfig 분리, 로그 위치, profiles 제거, buildInfo, actuator 제한)을 전부 반영했고, 전 기수 멘토들이 반복 지적한 버그들(presigned 단위, S3Client 매 호출 생성, compose healthcheck, AWSS3Test의 src/main 위치)을 선제적으로 피해간 수준급 제출. 반면 schema.sql 배치와 storage.type 기본값이라는 설정 레이어 2곳이 로컬(dev) 기동을 깨뜨리는 구조고, CI는 이 조직 레포에서 트리거되지 않는다

**칭찬 포인트 (전 기수 대비 선반영):**
- **미션7 리뷰 4건 전부 반영**: JpaConfig 분리(+주석 제거), BaseEntity `= Instant.now()` 제거, MessageService 로그를 save 후로(메시지ID null 문제), profiles.active 하드코딩 제거, springBoot buildInfo(), prod actuator show-details:never + info.env:false
- **presigned URL 단위 정확**: `Duration.ofSeconds(presignedUrlExpiration)` + 설정값 실제 사용 — 8기 #84 `ofMinutes(600)`=10시간 버그, 10기 dead-field 버그(4건)를 둘 다 회피
- **S3Client/Presigner를 생성자에서 1회 생성 후 재사용** — 전 기수 최다 지적(매 호출 생성) 회피
- **compose healthcheck + `condition: service_healthy`** — 11기에서 "기수 유일 구현"으로 칭찬받던 패턴
- AWSS3Test가 src/test에 + `@EnabledIf`로 .env 없으면 스킵(CI 안전) — 9기 3회 지적(src/main 위치) 회피
- `.dockerignore` 작성(.env/.pem 포함) — 12기 다수 누락 지적과 대비
- compose 비밀번호 env_file 외부화 + healthcheck까지 변수화, CD에서 latest+**커밋 sha 태그로 배포**(latest 배포 아님)
- 커서 테스트 수정: flush/clear 이슈를 ID 재조회로 해결

---

## 🔴 Critical

### 1. schema.sql이 classpath 루트 + dev `sql.init.mode: always` → dev 기동 깨짐 — `application-dev.yaml:8` / `schema.sql:1`
스프링은 classpath 루트의 `schema.sql`을 sql.init이 자동 실행. dev는 `mode: always` + `ddl-auto: update` + `defer-datasource-initialization: true`라서 Hibernate가 테이블을 만든 뒤 schema.sql의 `CREATE TABLE`(IF NOT EXISTS 없음)이 실행돼 "relation already exists"로 기동 실패. **본인이 test 프로파일에서 이걸 겪고 `mode: never`를 추가한 흔적(application-test.yaml:2-4)** — dev는 그대로. 해법: schema.sql을 `db/` 하위 등 sql.init이 안 집는 경로로 이동(용도가 ①compose postgres 초기화 마운트 ②RDS 수동 실행이므로 classpath 루트일 필요 없음), compose 마운트 경로도 함께 수정.

### 2. `storage.type` 기본값이 s3 — 환경변수 없이 뜨는 모든 로컬 기동 실패 — `application.yaml:4,8`
`type: ${STORAGE_TYPE:s3}` → 아무 설정 없이 띄우면 S3 빈이 뜨면서 `${AWS_S3_ACCESS_KEY}`(기본값 없음) 해석 실패로 기동 불가. 9기 joonfluence P1(matchIfMissing=true로 S3 빈 기본 등록)과 본질 동일. **기본값은 피해 범위가 작은 쪽(local)** — 미션7 profiles.active 때와 같은 기본값 설계 원칙. prod/compose에서만 STORAGE_TYPE=s3 주입.

### 3. CI가 이 조직 레포에서 안 돎 — `test.yml:5`
`pull_request: branches: [ main ]` — 이 레포 PR의 base는 `김예준`이라 트리거 조건 불충족. **실제 이 PR 체크 0건 확인** (`gh pr checks` → "no checks reported"). fork 개인 레포에서 main 대상 PR일 때만 돌았을 것. branches 제한을 빼거나 `'**'`로.

## 🟡 Major

### 4. Static 자격증명 → DefaultCredentialsProvider — `S3BinaryContentStorage.java:43-50`
access/secret key를 @Value로 받아 `StaticCredentialsProvider` 생성. `.credentialsProvider(...)` 자체를 빼면 SDK 기본 체인이 로컬=CLI 프로필/env, ECS=Task Role, Actions=OIDC를 자동 탐지 — 키가 아예 존재하지 않게 됨. 13기 spring-kang·9기 eedys1234/yerin 동일 지적. **멘토 질문("현업 키 관리") 답변의 핵심.**

### 5. Dockerfile 단일 스테이지 — 소스·JDK·gradle 캐시가 최종 이미지에 — `Dockerfile:10-11`
`COPY . .` + 이미지 안 빌드 → 최종 이미지에 전체 소스/의존성 캐시/JDK 포함(비대+소스 유출). 미체크 심화 항목. 멀티스테이지(빌더에서 bootJar → 런타임 JRE에 jar만) + 레이어 캐시(gradle 설정 파일 선복사, 의존성 선다운로드 — "하루 10번 배포 시 9번은 30초"). 11기 실측 836MB→365MB.

### 6. `sh -c` ENTRYPOINT → SIGTERM 미전달, graceful shutdown 실패 — `Dockerfile:15`
PID 1이 sh — ECS 롤링 배포 시 SIGTERM이 JVM에 안 가서 처리 중 요청이 끊김. `"exec java ${JVM_OPTS} -jar ..."`로 exec 한 단어 추가. 9~11기 15회+ 반복 지적.

### 7. 버전 이중 관리 — `Dockerfile:7` + `build.gradle`(version)
`PROJECT_VERSION=1.2-M8`이 두 곳 — 버전 올릴 때 Dockerfile 누락하면 jar 못 찾아 컨테이너 기동 실패. `bootJar { archiveFileName = 'app.jar' }` 고정 또는 ARG 빌드 주입. 미션7 info 버전 하드코딩→buildInfo() 교훈의 Docker판.

### 8. deploy.yml이 PR에 없음 — fork release 브랜치에만 존재
PR 본문엔 CD 완료 체크인데 diff 21개 파일에 deploy.yml 없음 — fork `release` 브랜치에만 있어 조직 레포에 기록이 안 남고 리뷰도 못 받음. 김예준 브랜치에도 포함해 PR에 올리기. (deploy.yml 자체는 release 브랜치에서 확인: latest+sha 태깅, sha로 render-task-definition — 구조 좋음. AWS 키는 secrets → OIDC role-to-assume 소개 가치)

### 9. get()의 ResponseInputStream 미종료 → 커넥션 누수 — `S3BinaryContentStorage.java:74-82`
S3 getObject의 스트림을 호출자가 닫지 않으면 커넥션 풀 고갈(10기 #264). 다운로드는 presigned로 우회하므로 get() 사용처 확인 — 쓰는 곳이 있으면 try-with-resources 계약 명시, 없으면 사용 계획 질문.

## 🔵 Minor

### 10. AWSS3Test 클린업 없음 + 테스트 간 의존 — `AWSS3Test.java:63,70`
업로드한 `test/` 객체가 실행마다 버킷에 축적 — @AfterAll deleteObject (8기 본인 코멘트 그대로: "클린업은 안 하나요? 테스트가 멱등하지 않을 것 같아요"). download()가 upload()를 직접 호출 — @BeforeEach로. 장기적으론 Mock/LocalStack(12기 jieunhong: 실 AWS 테스트는 속도·비용·외부 의존).

### 11. @Value 5개 → @ConfigurationProperties — `S3BinaryContentStorage.java:42-47`
8기 본인 시그니처 멘트: "키 값들이 많은데요, 별도의 파일로 묶어보실래요." S3Properties record + @ConfigurationProperties("discodeit.storage.s3") — 타입 세이프 + 테스트 용이.

### 12. schema.sql: read_status UNIQUE(user_id, channel_id) 중복 2건 — `schema.sql` (read_status 제약)
`read_status_user_id_channel_id_key` + `uks2dq41xxk6kq89ov394a93cqi` — pg_dump 산출물 티. 하나 제거. (+ FK들에 ON DELETE 정책 없음 — 탈퇴 시 author SET NULL 같은 기존 설계 의도가 DDL에 반영됐는지 확인 질문 가치)

### 13. (리뷰 파일에만) put 시 contentType 미설정 — `S3BinaryContentStorage.java:61-64`
octet-stream으로 저장되지만 download에서 responseContentType으로 오버라이드하므로 실해는 없음 — put에 넣으면 S3 콘솔/직접 접근에서도 올바른 타입. 11기 4건 지적.

### 14. (리뷰 파일에만) EXPOSE 80 + 컨테이너 root 실행 — `Dockerfile:13`
8080 + 포트매핑 관례(9기 eedys1234), non-root USER. / Storage 인터페이스의 ResponseEntity 반환은 기존 구조(이번 PR 아님) — 8기 hagyutae·12기 jieunhong 계층 분리 지적 선례만 기록.

---

## 질문 답변 — "현업에서는 중요한 키들을 보통 어떻게 관리하는지"

1. **1원칙: 키를 만들지 않는다.** AWS 안에서 AWS를 쓸 땐 IAM Role. ECS 태스크 롤 + DefaultCredentialsProvider → 키 발급/배포/로테이션 자체가 소멸. GitHub Actions도 OIDC(role-to-assume)로 키 없이 역할 가정.
2. **그래도 남는 시크릿(DB 비번 등)은 전용 보관소**: Secrets Manager / SSM Parameter Store(SecureString) → ECS 태스크 정의 `secrets` 필드로 주입. S3 .env(environmentFiles)는 공식 기능이지만 암호화/로테이션/접근감사/버전관리에서 밀림.
3. 실무 예시: k8s + External Secrets로 Secrets Manager 값을 환경변수로 주입 — 코드는 어디서 왔는지 모름.
4. 지금 구성에서 첫 걸음 = 🟡4 (credentialsProvider 제거).

## 다음 스텝 (우선순위)
1. 🔴1·2 (dev 기동 복구: schema.sql 이동 + storage.type 기본 local)
2. 🔴3 (CI 트리거) + 🟡8 (deploy.yml PR 포함)
3. 🟡4 (IAM Role 전환 — 질문 답변 연계) → 🟡5·6·7 (Dockerfile 3종)
4. 심화 남은 것: 멀티스테이지 (🟡5와 동일 작업)

## 2차 추가 후보 (2026-10-26, 1차 게시 후 — 현업 팁 위주, raw 라인 검증 완료)
- `logback-spring.xml:27-32` prod에서 FILE appender(.logs/app.log) — 컨테이너는 stdout만 → awslogs/CloudWatch. 재배포 시 소실·디스크 점유
- `Dockerfile:8` JVM_OPTS 빈값 — `-XX:MaxRAMPercentage=75.0`, ECS 메모리 하드리밋 초과 시 137 OOMKilled
- `Dockerfile:13` + `application-prod.yaml:15` EXPOSE 80 + root 실행 — non-root USER는 1024 이하 바인딩 불가 → 8080 + 매핑
- `application-prod.yaml:4` ddl-auto validate 칭찬 + Flyway 소개(schema.sql 수동 실행의 근본 해법)
- `S3BinaryContentStorage.java:78` NoSuchKeyException만 404, 나머지 SdkException 미처리 — 404 vs 장애 구분(알람 기준)
- `S3BinaryContentStorage.java:62-64` put contentType 미설정 → octet-stream
- ECS 컨테이너 헬스체크/ALB가 /actuator/health 보는지 질문 — probes(readiness/liveness) 분리
- `deploy.yml:61-66`(PR 미포함, 일반 코멘트) desired-count 0 다운타임 — 본인 주석으로 인지함, 동적 hostPort+ALB·circuit breaker 소개
- `application.yaml:2` `discodeit.seed: true` 소비자 없음(Java 전수 grep 0건) — 죽은 설정
- `compose.yaml:9` prod 프로파일 하드코딩 — 환경 분리 토론거리

## 게시 현황
- [x] 1차 게시 완료 (review 5651336941, APPROVED): 인라인 9건(1·2·3·5·6·7·9·10·12) + 총평. **미게시**: 4(credentialsProvider), 8(deploy.yml 미포함), 11(@ConfigurationProperties), 멘티 질문 답변, 아키텍처 숙제
- [ ] 2차 추가 코멘트 (위 후보, 게시는 사용자)
