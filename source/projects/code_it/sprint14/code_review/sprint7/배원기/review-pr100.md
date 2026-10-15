# 코드 리뷰 — [배원기] sprint7 (PR #100)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/100
- **작성자**: wongibae (배원기), head `wongibae:배원기-sprint7` → base `배원기` ✅
- **규모**: +3376 / −801, 78 files (api-docs json 1278줄 + FE 번들 포함)
- **라벨**: 방향 이탈🧭 — **미션6 리팩토링은 수준급, 그런데 미션7 요구사항 4개(예외 고도화·검증·Actuator·테스트)가 미수행/제거됨.** PR 본문도 템플릿 그대로
- **참고**: 8~13기 인사이트 (`reference/sprint7-past-cohort-review-insights.md`)

> diff 전체(핵심 3251줄) + head raw 검증 완료.

---

## 총평 — 이번 PR의 절반은 훌륭한 "미션6 보강"이고, 미션7은 프로파일+로깅만 하고 멈췄다. 노력의 방향을 요구사항에 다시 정렬하는 것이 핵심 피드백

**훌륭한 것 (과거 기수 지적을 선반영한 수준):**
- **MapStruct 정식 전환** — interface Mapper + componentModel + uses 합성 + @Mapping(source="channel.id" 등). 수동 매퍼 전면 교체
- **`AppConfig`로 @EnableJpaAuditing 분리** — 10·11기 멘토들이 "모범답안"으로 못 박은 패턴을 정확히 (김예준 PR과 대비되는 올바른 방향)
- **쿼리 최적화 대거**: `findAllByTypeOrIdIn`(findAll 메모리 필터 제거), fetch join 3종(author.status/profile, readStatus.user), `findLastMessageAtByChannelId` LIMIT 1, `@BatchSize(100)` — N+1을 진지하게 공략
- **커서 페이지네이션 시도** (cursor 파라미터 + nextCursor 응답) — 심화 항목 선제 도전
- 채널 삭제에 message/readStatus 선삭제 추가, `ddl-auto: validate` 전환, `profiles.default: dev`, 엔티티 update에 null+equals 가드, schema.sql 재작성(제약 분리, 기존 suer_id 오타 수정)

**그러나 미션7 기준으로는:**
- ❌ 예외 고도화: ErrorCode/커스텀 예외/ErrorResponse 없음 — 핸들러는 기존 3개 그대로(e.getMessage() 노출 포함)
- ❌ 유효성 검사: **starter-validation 의존성을 오히려 제거** — @Valid/@NotBlank 전무
- ❌ Actuator: **의존성 자체가 없음**
- ❌ 테스트: src/test 파일 0개 — **starter-data-jpa-test도 제거**
- 체크리스트·주요 변경사항·질문 모두 빈 템플릿, "셀프 리뷰로 질문하겠다" 했지만 셀프 리뷰 코멘트도 0건

---

## 🔴 Critical

### 1. 유저 삭제 조건 반전 — 삭제 API가 완전히 거꾸로 동작 — `BasicUserService.java:131`
```java
if (userRepository.existsById(userId)) {   // ! 가 빠짐
    throw new NoSuchElementException(...);
}
userRepository.deleteById(userId);
```
**존재하는 유저를 지우면 404, 없는 유저를 지우면 204 성공.** 리팩토링 중 `!` 유실. 탈퇴 기능이 통째로 죽은 상태 — FE에서 탈퇴 한 번만 눌러봤으면 잡혔을 버그.

### 2. 탈퇴 작성자의 메시지가 목록에서 증발 — `MessageRepository.java:16-17`
```java
"LEFT JOIN FETCH m.author a " + "JOIN FETCH a.status "
```
author는 LEFT인데 **a.status가 INNER JOIN** — author가 null(탈퇴)인 메시지는 status 조인 조건을 만족 못 해 **행 자체가 결과에서 빠짐**. 채팅 기록 보존 정책(author만 SET NULL) 설계를 쿼리가 깨뜨림. `LEFT JOIN FETCH a.status`로. (UserMapper:11의 `user.getStatus().isOnline()` expression도 author null이면 NPE — MapStruct interface는 인자 null만 가드하고 expression 내부는 못 지켜줌. `user.getStatus() != null && ...` 가드 필요)

### 3. prod 설정 파일이 웹에 공개되는 위치에 — `src/main/resources/static/application-prod.yaml`
static/ 아래 파일은 ①스프링 설정 탐색 경로가 아니라 **prod 프로파일로 로드되지 않고** ②정적 리소스로 서빙돼 **`http://서버/application-prod.yaml`로 누구나 다운로드 가능**. 지금은 자격증명이 env var placeholder라 직접 유출은 없지만 서버 주소가 노출되고, 구조적으로 가장 위험한 자리. `src/main/resources/`로 이동.

### 4. update의 자기 자신/null 가드를 이번 PR에서 "제거" (퇴행) — `BasicUserService.java:99, 102`
기존 코드: `newEmail != null && !newEmail.equals(user.getEmail()) && existsByEmail(newEmail)` — **올바른 가드가 있었는데** 이번 PR에서 `existsByEmail(newEmail)`만 남김. 결과: FE가 폼 전체(기존값 포함)를 제출하면 본인 username/email에 걸려 **항상 409**. 전 기수 6회 반복 버그를 "만들어 넣은" 셈 — 리팩토링 diff를 제출 전에 본인이 다시 읽었어야 할 지점.

