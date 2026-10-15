# 코드 리뷰 — [김예준] 스프린트 미션 7 (PR #97)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/97
- **작성자**: kim-yejunn (김예준), head `kim-yejunn:김예준` → base `김예준` ✅
- **규모**: +1028 / −44, 30 files (프로젝트 루트는 `sprint-mission-1/` 하위)
- **라벨**: 성실 완주🌿 — 기본 요구사항 8개 전부 구현, 🔴 1건(운영 기능 희생)
- **참고**: 미션6(#89)은 리뷰 없이 머지됐으므로 마지막 실질 리뷰는 #58(미션4+5). 미션6 이월 관점 포함.
- **멘티 질문**: "현업에서 테스트를 어느 정도까지 작성하나?" — 답변 필수

> diff 전체(1468줄) + head raw 검증 완료. 라인은 raw 기준 (경로 접두사 `sprint-mission-1/` 생략).

---

## 총평 — 미션7 기본 8개 항목을 빠짐없이, 테스트는 3층 구조로 성실하게 완주. 단 하나의 🔴: 테스트를 통과시키려고 @EnableJpaAuditing을 주석 처리 — "테스트가 운영 코드를 바꾸게 둔" 사례라 이번 리뷰의 핵심 교육 포인트

**잘한 것:**
- **프로파일 분리 정석**: dev(로컬 상세 로그·배치 통계) / prod(환경변수 + `ddl-auto: validate` + 로그 레벨 축소) / test(H2 MODE=PostgreSQL) — prod에 비밀번호 하드코딩 없음
- **테스트 3층 × 3도메인(User/Channel/Message) 10개 파일**: 단위(Mockito, 실패 케이스 + `should(never())` 부수효과 검증) / 슬라이스(@WebMvcTest 예외→상태코드, @DataJpaTest derived 쿼리 + flush/clear로 영속성 컨텍스트 분리) / 통합(@SpringBootTest+MockMvc, DB 상태까지 검증). BDD given-when 스타일 일관
- **검증 완비**: 전 컨트롤러 @Valid + DTO 제약(@NotBlank/@NotNull/@NotEmpty/@Email), GlobalExceptionHandler에 MethodArgumentNotValid/TypeMismatch/HttpMessageNotReadable/Multipart 핸들러 기존 체계와 통합
- **`@JsonProperty("username")`** (UserDto.java:8) — 내부 필드명(userName)과 API 스펙(username)을 분리한 디테일. 이 덕에 테스트의 `result.userName()`과 jsonPath `$.username`이 모두 정합
- logback rolling(SizeAndTime 10MB/30일) + 프로파일별 레벨, Actuator(health/info/metrics/loggers), `.gitignore`에 `*.log` 선반영
- **`GlobalExceptionHandler:112` `log.atLevel(type.getLevel())`** — ExceptionType이 로그 레벨을 스스로 갖는 구조. "4xx=WARN/5xx=ERROR 구분"은 과거 기수 단골 지적인데 구조적으로 선반영
- Boot 4 신규 테스트 모듈 체계(`spring-boot-webmvc-test`, `tools.jackson`)를 정확히 사용

---

## 🔴 Critical

### 1. 테스트를 위해 운영 기능을 껐다 — `DiscodeitApplication.java:7-8` `// 테스트 시에는 주석 처리 필요` `//@EnableJpaAuditing`
@WebMvcTest 같은 슬라이스 테스트가 메인 클래스의 @EnableJpaAuditing 때문에 깨지니까 **운영 기능을 주석 처리**한 상태로 제출. 결과:
- `BaseUpdatableEntity.java:15-16`의 `@LastModifiedDate updatedAt` **자동 갱신이 전면 중단** — 수정 API를 호출해도 updatedAt이 안 바뀜 (markUpdated()를 수동 호출하는 경로만 갱신)
- createdAt은 `BaseEntity.java:20`의 `= Instant.now()` **필드 초기화 덕분에 "우연히" 채워져서** 문제가 안 보일 뿐
- **올바른 해법 — 10기 #233·11기 #163 멘토들이 "모범답안"으로 못 박은 패턴**: @EnableJpaAuditing을 별도 `@Configuration`(예: global/config/JpaConfig)으로 분리 → 슬라이스 테스트는 그 설정을 안 올리므로 주석 토글이 필요 없어짐. @DataJpaTest에서 auditing이 필요하면 `@Import(JpaConfig.class)`.
- 교훈 문구: **"테스트가 어렵다는 신호는 코드 구조를 고치라는 신호지, 기능을 끄라는 신호가 아니다."**
- 부수 정리: `BaseEntity.java:20`의 `= Instant.now()` 초기화는 @CreatedDate와 중복(10기 #182 동일 지적) — auditing 복구 후 제거. `BaseUpdatableEntity:18-24`의 markUpdated()/updateAt() 수동 메서드도 auditing과 역할 중복 — 하나로.

## 🟡 Major

### 2. 생성 로그가 save 전 — messageId=null로 찍힘 — `MessageService.java:87-88`
```java
log.info("메시지 생성 완료: messageId={}", message.getId());
return messageMapper.toDto(messageRepository.save(message));
```
id는 @GeneratedValue(UUID)라 **persist 때 배정**되므로 save 전인 이 로그는 항상 `messageId=null`. 게다가 저장이 실패해도 "완료" 로그가 남음. save 후로 이동 (ChannelService는 save 후 로깅이라 올바름 — 같은 작성자의 두 패턴이 갈린 것).

### 3. dev 재시작마다 데이터 소실 + 잔재 설정 — `application-dev.yaml:8-11`
- `ddl-auto: create` — 재시작마다 drop+create로 로컬 데이터 전멸. 미션6의 schema.sql/validate 흐름에서 후퇴 (dev는 `update` 또는 validate+스크립트 권장)
- `sql.init.mode: always` + `defer-datasource-initialization: true` — **schema.sql/data.sql이 없어서 아무것도 안 하는 잔재 설정.** 삭제.

### 3-2. `spring.profiles.active: dev` 하드코딩 — `application.yaml:18-19`
운영 배포 시 실수로 dev 설정이 활성화될 위험 (10기 #228 동일 지적). yaml에서 빼고 `SPRING_PROFILES_ACTIVE` 환경변수/실행 옵션으로 주입. (prod를 환경변수로 설계한 것과 짝이 맞으려면 프로파일 선택도 외부에서)

### 4. Actuator info에 인프라 정보 노출 — `application.yaml` info.config 블록
`info.config.datasource.url`(prod에선 ${DATABASE_URL} 전체 — 호스트·포트·DB명), storage 경로, ddl-auto까지 `/actuator/info`로 공개. 과제에선 가시성 연습으로 이해되지만 **prod 프로파일에선 빼는 습관**을 (13기 #116: "prod에선 show-details: never, env.enabled: false" / 10기 #243·11기 #150 동일). `management.info.env.enabled: true`와의 조합 특히 주의.
- 보너스: `info.spring-boot.version: '4.1.0'` 하드코딩은 버전 올리면 거짓말이 됨 — `springBoot { buildInfo() }`(build.gradle)로 /actuator/info에 자동 주입이 정석.

## 🔵 Minor

- **테스트 커버리지 공백**: Auth/ReadStatus/UserStatus/BinaryContent 도메인 테스트 없음. 통합 테스트에 validation 실패(400) 케이스 없음 — @Valid를 달았으니 "빈 username이면 400 + fieldErrors" 한 건이 가성비 최고.
- `ChannelServiceTest.channelCreate_private_success` — 반환값 `result` 미사용, save 횟수만 검증. 반환 DTO 검증 추가.
- 테스트 클래스 `public` 혼재 (ChannelRepository/MessageRepository/ChannelService/MessageService/UserServiceTest는 public, 나머지는 package-private) — JUnit5 관례는 package-private 통일.
- logback `totalSizeCap` 미설정 — 10MB×일수×인덱스로 커질 수 있어 상한 권장. 컨테이너 배포 전제면 prod는 FILE 없이 CONSOLE만(수집기가 가져감)도 고려.
- build.gradle에서 `spring-boot-starter-webmvc`(Boot 4 신명칭) → `spring-boot-starter-web`(구명칭)으로 되돌림 — 동작하더라도 Boot 4 기준 신명칭 유지가 맞는지 확인 [Q].

---

## 멘티 질문 답변 — "현업에서 테스트를 어느 정도까지 작성하나?"

핵심: **커버리지 %가 아니라 리스크 기준**. 현업 일반론:

1. "모든 메서드의 성공+실패 전부"는 현업에서도 안 한다. 기준은 **깨지면 아픈 순서** — 돈/인증/데이터 정합이 걸린 로직, 분기·경계값이 있는 로직, 한 번 버그났던 곳.
2. **단위 테스트는 "로직이 있는 곳"에** — 조건문·계산·변환이 있는 메서드. 단순 위임(service가 repo 호출만)은 테스트 가치가 낮다.
3. **통합 테스트는 중요 시나리오의 행복 경로 + 대표 실패 1~2개** — 세부 분기는 단위로 내린다 (테스트 피라미드: 단위 多 > 슬라이스 > 통합 少). 지금 구성(도메인당 단위+슬라이스+통합)이 정확히 이 피라미드다.
4. **버그 수정 시 재현 테스트부터** 추가하는 게 현업에서 테스트가 쌓이는 주된 경로 — 회귀 방지가 1번 목적.
5. 조직마다 커버리지 게이트(70~80%)를 두기도, 안 두기도 함. 둬도 "숫자 채우기용 getter 테스트"는 안티패턴으로 본다.

덧붙여 실전 팁 몇 가지 (8기 멘토링 때 정리했던 기준):
- private 메서드를 테스트하고 싶은 유혹이 들면 → 그 로직을 별도 객체로 분리해 public으로 만든 뒤 테스트하라는 신호다.
- @BeforeEach에 올리는 기준: ①그걸 몰라도 각 테스트를 이해할 수 있고 ②수정해도 모든 테스트에 영향이 없을 때만.
- 통합 테스트에서 @Transactional 롤백 대신 @AfterEach deleteAll을 쓰면, 프로덕션 코드의 @Transactional 누락 실수를 테스트가 잡아준다.

---

## 다음 스텝 (심화 로드맵)
1. JpaConfig 분리로 auditing 복구 (🔴1) — 이번 수정의 전부
2. MDC 로깅 (심화 항목) — 요청별 traceId를 logback 패턴 `%X{traceId}`로
3. 통합 테스트에 validation 400 + Auth 시나리오 추가
