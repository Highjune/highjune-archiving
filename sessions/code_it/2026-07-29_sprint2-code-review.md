# 세션 — Code it 스프린트14 sprint2 코드 리뷰 (2026-07-29)

## 개요
`codeit-bootcamp-spring/14-sprint-mission` 학생 PR 리뷰 이어감. Claude는 리뷰 항목만 도출해 사용자(멘토 Highjune)에게 보여주고, 사용자가 직접 GitHub에 리뷰. 매 건 `review.md` 저장 + 채팅 요약 병행.

## 리뷰한 PR (sprint2 중심)

| PR | 학생 | 저장 | 핵심 |
|---|---|---|---|
| #13 | 신상엽 (Smil-limS) | `sprint2/신상엽/review.md` | 완성도 최상위. BaseEntity abstract·AbstractFileRepository(DRY)·검증·예외 상수화. 🔴 File 레포 예외 삼킴(데이터 유실), update null 덮어쓰기, 싱글턴 스레드 비안전 |
| #20 | 박수현 (shp02x2) | `sprint2/박수현/review.md` | 1차만. 엔티티 일관성·인터페이스 분리·Map<UUID,T> 좋음. getInstance 스레드 안전성, 없는 id 정책, 검증이 다음 스텝 |
| #22 | 김지현 (pengji-dev) | `sprint2/김지현/review.md` | 구조 탄탄(Repository 주입, Optional 예외). 🔴 serialVersionID 오타(→UID), update 시 updatedAt 미갱신(setter 사용). JCF/File 서비스 완전 중복 |
| #24 | 조예준 (joyejun) | `sprint2/조예준/review.md` | 2-1 초기. main 부재로 실행 불가, messageRead(Integer)·get(chennel) 등 Map key 타입 실수로 조회 항상 실패 |
| #23 | 이현석 (giseo1107) | `sprint2/이현석/review.md` | 2-1인데 main으로 CRUD 직접 실행·검증(태도 최고). Channel.update 파라미터 오타(번호 미갱신), findAll 내부 리스트 노출, List→Map |

(앞 세션에서 완료: #10 김민재, #12 이은솔 — `2026-07-28_...` 로그 참고. sprint1은 #2 조준희.)

## 멘토 리뷰 확인/보강 흐름
- #20: 형이 없는 id null·검증 커버. 추가 제안 = 싱글턴 힌트 + 검증이 채널/메시지에도 적용 + 칭찬.
- #23: 형이 Channel 오타·findAll 방어·List→Map + 칭찬(실행하며 개발)까지 완비. 추가는 불필요 수준(Message update 반환 불일치, .idea 커밋 정도).

## 이번 세션 심화 설명 주제 (재사용)
- **Map key 타입 함정**: `get/containsKey/remove(Object)`는 타입을 안 막아(넣기 put/add는 K로 막음) 조회 key 타입 실수가 컴파일에 안 잡히고 런타임에 "항상 못 찾음". Map/Collection 인터페이스 규약(HashMap 특성 아님).
- **serialVersionUID vs serialVersionID 오타**: 이름 틀리면 직렬화 버전 필드로 인식 못 함. 다만 영향은 잠재적 → 🔵 수준(치명 아님). updatedAt 미갱신이 더 중요.
- **updatedAt 미갱신**: 엔티티 update() 대신 서비스가 setter 호출 → updatedAt 안 바뀜. 해결: 서비스에서 엔티티 update() 호출, @Setter 제거.

## 종합 평가 (경어체·긍정 부각, 각 150자 이내) — 8명분 작성해 전달함
김민재/이은솔/신상엽/박수현/김지현/조예준/이현석 + 조준희(sprint1).

## 다음
남은 학생 PR 있으면 동일 방식으로 이어가기.