### 5. 미션7 요구사항 4종 미수행 (스펙)
- **Validation**: build.gradle에서 starter-validation 제거됨 — 복구 + 전 요청 DTO 제약 + @Valid + MethodArgumentNotValid 핸들러
- **예외 고도화**: ErrorCode enum + DiscodeitException 계층 + ErrorResponse — 현재 핸들러의 `e.getMessage()` 노출(:17, 25, 33)도 함께 해소됨
- **Actuator**: starter-actuator 추가 + health/info/metrics/loggers 노출
- **테스트**: 단위(Mockito)/슬라이스(@WebMvcTest·@DataJpaTest)/통합(@SpringBootTest+H2) — 지금 0개

## 🟡 Major

### 6. ChannelMapper가 Repository를 직접 주입 — 전 기수 최다 금지 패턴 — `ChannelMapper.java:20-24`
MapStruct abstract 클래스에 MessageRepository/ReadStatusRepository를 @Autowired — toDto 호출마다 lastMessageAt 쿼리 + (PRIVATE면) 참여자 쿼리 → **채널 목록 조회가 채널 수만큼 N+1**. 다른 쿼리들을 그렇게 최적화해놓고 매퍼에서 되돌려받는 모양새. 서비스에서 IN 배치로 미리 조회해 toDto(channel, participants, lastMessageAt)로 넘기는 구조로 (10~13기 전 기수 공통 지적).

### 7. 메시지 없는 채널의 lastMessageAt = Instant.MIN — `ChannelMapper.java:34`
`.orElse(Instant.MIN)` → 응답에 "-1000000000-01-01T00:00:00Z". FE가 날짜를 표시하면 괴상한 값이 나감. 스펙은 null — `.orElse(null)`.

### 8. dev/prod yaml 오타 3종 — 설정이 조용히 무시되는 중 — `application-dev.yaml:2, 6` / `static/application-prod.yaml:2, 6`
`prot:`(→port), `dirver-class-name:`(→driver-class-name), `org.postresql.Driver`(→postgresql). 스프링은 모르는 키를 **에러 없이 무시**하므로 — port는 기본 8080이라 우연히 돌고, driver는 url에서 유추돼 우연히 돈다. "동작하니까 맞겠지"가 안 통하는 대표 사례.

### 9. ReadStatus 중복 생성 정책 변경 — `BasicReadStatusService.java` create
기존: 중복이면 예외(409 성격) → 변경: **중복이면 기존 것을 조용히 반환**(orElseGet). 스펙이 중복 시 에러라면 되돌려야 함. 의도적 변경이라면 왜인지 PR 본문에 적었어야 할 결정.

### 10. message_attachments의 message_id FK 누락 — `schema.sql` (제약 섹션)
재작성하면서 attachment_id FK만 추가하고 **fk_message_attachment_message가 빠짐**(기존 스키마엔 있었음). 메시지 삭제 시 조인 테이블 행 고아 가능. 그리고 sql.init 제거로 schema.sql은 이제 수동 실행 전제인데 실행 방법 안내(README)가 없음.

## 🔵 Minor

- `@JsonManagedReference/@JsonBackReference`(User/UserStatus) — DTO만 반환하므로 불필요 잔재. 엔티티가 Jackson을 탈 일이 생겼었다는 신호라 오히려 점검 대상
- PageResponse.nextCursor가 Object 타입 — Instant로 명시 (12기 동일 지적). createdAt 단독 커서는 동시각 누락 위험 — (createdAt, id) 복합 (전 기수 공통)
- `LocalBinaryContentStorage.java` — e.printStackTrace + RuntimeException 래핑(:init, get) → log.error + 의미 있는 예외. storage.local 패키지 이사는 좋음
- 커스텀 `/api/health` 스크린샷 — Actuator 도입하면 /actuator/health로 대체
- fe_bundle_1.2.3.zip, api-docs_1.2.json(1278줄), HELP.md 커밋 — 산출물은 저장소 밖으로. `.gitignore`의 `.*` 패턴은 `.github/`까지 무시하니 주의
- README "모범 답안 리포지토리입니다" — 업스트림 문구 복사된 것. 수정
- logback totalSizeCap 없음. create의 UserStatus — save 생략하고 cascade PERSIST에 맡긴 건 동작하지만, 지역변수가 안 쓰이고 `setUser` 부수효과에 의존해 읽기 어려움 — 주석 한 줄

---

## 다음 스텝 (우선순위)
1. 🔴1(delete 반전)·🔴4(update 가드 복원) — 기존 코드 diff와 대조해서 복원
2. 🔴5 미션7 요구사항: validation 복구 → 예외 고도화 → Actuator → 테스트 (이 순서)
3. 🔴2(JPQL LEFT JOIN)·🔴3(prod yaml 위치) 수정
4. 미션6 보강분(MapStruct·커서·fetch join)은 이미 좋은 자산 — 🟡6 매퍼 구조만 교정하면 완성
