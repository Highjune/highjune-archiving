# 코드 리뷰 — [신상엽] sprint7 (PR #99)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/99
- **작성자**: Smil-limS (신상엽), head `Smil-limS:mission_7` → base `신상엽` ✅
- **규모**: +2552 / −8483, 183 files (삭제 대부분은 잘못 커밋돼 있던 React FE 소스 정리 — 좋은 청소)
- **라벨**: 복귀 환영🎯 + 모범답안 병합 리스크 — sprint3 #45 이후 첫 정식 리뷰 (sprint5 #81 CLOSED·sprint6 #92 미리뷰)
- **중요 맥락**: 배원기 #100과 동일한 공통 베이스(모범답안 레포 추정)를 병합한 흔적 — **같은 버그 4종 공유** + 병합 과정에서 **본인 기존 코드의 더 좋았던 부분이 퇴행**됨
- **테스트 3종 미수행은 본인이 체크리스트에 정직하게 표기**

> diff 전체(핵심 6896줄) + head raw 검증 완료.

---

## 총평 — 스펙 정비(XxxApi 분리·@Valid·검증 메시지·fieldErrors 수집)와 FE 소스 청소는 상엽님답게 깔끔하다. 그러나 공통 베이스를 병합하면서 ①그 베이스의 버그 4종을 그대로 들여왔고 ②본인 기존 코드가 더 좋았던 3곳(ErrorCode의 HttpStatus, 핸들러 로깅, 정적 팩토리)이 오히려 후퇴했다. "가져온 코드와 내 코드를 비교·선택하는 눈"이 이번 리뷰의 주제

**잘한 것:**
- **Swagger XxxApi 인터페이스 분리** (Auth/User/Channel/Message/ReadStatus/BinaryContent) — 역대 기수 멘토 공통 권장 패턴
- **@Valid + 검증 메시지 정성**: min/max·@Email·"비공개 채널은 최소 2명" 같은 도메인 규칙까지 제약으로. **validation 핸들러가 fieldErrors를 details에 수집** (김어진 PR에 없던 완성도)
- URL·상태코드 스펙 정비: PATCH 전환, /api/readStatuses, 201/204, 엔티티 노출 제거(User→UserDto)
- BaseEntity `id = UUID.randomUUID()` 필드 초기화 → @GeneratedValue 전환, 잘못 커밋돼 있던 FE 소스(package-lock 포함 ~7천 줄) 삭제
- prod yaml을 올바른 위치(resources/)에 둠 (배원기와 달리 static 사고 없음)

