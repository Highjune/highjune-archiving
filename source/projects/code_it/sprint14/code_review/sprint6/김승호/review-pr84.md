# 코드 리뷰 — [김승호] 스프린트 미션 6 (PR #84)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/84
- **작성자**: WinLike-dev (김승호), head `WinLike-dev:mission6` → base `김승호` ✅
- **규모**: +1592 / −18265, 100 files (삭제 대부분은 기존 헥사고날 구조·newman 리포트·구 정적 자산)
- **라벨**: 최상급🏆 — 🔴 없음. 개선 제안 🟡 3건 + 토론 [Q] 위주
- **참고**: 8~13기 인사이트 (`reference/sprint6-past-cohort-review-insights.md`)

> diff 전체 확인 + 주요 소스 41개 파일 head raw 전문 검토, 라인 검증 완료.

---

## 총평 — 과거 기수 멘토들의 "심화 권장사항"을 거의 전부 선반영한 제출물. sprint4 #63에 이어 이번에도 기수 최상위

**구조 결정부터 훌륭:**
- 기존 헥사고날(adapter/port/event) 구조를 스스로 걷어내고 도메인별 layered(controller/service/repository/entity/mapper)로 재편 — 과제 규모에 맞는 적정 복잡도로 되돌리는 판단력. 이벤트 기반 삭제 전파도 서비스 직접 오케스트레이션으로 단순화.
- PR 본문에 연관관계 표(주인/방향/부모-자식/cascade 기준) + "Entity 노출 문제 5가지"를 실제 부딪힌 순서로 정리 — 문서 자체가 모범답안 수준.
- OpenAPI 문서를 제공 스펙 v1.1과 필드 단위 대조(oasdiff)했다고 명시 → 실제 코드 확인 결과 전 DTO 스펙 일치.

