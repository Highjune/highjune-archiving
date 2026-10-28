# 코드 리뷰 — [조예준] sprint8 (PR #114) — 시작 전 베이스 코드 PR

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/114
- **작성자**: joyejun (조예준), head `joyejun:mission8` → base `조예준` ✅
- **규모**: +8,786 / −434, **132 files** — 본문 "시작전 pr 올립니다", 체크리스트 템플릿 그대로, "셀프 코드 리뷰로 질문 이어가겠다"
- **라벨**: 미완성🛠️(시작 전) — sprint8 산출물(Dockerfile·compose·S3) 없음. **head 컴파일 실패(실측, 3 errors)**
- **이력**: sprint2·3 머지, sprint6 "미완성" 머지(10/03), **sprint7 미제출** → 베이스 코드로 sprint7 수준을 따라잡는 상태
- **참고**: `reference/sprint8-past-cohort-review-insights.md`, 신상엽 #113(동일 베이스 코드)

> 커밋 5개(10/25): 베이스 코드 push → README → upstream main 머지 → upstream 조예준 머지 → "병합 완료". 코드잇 공식 sprint8 베이스 코드와 본인 sprint6 잔재가 섞임.

## 🔎 베이스 코드 식별 (중요 — 상엽 #113 리뷰에도 영향)
`UserController.java`·`GlobalExceptionHandler.java`·`MDCLoggingInterceptor.java`가 조예준·신상엽 head에서 **blob 동일**(git hash-object) → 코드잇 공식 sprint8 베이스 코드. 따라서 아래는 **베이스 코드 자체의 문제**:
- `UserController.java:48,68` 요청 DTO 통째 로그 → password 평문 (`BasicUserService.java:42,102`도)
- `GlobalExceptionHandler.java:22-23` 일반 Exception `e.getMessage()` 응답 노출, `:31` 모든 커스텀 예외 ERROR+스택, `:41` 검증 실패 ERROR
- `LocalBinaryContentStorage.java:40,67` `printStackTrace()` + RuntimeException 래핑
- `application.yaml:14-16` `profiles.active: [dev]` 하드코딩, `application-dev.yaml:6-8` DB 비번 평문
→ 상엽 #113 코멘트 2·6·9번은 베이스 코드 비판. 수정 요구는 유효하되 "베이스 코드에 있는 것도 그대로 믿지 말 것"으로 프레이밍 권장.

---

## 총평 — 베이스 코드로 출발점을 맞춘 건 좋은 선택(sprint7 미제출 상태에서 현실적). 다만 ①본인 구 코드(`mappper/`, `LocalBinaryContentStorageImpl`, `codeit/` 서브프로젝트)가 같이 남아 컴파일이 깨져 있고 ②베이스 코드 자체에 비밀번호 로그 등 함정이 있어 그대로 쓰면 안 됨. 시작 전 PR이므로 "깨끗한 출발선 만들기" 체크리스트 + sprint8 함정 선제 안내 위주

## 🔴 Critical (출발선)

### 1. 컴파일 실패 — `mappper/ChannelMapper.java:32,38` · `mappper/MessageMapper.java:29`
`./gradlew compileJava` 실측 3 errors: `readStatusRepository.findAllByChannelId` 없음, `ChannelDto` 생성자 시그니처 불일치(7개 vs 6개 인자), `message.getUpdateAt()` 없음. 패키지명 오타 `mappper`(p 3개)인 본인 sprint6 매퍼 7개(@Component)가 베이스의 `mapper/` 7개와 공존. `mappper/` 폴더 삭제가 답(베이스 `mapper/`가 완전체).

### 2. `LocalBinaryContentStorageImpl.java` 중복 빈 — `storage/local/LocalBinaryContentStorageImpl.java:21-23`
베이스 `LocalBinaryContentStorage`와 **같은 `@ConditionalOnProperty(local)` + `@Component`** → 컴파일을 고쳐도 기동 시 `BinaryContentStorage` 빈 2개로 `NoUniqueBeanDefinitionException`. 삭제.

### 3. `codeit/` 서브프로젝트 통째 + `.DS_Store` 다수 + `.ser` 직렬화 데이터 커밋 — `codeit/**`
gradlew·build.gradle·file-data-map/*.ser(sprint2 파일 저장소 데이터)·`.DS_Store` 10개+가 루트 하위 `codeit/`에 통째로. 삭제 + `.gitignore`에 `.DS_Store`. `src/main/java/.../discodeit/README.md`(빈 파일)도 제거. (8기 본인 #85 "PR 올린 후 어떤 파일 올라갔는지 확인")

## 🟡 Major (베이스 코드 함정 — 그대로 쓰지 말 것)

### 4. 요청 DTO 통째 로그 → 비밀번호 평문 — `UserController.java:48,68` · `BasicUserService.java:42,102`
베이스 코드에 있는 그대로. record toString에 `password=` 포함. 식별자만 찍기.

### 5. 전역 핸들러: `e.getMessage()` 노출 + 전부 ERROR — `GlobalExceptionHandler.java:22-23,31,41` · `ErrorResponse.java:24-26`
4xx WARN(스택 없이)/5xx ERROR, 일반 Exception은 고정 메시지.

### 6. `profiles.active` 하드코딩 + `storage.type: local` 플레이스홀더 없음 — `application.yaml:14-16,49`
sprint8에서 `STORAGE_TYPE`·`SPRING_PROFILES_ACTIVE`를 환경변수로 주입해야 하므로 `${STORAGE_TYPE:local}` 형태로 바꾸는 것이 첫 작업. 기본값은 local(안전한 쪽).

## 🔵 Minor
### 7. `LocalBinaryContentStorage.java:40,67` `printStackTrace()` — 로그 체계 밖(MDC requestId 미부착). 도메인 예외로.
### 8. PR 위생 — 시작 전 PR은 **Draft**로, 본문 체크리스트는 실제 상태로, 완료 시 Ready for review. 132파일 → 정리 후 sprint8 범위만 남게.

## sprint8 선제 가이드 (총평용 — 전 기수 함정 5)
1. Dockerfile: `exec java`(SIGTERM), 멀티 스테이지, jar명 고정(`bootJar { archiveFileName }`)
2. compose: `pg_isready` healthcheck + `condition: service_healthy`, 볼륨 경로 = `root-path`
3. S3: S3Client/Presigner **1회 생성**(매 호출 금지), presigned `Duration.ofSeconds`(분 단위 버그 조심), `credentialsProvider` 지정 안 하기(IAM Role)
4. 설정: `${STORAGE_TYPE:local}`, prod `ddl-auto: validate`, `.env`는 .gitignore+.dockerignore 둘 다
5. 테스트: AWSS3Test는 `@EnabledIf`(.env 없으면 스킵) + 클린업 + 테스트 간 의존 금지; S3 없이 도는 단위 테스트(spy)도 가능 — 상엽 #113 참고

## 게시 현황
- [ ] 코멘트 ~8건 + 총평(출발선 체크리스트 + 선제 가이드) 문안 전달 (게시는 사용자)
