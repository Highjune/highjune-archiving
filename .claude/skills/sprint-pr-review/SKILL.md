---
name: sprint-pr-review
description: Use when reviewing a codeit-bootcamp-spring/14-sprint-mission student PR (스프린트 미션 코드 리뷰) — full workflow including past-cohort (9~13기) mentor review reference
---

# 스프린트 미션 PR 리뷰 워크플로우

사용자(Highjune)는 Code it 부트캠프 14기 멘토로서 `codeit-bootcamp-spring/14-sprint-mission`의 학생 PR을 리뷰한다.

## 절대 규칙

- **GitHub에 직접 코멘트/리뷰를 게시하지 않는다.** 분석 결과와 복붙용 문안만 제시하고, 게시는 사용자가 직접 한다.
- 모든 리뷰는 **파일 저장 + 채팅 요약 둘 다** 제공한다.
- 파일 경로: `source/projects/code_it/sprint14/code_review/sprint{N}/{학생이름}/review-pr{번호}.md`

## 과거 기수 리뷰 참고 (필수 단계)

같은 과제는 **8~13기**(`codeit-bootcamp-spring/{8..13}-sprint-mission`)에서도 진행됐고, 그때 멘토들의 리뷰가 좋은 참고 자료다. **8기는 Highjune 본인이 멘토(리뷰어)로 활동**했으므로(참가자 아님) 본인 과거 리뷰 스타일·지적 패턴을 그대로 참고할 수 있다.

1. 리뷰 시작 전 `source/projects/code_it/sprint14/code_review/reference/sprint{N}-past-cohort-review-insights.md` 존재 여부 확인.
2. **있으면** 그 문서를 읽고 리뷰에 반영한다 (재수집 금지 — 이미 캐시됨).
3. **없으면** 기수별 병렬 백그라운드 에이전트(gh CLI, 읽기 전용; 예: 8-9기/10-11기/12-13기로 2기수씩 3에이전트)로 해당 스프린트 PR들의 멘토 인라인 코멘트+리뷰 총평을 수집·중복 제거하고, 그 결과를 위 경로에 통합 문서로 저장한 뒤 리뷰에 반영한다. 검색은 `gh pr list --search "sprint{N} in:title"` + 변형("미션 {N}", "스프린트 미션 {N}").
4. 리뷰 문안에서 과거 기수 근거는 "N기 멘토들도 공통적으로 권장한 패턴" 식으로 자연스럽게 인용한다 (대표 예: Swagger 어노테이션 XxxApi 인터페이스 분리).
- 현재 캐시: sprint5, 6, 7, 8 완료 (`sprint{5,6,7,8}-past-cohort-review-insights.md`). sprint7 캐시엔 8기 Highjune 본인의 테스트 철학 총평(#68 등), sprint8 캐시엔 본인 시그니처(아키텍처 다이어그램 숙제, @ConfigurationProperties, 테스트 멱등성)가 들어 있어 재사용 가치 높음.

## 리뷰 절차

1. `gh pr view {n} --repo codeit-bootcamp-spring/14-sprint-mission --json ...`으로 메타데이터 확인. **base 브랜치가 `main`이면 머지 금지 경고 + 학생 브랜치로 변경 안내** (반복되는 프로세스 이슈).
2. `gh pr diff`로 diff를 스크래치패드에 받아 전체 분석.
3. 모든 코멘트에 파일:라인 위치 지정. 라인은 head 브랜치 raw 파일(`raw.githubusercontent.com/{fork}/{branch}/...`)을 curl + grep -n으로 **반드시 검증**.
4. 심각도 분류: 🔴 실질 버그/스펙 불일치 → 🟡 Major(설계·요구사항) → 🔵 Minor(네이밍·스타일). 칭찬 포인트도 반드시 수집.
5. 리뷰 파일 저장 후, 채팅에 요약 + 복붙용 코멘트 문안 제공.

## 문안 톤

- 복붙용 문안: `>`/`|` 접두사 없는 평문, 경어체, 따뜻하고 격려하는 톤. 라벨이 매운맛🔥이면 직설 허용.
- **사람이 쓴 티 내기 (항상 적용)**: 너무 완벽한 문어체 금지. 경어는 유지하되 ①구어체 어미 섞기("~더라구요", "~거에요", "~것 같아요", "~해보시면 좋을듯요") ②가벼운 오타·띄어쓰기 실수를 전체에서 2~4곳만 자연스럽게(예: "되요/돼요" 혼용, "할수 있어요", "그런것") ③ㅎㅎ/! 같은 가벼운 감탄 가끔 ④문장 길이 들쭉날쭉하게. 단, 클래스명·라인·설정키·명령어 등 기술 용어에는 절대 오타 금지(복붙 시 오해 유발). 모든 코멘트가 같은 템플릿 구조(결론→근거→근거)로 균일해 보이지 않게 일부는 질문으로, 일부는 감상으로 시작해도 됨 — 두괄식 원칙은 유지하되 기계적으로 똑같지 않게.
- 라벨이 미완성🛠️이면: 격려 톤 + 복구 로드맵 중심으로 구성.
- 내부 평가(총평) 요청 시: 3인칭 서술, 2문단(강점 → 개선 테마), 격려 마무리 불필요.

## 참고

- 프로젝트: Discodeit (Discord 클론, User/Channel/Message/ReadStatus/UserStatus/BinaryContent)
- 미션5 스펙 키 포인트: 자원 중심 URL, camelCase 필드(스펙 우선), @RequestPart multipart, 201/204, springdoc 문서화.