**과거 기수 멘토 지적 사항 선반영 목록 (전부 코드로 확인):**
| 과거 기수 지적 | 이 PR |
|---|---|
| OSIV off (13기 요구) | `application.yml:28` open-in-view: false + 트랜잭션 안에서 지연 로딩 종료 |
| ddl-auto validate (11기 #122) | `application.yml:26` validate + create if not exists 멱등 스키마 |
| DB 자격증명 하드코딩 금지 (9~10기) | `.env` 분리 + `.env.example` 제공 |
| Mapper는 변환만 (10~13기 최다) | MapStruct `unmappedTargetPolicy = ERROR`, Repository 의존 없음 |
| N+1 — 배치/IN 조회 (전 기수 1위) | `@EntityGraph`, projection 인터페이스 IN 조회, `default_batch_fetch_size: 100` |
| 파일-트랜잭션 정합성 (12기 #99, 13기 #99 심화) | `BinaryContentFileManager` — TransactionSynchronization으로 롤백 시 저장 파일 정리, 삭제는 afterCommit으로 지연 |
| Storage delete 부재 → 고아 파일 (10~11기) | `BinaryContentStorage.delete` 추가 + 교체/삭제 흐름에서 정리 |
| 읽기전용 트랜잭션 쓰기 참여 함정 (11기 #128) | `TransactionConfig` — setValidateExistingTransaction(true)로 기동 후 첫 호출에서 예외로 노출 |
| ManyToMany 타당성 (8기 #52 본인 질문) | `@OneToMany + @JoinTable` + attachment_id UK — "첨부는 메시지 하나에만" 모델링 정확 |
| 인덱스 (8기 본인 지적) | `schema.sql:79-83` — (channel_id, created_at desc) 등 조회 경로 기반 |
| 벌크 연산 | ReadStatus 벌크 DELETE, 작성자 detach 벌크 UPDATE (flushAutomatically) |

**그 외 디테일**: 임시파일 + ATOMIC_MOVE로 반쯤 쓰인 파일 방지(`LocalBinaryContentStorage.put`), ContentDisposition UTF-8 파일명, 잘못된 contentType → octet-stream 폴백, `getReferenceById`로 불필요 SELECT 회피, exists 쿼리로 존재만 확인, GlobalExceptionHandler의 ErrorResponse 위임(405/415 상태 보존) + 내부 메시지 은닉, 컴팩트 생성자 불변 복사, 매퍼/핸들러/엔티티 테스트 유지.

---

## 🟡 개선 제안 (버그 아님)

### 1. 채널 삭제 시 메시지 전량 로드 — `ChannelServiceImpl.java:160-168` (deleteMessages)
`messageRepository.findAllByChannelId(channelId)`로 **채널의 모든 메시지 엔티티를 메모리에 올린 뒤 건별 삭제**. ReadStatus는 벌크 DELETE로 처리하면서(`:154`) 메시지만 로드 방식이라 비대칭. 메시지 10만 건 채널이면 메모리 + 삭제 쿼리가 그만큼 발생.
- 첨부 파일 정리 때문에 로드가 필요했던 것으로 보이는데, **첨부 id만 projection으로 뽑고**(조인테이블 기준 쿼리) → 조인테이블/메시지/binary_contents를 벌크 DELETE 3방으로 전환 가능. cascade에 의존하지 않는 순서 제어는 이미 하고 있으니 자연스러운 연장.

### 2. Slice가 서비스 계약 밖으로 누출 — `MessageControllerService.java:21`
다른 경계는 전부 Command/Result로 감쌌는데 여기만 `Slice<MessageResult>`가 인터페이스 시그니처에 노출. 13기 멘토 지적("Slice는 service에서 사용이 끝나고, Controller는 Spring Data에 대해서는 몰라야")과 정확히 겹치는 지점. 서비스가 `PageResponse<MessageResult>`(또는 자체 SliceResult)를 반환하면 본인이 세운 "REST 계층은 변환만" 규칙과도 맞아떨어짐.

### 3. [Q] 벌크 연산의 사각지대 인지 확인 — `MessageRepository.java:47-49` (detachAuthor)
벌크 UPDATE는 `@PreUpdate`를 우회하므로 작성자가 비워져도 **updatedAt이 갱신되지 않고**, 영속성 컨텍스트의 기존 엔티티에도 반영되지 않음(`clearAutomatically` 미설정). 현재 삭제 흐름에서는 메시지가 컨텍스트에 로드돼 있지 않아 실해는 없음 — "작성자 detach는 내용 수정이 아니므로 updatedAt 미갱신이 맞다"고 판단했는지, 아니면 놓쳤는지 확인 겸 질문.

## 🔵 Minor / 토론

### 4. getReferenceById 최적화가 응답 조립에서 상쇄됨 — `MessageServiceImpl.java:56-63, 67`
"SELECT 없이 프록시 참조만" 주석대로 저장은 아꼈지만, 바로 다음 `MessageResult.from(created)`가 `UserResult.from(author)`를 부르며 프록시 초기화 + status + profile을 **개별 쿼리 3번**으로 로딩. 생성 응답에 author 전체가 필요하다면 처음부터 EntityGraph findById 1방이 쿼리 수로는 이득일 수 있음. (트레이드오프 인지 확인용)

### 5. byte[] 전체 메모리 적재 — `UserRestMapper.java:54` (getBytes), `LocalBinaryContentStorage.java:50-57`
max-file-size 10MB 제한이 있어 당장 문제는 없음. 다음 단계로는 `transferTo`/InputStream 스트리밍 (11기 멘토 P5 권장). 다운로드는 이미 InputStreamResource 스트리밍이라 업로드 쪽만 남음.

### 6. Auditing 대신 @PrePersist/@PreUpdate — `BaseEntity.java:29-32`, `BaseUpdatableEntity.java:23-33`
기능 동일 + "하위 오버라이드 방지 위해 private" 주석까지 정확. 다만 스펙이 Spring Data Auditing(@CreatedDate)을 명시했다면 리뷰 때 선택 근거를 물을 수 있으니 답변 준비. 테스트에서 시각 주입이 필요해지면 Auditing + DateTimeProvider 쪽이 유리.

### 7. [Q] 첨부만 있는 메시지 — `Message.java:65, 83-88`
content가 non-blank 필수라 **첨부파일만 보내는 메시지가 400**. 실제 디스코드는 첨부만 전송 가능. 제공 FE/스펙 v1.1에서 이 케이스가 허용되는지 확인해봤는지? (허용이면 content nullable + "content나 첨부 중 하나는 필수"로 완화)

---

## 다음 스텝 제안 (심화)
1. 커서 기반 페이지네이션 — (createdAt, id) 복합 커서 (전 기수 공통: createdAt 단독은 동시각 누락)
2. 채널/유저 삭제의 벌크화 (위 🟡1) + 대량 삭제는 배치/이벤트로 미루는 설계 (13기 #96)
3. 비밀번호 해싱 — 다음 스프린트 Security 예고
