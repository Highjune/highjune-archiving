# 세션 — Code it 스프린트14 sprint3 코드 리뷰 (2026-08-10 ~ 08-12)

## 개요
`codeit-bootcamp-spring/14-sprint-mission` 학생 PR 리뷰(sprint3 중심). Claude가 리뷰 항목만 도출해 사용자(멘토 Highjune)에게 보여주고, 사용자가 GitHub에 직접 리뷰. 매 건 `review-pr{번호}.md` 저장 + 채팅 요약. GitHub에는 직접 안 씀.

## 리뷰한 PR

| PR | 학생 | 저장 | 핵심 |
|---|---|---|---|
| #32 | 이은솔 (EUNSOLY) | `sprint3/이은솔/review-pr32.md` | Spring 전환 최상위. @ConditionalOnProperty 구현체 스위칭, DI, Optional, DTO. 질문3(@Value/@PostConstruct, MultipartFile, Repository직접주입 vs Service재사용) 답변 |
| #35 | 김민재 (mjdevkim) | `sprint3/김민재/review-pr35.md` | Application/Domain 2계층 + 수동 보상 롤백(addSuppressed). 질문3(긴 AppService→트랜잭션 부재/성공·보상 분리, 예외 계층·분류, yaml 리소스) |
| #36 | 조준희 (Joonehee-JO) | `sprint3/조준희/review-pr36.md` | s1/s2 계층분리 성장 but sprint1 잔재 대량 dead code. 질문3(계층 언제 나눌지=복잡도, 검증위치=경계vs서비스, null/디폴트) |
| #39 | 김지현 (pengji-dev) | (스켈레톤이라 파일 저장 안 함) | Spring Initializr 초기세팅뿐. thymeleaf-test(없는 의존성), discodeit/ 중첩폴더, properties→yaml. 격려+로드맵 위주 |
| #44/#45 | 신상엽 (Smil-limS) | `sprint3/신상엽/review-pr44.md` | 구조 최상위. 🔴실수성 버그3(비번=이메일 create:35, update 프로필삭제 getId→getProfileId:82, 채널삭제 deleteById→deleteByChannelId:100), @Primary→@ConditionalOnProperty, PRIVATE수정 IllegalState, findAll orElse(null). #45는 #44와 동일 head(중복 PR) |
| #46 | 이현석 (giseo1107) | `sprint2/이현석/review-pr46.md` | sprint2-2 미완성. 🔴 id에 transient(역직렬화시 null), Repository 구현체 부재, UserRepository.save 컴파일에러. 격려+로드맵 |
| #49 | 조예준 (joyejun) | `sprint3/조예준/review-pr49.md` | sprint2 대비 성장 큼(잔재 정리+정석 계층). 🔴빌드 깨짐 3건: package discodeit"3" 오타(컴파일에러), gradle-wrapper.properties→.yaml rename(gradlew 불능), application.yaml이 src/resources/(Spring 못읽음). JCF 레포 @Repository 누락(붙이면 빈충돌→@ConditionalOnProperty 세트로), .gitignore `.DS_Store.idea` 합쳐짐→.DS_Store 12개+.ser 커밋, DiscodeitApplication 셋업 전부 주석. 신규 도메인 미착수(진행 중) |

## 이번 세션 심화 설명 주제 (재사용)
- **@Value 주입 타이밍**: 빈 생성 ① 생성자 → ② 필드주입 → ③ @PostConstruct. 필드주입은 생성자에서 null → @PostConstruct 우회. 생성자 파라미터 주입이 정석(final·테스트 쉬움). 추상클래스+상속이면 @ConfigurationProperties로.
- **checked→unchecked 예외 변환**: 감싸 다시 던지는 이유(계층 오염 방지, 저수준→의미있는 예외 번역, 위로 전파). 원인 e 항상 보존.
- **표준 예외 3종**: 조회실패=NoSuchElementException(java.util), 잘못된인자/중복=IllegalArgumentException, 상태위반=IllegalStateException. "JDK 표준 예외"라 부름. 커스텀은 나중.
- **@ConditionalOnProperty**: name=yaml 키 경로(discodeit.repository.type), havingValue=그 키의 값. matchIfMissing=키 없을 때 기본. yaml 한 줄로 구현체 스위칭.
- **transient**: 직렬화 제외 표시 → 역직렬화시 null(객체)/0(숫자). id에 붙이면 역직렬화 후 findById 실패. 파생값·비번·직렬화불가 객체에만.
- **Map key 타입 함정(get/containsKey는 Object)**, **serialVersionUID vs serialVersionID 오타**, **findAll orElseThrow → 목록 전체 실패 방어(단건은 예외 유지)** 는 여러 학생 공통 패턴.
- **Repository 직접주입 vs Service 재사용**: 순환참조 방지로 Repository 직접이 맞음. 검증 중복은 Service 상호주입 말고 Validator 컴포넌트 추출.
- **Application Service가 길어짐**: 트랜잭션 부재로 수동 롤백 탓. 성공/보상 경로 메서드 분리 + 다음 스프린트 @Transactional로 대체.

## 종합평가 (2026-08-12, 7명 전원 완료)

담당 멘티 7명 전원 종합평가 작성 완료. 형식: 짧게, 경어체, 전반적 톤(기술 항목 나열 X — "그런식으로 구체적으로 말고" 피드백 반영), 강점 인정 → 개선 방향 → 격려.

| 학생 | 평가 축 (강점 / 개선점) |
|---|---|
| 김민재 | 설계 고민 깊이 최상위 / 작은 마무리(dead code·디테일)와 "단계에 맞는 적정선" 감각 |
| 이은솔 | 꼼꼼함+완성도 최상위, 질문 수준 높음 / 이미 맞는 판단에 확신 갖기(트레이드오프 스스로 정리) |
| 신상엽 | 구조·완성도 최상위 / 실행해서 확인하는 검증 습관, 복붙 자리 의심 |
| 조준희 | 성장 폭 최대, 설계 본질 고민 시작 / 옛 코드 정리 습관("삭제까지가 완료"), 검증 책임 위치 정하기 |
| 조예준 | 피드백 반영하며 성장 / 제출 전 빌드·실행 확인 루틴, 환경설정 파일 조심성 |
| 김지현 | 꾸준함, 피드백 반영 태도 / 작게라도 완성하는 경험 우선, 중간 공유 자주 |
| 이현석 | 구조 방향은 정확, 솔직한 제출 태도 / 좁게라도 돌아가는 한 조각 완성(User 하나 끝까지), 일찍 질문하기 |

## sprint3 최종 현황 (멘티 7명)

- sprint3 제출 6명: 이은솔 #32, 김민재 #35, 조준희 #36, 김지현 #39(스켈레톤), 신상엽 #44/#45(중복), 조예준 #49(기본까지, 심화·신규도메인 진행 중)
- 미제출 1명: 이현석 — 최신이 #46(sprint2-2 미완성), 사실상 한 스프린트 뒤. sprint3 올라오면 리뷰 예정.
- 리뷰 + 종합평가 7명 전원 누락 없음.

## 파일명 규칙 (2026-08-10 확립)
`review-pr{번호}.md` — 사용자가 PR 번호로 바로 찾기 위함.

## 다음
- 이현석님 sprint3 PR 올라오면 리뷰.
- 조예준님 #49 수정(빌드 복구·심화·신규 도메인) 커밋 올라오면 재확인.
