# Sprint 6 (JPA 전환) — 과거 기수(8~13기) 멘토 리뷰 인사이트

> 수집일: 2026-09-15. `codeit-bootcamp-spring/{8..13}-sprint-mission`의 sprint6 PR 멘토 리뷰(인라인+총평)를 병렬 에이전트로 수집·통합.
> **8기는 Highjune 본인이 멘토**였음 (참가자 아님) — sprint6 담당 PR #54/#55/#56/#57/#59, 인라인 52건, APPROVED 위주 부드러운 톤 + 실무 관점.
> 원본 JSON: 세션 스크래치패드 `r8~r13` (휘발성, 필요 시 재수집).

## 미션 6 컨텍스트

전 기수 공통: **JCF/File → Spring Data JPA + PostgreSQL 전환**. 엔티티 연관관계 매핑(객체 참조 + LAZY), BaseEntity/BaseUpdatableEntity 분리 + Auditing, DTO/(MapStruct), BinaryContent bytes 분리 + BinaryContentStorage 추상화, 페이지네이션(Slice 기본 + 심화: 커서), schema.sql + ddl-auto 정합성, OSIV 비활성화(13기 명시 요구사항).

## 공통 리뷰 테마 (빈도순)

### 1. N+1 / LAZY / fetch join — 전 기수 압도적 1위
- "이런 코드에서 n+1 을 주의하셔야 합니다~!" (8기 #54, **Highjune**)
- "이러면 N+1 문제가 발생할거 같은데요? fetch join이나 entityGraph를 사용하셔야합니다" (13기 #99/#104)
- 해결 전략 선택 기준까지 요구: "ToOne은 EntityGraph, ToMany 컬렉션은 BatchSize + 2-step(IDs → IN). 컬렉션 fetch join은 페이징 충돌·카테시안 곱으로 목록 API에 비추천" (11기 #128/#130)
- "전체 채널 로딩 후 자바에서 필터링 — 쿼리로 가능한 일은 DB에서 끝낸다" (11기 #124)
- "채널마다 전체 메시지 조회 후 stream으로 마지막 메시지 계산 → `findTopByChannel_IdOrderByCreatedAtDesc`로 DB에서 바로" (13기 #101)

### 2. @Transactional 경계 — 누락, readOnly 구분, dirty checking
- "BasicUserService에 전체적으로 @Transactional이 빠져있는것 같네요" (9기 #137)
- "여기에는 왜 @Transactional(readOnly = true) 가 없을까요?" (8기 #59, **Highjune**)
- "클래스 레벨 readOnly=true는 전 메서드에 상속 — 쓰기 메서드가 변경 감지 스냅샷을 못 만들 수 있다" (11기 #128)
- "변경 감지가 자동 UPDATE 실행 — save() 재호출 불필요" (10기 #199) / "update 후 다시 find 할 필요가 있나요?" (8기 #59, **Highjune**)

### 3. Mapper 역할 위반 — Repository 의존 금지 (10~13기 최다 빈출)
- "Mapper는 객체 간 변환만. Repository를 주입받아 쿼리 실행하면 toDto 호출마다 N+1" (10기 #201/#208, 11기 #129/#140, 13기 #101/#104 — 거의 동일 문구로 반복)
- 조회는 Service에서 배치로 미리, Mapper엔 순수 변환만.
- MapStruct가 요구사항인 기수(13기)에선 미사용 자체를 지적: "요구 사항에 mapstruct가 있었던 걸로 아는데 누락된거 같애요"

### 4. OSIV(open-in-view) 비활성화 — 13기 요구사항, 반복 지적
- "osiv는 영속성을 controller에서도 사용하게 해주는 것. 안티패턴이라 잘 사용되지 않습니다. `open-in-view: false`로 꺼줘야" (13기 #99/#104/#113 동일 문구 반복)
- "controller에 entity를 올리는 것 자체가 안티패턴" (13기 #96)

### 5. BinaryContent 분리의 함정 — 고아 파일 + DB/파일 정합성
- "DB 레코드는 cascade로 지워져도 디스크 실제 파일은 남는다" (10기 #184) → "**Storage에 delete(UUID)를 추가**해 함께 정리" (11기 #124)
- "파일 저장 실패해도 DB 트랜잭션은 롤백 안 됨 → 파일 저장을 커밋 이후로 분리" (12기 #99) / "TransactionSynchronizationManager로 롤백과 동기화" (13기 #99)
- bytes 컬럼이 DDL에 잔존하는 반쪽 구현 반복 지적 (8기 #61, 9기 #119/#122)
- 대용량: `getBytes()` 전체 메모리 적재 → OOM, 스트리밍/`transferTo()` 권장 (11기 #128, 13기 #96/#110)

### 6. schema.sql ↔ 엔티티 ↔ ddl-auto 정합성
- "schema.sql로 관리 중이라면 `ddl-auto: validate` 권장 — update는 어긋나도 눈치 못 챔" (11기 #122, 13기 #101)
- "JPA cascade와 DDL ON DELETE는 다른 레이어에서 독립 동작 — 상충하면 예상 못한 결과" (10기 #193)
- "FK 참조 대상 테이블이 파일 하단에 선언 — 빈 DB에서 순서대로 실행하면 FK 오류" (11기 #124)
- "스키마 좋은데요. 인덱스도 한번 추가해보시겠어요?" (8기 #54/#55/#60, **Highjune**/hagyutae)

### 7. 연관관계 설계 — LAZY 기본, cascade 신중, ManyToMany 타당성
- "@ManyToOne에는 기본적으로 안전하게 LAZY" (8기 #54, **Highjune**) / ManyToOne·OneToOne 기본 EAGER 표 제시 후 "실무에서는 lazy로 통일" (13기 #104/#112)
- "이미 업로드된 BinaryContent를 여러 Message가 공유하는 경우가 있을까요?" — Message:BinaryContent는 1:N, `@OneToMany + @JoinTable`이 적절 (8기 #52, 11기 #119/#122/#124)
- "CascadeType.ALL은 과한 전파가 아닌지" (8기 #60) / "삭제는 실무에서 매우 조심스러워 cascade 둘 다 잘 안 쓴다" (11기 #140)
- 컬렉션 setter 공개 + orphanRemoval 조합 위험 — add/remove로 캡슐화 (12기 #95)

### 8. 페이지네이션 — 커서는 (createdAt, id) 복합
- "createdAt 단독 커서는 동시각 데이터 누락/중복 — (createdAt, id) 복합 커서" (9기 #141, 11기 #130, 13기 #96/#102/#110 — 전 기수 동일 지적)
- "Slice는 service에서 소비 종료 — Controller는 Spring Data를 몰라야" (13기 #99)
- 기본 page size 50 요구사항 + `@PageableDefault` (13기 #99/#104/#113)
- 제네릭 PageResponse 공통화는 칭찬 패턴 (9기 #133/#136/#143)

### 9. 예외 처리
- "IllegalStateException보다 커스텀 에러 추천" (8기 #54/#56, **Highjune**) / "NoSuchElementException은 커스텀이 아닌데 현업에서는 커스텀을 쓰는 게 좋다" (13기 #104)
- "RuntimeException은 의미가 너무 광범위 — 사용 금지" (8기 #61) / printStackTrace 금지 (9기 #124/#128)
- 핸들러가 계산한 status를 안 쓰고 항상 400 반환하는 버그류 (13기 #102)

### 10. 엔티티 노출 금지·DTO 규율·검증
- "엔티티 그대로 노출 → OSIV off 시 LazyInitializationException, 순환 참조, 민감정보" (11기 #119, 12기 #101)
- "@NotBlank는 CharSequence 전용 — UUID/Instant엔 @NotNull" (10기 #184), `@NoArgsConstructor(access = PROTECTED)` (10기 #208, 11기 #129)

### 11. Auditing
- "@EnableJpaAuditing 없으면 null 저장" (10기 #204) / "@CreatedDate + @PrePersist 수동 설정 중복 — 하나로" (10기 #182) / "메인 클래스에 붙이면 슬라이스 테스트 깨짐 — JpaConfig 분리" (10기 #186)
- "채워지는 시점은 persist/update 후라는 걸 정확히 알아야" (13기 #96/#99)

### 12. 보안·운영·Git 위생
- 평문 비밀번호 비교/저장, DB 자격증명 하드코딩 → 환경변수 (9기 #125/#141, 10기 #199/#201)
- Content-Disposition 파일명 path traversal sanitize (11기 #128)
- `.idea/`, `uploads/` 실파일, `.ser`, 로그 파일 커밋 — "git history에서도 제거" (8기 #59, 9기 #124/#139)

## 리뷰 스타일 참고
- **Highjune(8기)**: APPROVED 위주 + 실무 코멘트 ("실무에서 findAll 쓰는 경우 거의 없다", 미사용 import 정리 습관, 축약 변수명 지양)
- hagyutae(8/9/12기): `[REQUIRED]/[SUGGEST]/[Q]/[GOOD]` 라벨 + "조사해서 답글로 남겨주세요" 과제형
- the-eris-net(13기): P1~P5 우선순위 라벨 (P1=요구사항 위반)
- 총평 공통 구조: JPA 개념 이해 칭찬 → "입력→저장→조회→응답 전체 흐름 끝까지 검증" → "학습용 구현에서 운영 가능한 구현으로"