**병합으로 들여온 공유 버그 (배원기 #100과 동일):**

## 🔴 Critical

### 1. 유저 삭제 조건 반전 — `BasicUserService.java:142`
`if (userRepository.existsById(userId)) { throw new UserNotFoundException(...) }` — **존재하면 404, 없으면 204**. 삭제 기능이 거꾸로. (:143의 log.warn "존재하지 않는 사용자"를 존재할 때 찍는 것까지 포함) `!` 복원.

### 2. 탈퇴 작성자 메시지 증발 — `MessageRepository.java:16-17`
`LEFT JOIN FETCH m.author a` + `JOIN FETCH a.status`(INNER) — author null인 메시지가 결과에서 탈락. `LEFT JOIN FETCH a.status`로. (UserMapper의 `user.getStatus().isOnline()` expression NPE 가드도 함께)

### 3. prod에 DB 비밀번호 평문 하드코딩 — `application-prod.yaml:6-8`
`password: discodeit1234`가 운영 프로파일에 그대로. 전 기수 최다 반복 지적 — `${DB_URL}`/`${DB_PASSWORD}` 환경변수로. 같은 파일 **:14의 open-in-view가 hibernate: 아래에 들여쓰기**돼 있어 `spring.jpa.hibernate.open-in-view`라는 없는 키 → 조용히 무시 → OSIV가 기본값(true)로 켜진 채 운영. `spring.jpa.open-in-view`로 한 단계 올려야 함 (11기 멘토의 "YAML 들여쓰기 레벨 실수" 바로 그 패턴).

### 4. update 자기 자신/null 가드 없음 — `BasicUserService.java:109, 113`
`existsByEmail(newEmail)` — 본인 기존값 그대로 제출하면 409, null이면 existsByEmail(null) 호출. `existsByEmailAndIdNot` + null 스킵.

## 🟡 Major — 병합 과정의 "퇴행" 3곳 (본인 기존 코드가 더 좋았음)

### 5. ErrorCode에서 HttpStatus를 제거하고 이름 문자열 파싱으로 — `ErrorCode.java` + `GlobalExceptionHandler.java:18-20`
**기존 코드는 ErrorCode에 HttpStatus가 내장**돼 있었고(400/404/409/500 분류까지 완비 — 9기·13기 멘토 권장 패턴 그대로), 이번에 message만 남기고 제거. 핸들러는 `name().contains("NOT_FOUND") ? 404 : 400`으로 판정 — 결과: **중복(DUPLICATE_USER)이 409가 아니라 400**, 새 코드 추가 때마다 이름 규칙에 의존. 기존 방식 복원이 정답.

### 6. 핸들러에서 @Slf4j와 log.error 제거 — `GlobalExceptionHandler.java` (로그 0건)
기존 핸들러엔 로깅이 있었는데 사라짐. **Exception 폴백이 로그 없이 500만 반환 — 서버 장애가 어디에도 기록되지 않음.** 로그 관리가 이번 미션 주제인데 정작 가장 중요한 에러 로그가 삭제됨. DiscodeitException→warn, Exception→error로 복원. (ErrorCode에 slf4j Level 필드를 넣고 log.atLevel로 묶으면 5번과 함께 구조적으로 해결)

### 7. 정적 팩토리 → public 생성자 전환
기존 `User.create()/Channel.create()` 정적 팩토리(sprint 초기에 칭찬했던 본인 스타일)가 전부 public 생성자로 교체됨. 치명적이진 않지만, 가져온 코드가 본인 코드보다 나을 때만 바꾸는 게 원칙 — 이번 병합은 그 반대 방향이 여러 곳.

## 🟡 기타 (공유 베이스 동일)

- **ChannelMapper @Autowired Repository** (`ChannelMapper.java:20-24`) — 채널 목록 N+1, 전 기수 최다 금지 패턴. + `:34 .orElse(Instant.MIN)` — 메시지 없는 채널이 "-10억년"으로 응답. 서비스 배치 조회 + null로.
- **`profiles.active: dev` 하드코딩** (`application.yaml:5`) — 배원기는 default였는데 상엽님은 active. 운영에서 옵션 없이 뜨면 dev로. yaml에서 빼고 SPRING_PROFILES_ACTIVE 주입 (또는 최소한 profiles.default로).
- info 블록 datasource url 노출 + version 1.7.0/spring-boot 4.1.1 하드코딩 → buildInfo() (김어진·배원기와 동일 코멘트)
- `LocalBinaryContentStorage` printStackTrace ×2 → log.error
- api-docs_1.2.json(1278줄)·static assets 커밋 — 산출물 제외

## 🔵 Minor

- 로그 메시지 복붙 오류: `BasicUserService.java:52` "이미 존재하는 유저 이름입니다: {}"에 **email 변수**를 바인딩 / `:110, 114` update인데 "사용자 **생성** 실패" 문구
- UserAlreadyExistsException 하나로 email/username 중복 통합 — 기존 DUPLICATE_EMAIL/DUPLICATE_USERNAME 구분이 FE 에러 처리엔 더 친절했음
- PageResponse.nextCursor Object 타입 → Instant 명시, createdAt 단독 커서 동시각 누락 (전 기수 공통)
- 테스트 3종 미수행 — 본인 인지. 다음 제출의 최우선 (JpaConfig 분리는 이미 돼 있어 슬라이스 테스트 장애물 없음)

---

## 다음 스텝 (우선순위)
1. 🔴 4건: delete 반전 · JPQL LEFT 통일 · prod 비밀번호 env var + open-in-view 들여쓰기 · update 가드
2. 🟡 퇴행 복원: ErrorCode에 HttpStatus 되살리기 + 핸들러 로깅 복원 — **본인 기존 코드 참고**
3. 테스트 3종 (체크리스트 미완 항목)
4. 교훈: 외부 코드를 병합할 땐 diff를 떠서 "내 것보다 나은가"를 항목별로 판단 — 이번엔 버그 4종이 그대로 들어오고 좋은 코드 3곳이 나갔다
