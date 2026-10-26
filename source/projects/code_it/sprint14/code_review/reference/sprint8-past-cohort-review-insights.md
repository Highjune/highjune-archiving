# Sprint 8 (배포 미션) — 8~13기 멘토 리뷰 인사이트 (2026-10-26 수집)

미션8 = 배포: Dockerfile, docker-compose, S3 스토리지 구현체, AWS(RDS/S3/ECR/ECS), GitHub Actions CI/CD. 심화 = 멀티스테이지 Dockerfile, Codecov.

> **8기 Highjune 본인 담당**: #77/#81/#82/#83/#85/#86/#89 — 시그니처 패턴은 §6 참고 (아키텍처 다이어그램 숙제, @ConfigurationProperties, 테스트 멱등성).
> 멘토진: 8기 Highjune·hagyutae / 9기 bellman66·yerin-mentor·eedys1234·joonfluence / 10기 itstimi-XD·byungwook-min·joonfluence·kwj2435 / 11기 eunjinkim-codeit·JJong0416·psh10066·lcy960729 / 12기 hagyutae·jieunhong / 13기 jinho-yoo-jack·the-eris-net·spring-kang

## 1. 시크릿/자격증명 관리 (최다 테마)

- **Access Key 대신 IAM Role**: `.credentialsProvider(...)` 호출을 빼면 `DefaultCredentialsProvider`가 로컬 CLI 프로필 / GitHub Actions OIDC / ECS Task Role을 자동 탐지 (9기 yerin #180, eedys1234 3건, 10기 #250/#256, 13기 spring-kang #144 — "access/secret key 분기 제거")
- GitHub Actions도 OIDC + IAM Role 권장 (10기 #271/#275)
- `.env` 통째 커밋 = 유출 → 키 재발급부터 (8기 Highjune #85 "git 히스토리에 남아 유출 상태"), **RSA .pem 커밋 P1 사고** (10기 #271 — 키페어 즉시 삭제 + BFG)
- CI에서 `.env` 파일로 자격증명 write 금지 → step `env:` 블록 주입 (12기 hagyutae #118)
- DB 비번 평문 (10기 #255, 8기 #82 dev yaml) → 외부 주입 / Secrets Manager·Parameter Store (11기 #173/#181)
- **9기 yerin-mentor 총평**: Secrets Manager vs S3 env file vs Parameter Store 분리 기준을 실무 관점으로 답변한 선례 있음

## 2. S3 구현

- **S3Client/S3Presigner 매 호출 생성 금지** — HTTP 커넥션 풀 가진 무거운 객체, 싱글톤 필드/@Bean + @PreDestroy (8기 hagyutae #79, 9기 joonfluence P1, 10기 8건, 11기 7건, 12기 jieunhong #122 — 전 기수 최다 공통)
- **presigned URL 단위 버그**: yaml 600(초) ↔ `Duration.ofMinutes(600)`=10시간 (8기 #84, 10기 #254, 11기 #171/#180 "보안상 매우 위험") / 주입받은 expiration 필드를 안 쓰는 dead field (10기 #251 등 4건) / `@DurationUnit` 권장 (10기 #247/#256/#264)
- `matchIfMissing = true` → 프로퍼티 없으면 S3 빈이 기본 등록 → 자격증명 없이 기동 실패 (9기 joonfluence P1) — **"기본값은 안전한 쪽" 원칙**
- S3 예외 매핑: `NoSuchKeyException`만 404, 나머지는 storage error로 구분 — 전부 404로 뭉개면 권한/네트워크 장애도 404 (13기 spring-kang, 10기 4건)
- get() `ResponseInputStream` 미반납 → 커넥션 누수 (10기 #264) / 대용량 `asByteArray()` → `-Xmx384m`에서 OOM, 스트리밍으로 (11기 #177/#179)
- put 시 contentType 미설정 → octet-stream 저장, presigned 미리보기 불가 (11기 4건, 12기 #118)
- **Storage가 ResponseEntity 반환 = 계층 분리 위반** — URL만 반환하고 리다이렉트는 Controller에서 (8기 hagyutae #74, 12기 jieunhong 2건)
- 트랜잭션 안 S3 I/O → 커넥션 점유·롤백 시 고아 객체 → AFTER_COMMIT 이벤트/보상 (10기 #260, 12기 hagyutae #118)

## 3. Dockerfile

- **멀티스테이지 + JRE 경량화**: 단일 스테이지면 소스·gradle 캐시·JDK가 최종 이미지에 (13기 spring-kang) / 런타임은 `eclipse-temurin:17-jre-alpine`·Distroless — 836MB vs 365MB 실측 (11기 #183, 12기 jieunhong 2건, 10기 #251)
- **레이어 캐시**: gradle 설정 파일 선복사 + 의존성 선다운로드 — `COPY . .` 먼저면 한 글자 변경에도 전체 재다운로드. "하루 10번 배포 시 9번은 30초" (11기 #179, 10기 8건). `clean`이 캐시 무효화 (10기 #251/#260)
- **shell form(sh -c) ENTRYPOINT → SIGTERM이 JVM에 미전달** → ECS graceful shutdown 실패. exec form 또는 `exec java ...` (9기 yerin 2회, 10기 8건, 11기 5건 — 전 기수 공통)
- jar명 하드코딩: `*.jar` 와일드카드 위험 / `{이름}-{버전}.jar` + build.gradle version 이중 관리 → `ARG PROJECT_NAME/VERSION` 또는 `bootJar { archiveFileName='app.jar' }` 고정 (8기 Highjune #85, 9기, 10기 5건+)
- ENV 여러 줄 → 백슬래시 1레이어 (11기 4건) / 베이스 이미지 latest·불명확 태그 지양, digest/버전 고정 (11기 #180)
- `.dockerignore` 필수 — 없으면 .git/.gradle/build 통째 컨텍스트 + .env 이미지 유입 (12기 jieunhong #124, 10기 #267)
- 80 포트 대신 8080 + 포트포워딩 관례 (9기 eedys1234 #176)

## 4. docker-compose / 환경설정

- **`depends_on`만으론 DB 준비 보장 안 됨** → `pg_isready` healthcheck + `condition: service_healthy` (10기 7건, 11기 5건 — #179는 "기수 유일 구현" 칭찬)
- **볼륨 마운트 경로 ≠ 앱 실제 저장 경로** → 영속화 실패 (11기 4건: `/app/storage` 마운트 vs `.discodeit/storage` 기록)
- **`spring.profiles.active` yaml 하드코딩** → Boot 2.4+에선 환경변수와 병합돼 dev+prod 동시 활성화, "Unable to determine Dialect" 배포 실패의 실제 원인 (11기 eunjinkim #167/#179 진단, 10기 5건) — 실행 환경에서만 주입
- **환경변수 네이밍 불일치 = 기동 실패 단골**: `DATABASE_URL` vs `SPRING_DATASOURCE_URL` (9기 yerin #183), `PROD_DB_*` vs `SPRING_DATASOURCE_*` (11기 #177), 같은 설정의 주입 경로 2개 공존 금지 (8기 hagyutae #79)
- 로컬 postgres 버전을 RDS와 일치 (12기 2건: 16 vs 17)
- compose에 prod 프로파일 하드코딩 → 로컬이 실 prod 영향 줄 수 있는 구성 (8기 hagyutae #78)
- 기본 application.yaml에 ddl-auto 두는 것 조심 — 실 DB 스키마 삭제 위험 (8기 hagyutae #78)
- 13기 jinho-yoo-jack 최다 반복(7회): "application.yml 환경별 분리"

## 5. CI/CD (GitHub Actions / ECS)

- **CI가 clean 환경에서 실패**: 기본 프로파일로 떠서 localhost:5432 연결 시도 → `SPRING_PROFILES_ACTIVE=test` 지정 (13기 spring-kang #144)
- **피처 브랜치 push에 CD 트리거 = 실배포 사고 위험** → CI/CD 워크플로우 분리, CD는 release 브랜치만 (9기 joonfluence P3)
- ECS `desired-count 0→1` = 명백한 다운타임 (9기 yerin 2회, 10기 11건) → rolling / `--force-new-deployment` / `aws ecs wait services-stable`(sleep 금지)
- task-definition.json은 템플릿만 repo에 — 배포 산출물 성격 (9기 yerin #184)
- ECR Public 로그인은 us-east-1 고정 — 왜인지 주석 요구 (8기 Highjune 3회 "띠용할 수도"), Public/Private 액션 혼동 → 인증 실패 (10기 #252)
- `fail_ci_if_error: true` → Codecov 장애에 CI 전체 실패 (10기 3건) / 존재하지 않는 액션 버전(`checkout@v6`) 즉시 실패 (10기 #275)
- 워크플로우 위생: 전역 env 선언 후 하드코딩으로 덮기 모순, 미사용 env 제거, 변수명 모호성(URI vs NAME) (8기 Highjune #77/#81)

## 6. 테스트 — Highjune 본인 시그니처 포함

- **AWSS3Test 클린업 없음 → 멱등성 깨짐**: "uploadTest 하고 나서 삭제, 클린업은 안하나요?" (8기 Highjune #77) + S3Client/Presigner close (8기 Highjune)
- @TestMethodOrder 금지 — 테스트 독립성, 병렬 불가 (8기 Highjune #77 "귀찮아서 그렇게 하신 건 아니시죠!?")
- AWSS3Test가 src/main에 위치 → 운영 jar에 패키징 (9기 bellman66 3건, 10기 #256/#264, 11기 #179)
- @Disabled 대신 env 주입/`@EnabledIfEnvironmentVariable`/`Assumptions.assumeTrue`로 게이팅 (9기 bellman66, 10기 #267/#274) / 실 AWS 테스트 대신 Mock 단위 테스트 — 속도·비용·외부 환경 의존 (12기 jieunhong #124) / LocalStack+Testcontainers (10기)
- @DisplayName 상세화 + 테스트 함수명 = 본 클래스 함수명 (8기 Highjune 반복)
- 테스트 간 의존 금지(한 테스트가 다른 테스트 메서드 호출/선행 가정) (11기 3건)

## 7. Highjune(8기) 시그니처 — 재사용 1순위

- **아키텍처 다이어그램 숙제** (3개 PR 동일): "키 값을 어디에 설정했고 어디서 가져오고, 깃허브 올렸을 때 액션은 어떻게 돌고 그런 것을 draw.io나 아키텍처 툴로 그려서 공유해주세요. 제일 큰 공부가 될 겁니다."
- **@Value → @ConfigurationProperties** (3개 PR 반복): "키 값들이 많은데요, 별도의 파일로 묶어보실래요"
- **"장점 조사해서 이 코멘트 밑에 남겨주세요" 학습 유도형**: 멀티스테이지 장점, alpine 장점, readonly 트랜잭션 장점, ARG 장점
- build.gradle의 .env 파싱 = "빌드 시스템이 시크릿 다루는 구조" 금지 (#81)
- DDL 테이블 comment 필수 문화 소개 (#82)
- PR 위생: "PR 올린 후 어떤 파일들이 올라갔는지 확인까지" (#85 — 3000개 파일 PR)

## 8. 총평 스타일 참고

- 10기 joonfluence: P1~P5 라벨 + suggestion 블록 / 11기 eunjinkim: "무조건 수정 2가지" 우선순위 못 박기 + 배포 실패 트러블슈팅 단계 제시 / 12기 hagyutae: 설계→배포→미충족 섹션 구조 / 13기 spring-kang: 실행 검증 기반("로컬에서 돌려보면 실패합니다")
