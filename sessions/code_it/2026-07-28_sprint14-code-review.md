# 세션 — Code it 스프린트14 코드 리뷰 (2026-07-28)

## 목적
Code it(코드잇) 부트캠프 스프린트 미션 PR을 리뷰. Claude가 리뷰할 항목을 도출해 사용자(멘토, Highjune)에게 보여주고, 사용자가 직접 GitHub에 리뷰를 남기는 방식. **Claude는 GitHub에 직접 코멘트/리뷰를 달지 않음.**

## 프로젝트 구조
- 리뷰 결과 저장 경로: `source/projects/code_it/sprint14/code_review/sprint2/{학생이름}/review.md`
- 대상 저장소: `codeit-bootcamp-spring/14-sprint-mission` (Discodeit 콘솔 앱 미션)

## 리뷰한 PR

### PR #10 — [김민재] sprint2 (mjdevkim)
- 저장: `source/projects/code_it/sprint14/code_review/sprint2/김민재/review.md`
- 핵심 지적:
  - 🔴 `FileChannel/FileMessageRepository`가 못 찾을 때 `USER_NOT_FOUND` 오용 (copy-paste)
  - 🔴 기본 실행(JCF) 경로에서 `NoSuchElementException`(message=null) → 안내 문구 대신 null 출력
  - 🟡 `service/jcf/*`, `service/file/*` 6개 dead code (ServiceFactory가 항상 Basic만 생성)
  - 🟡 Singleton(getInstance) + 생성자 주입 충돌
  - 🟡 serialVersionUID 없음 / `.ser` 파일 git 커밋
  - 멘티 질문 3개 답변 작성 (DTO 세분화 / File IO 효율 / Controller vs Service)
- 멘토 리뷰 확인 결과: 형은 FileMessageRepository·JCFUserRepository·DTO final 등 5개 코멘트. 누락분(FileChannelRepository 동일 버그, dead code, 멘티 질문 미응답 등) 보강 제안함.

### PR #12 — [이은솔] 스프린트2 (EUNSOLY)
- 저장: `source/projects/code_it/sprint14/code_review/sprint2/이은솔/review.md`
- 특징: DTO 없음(엔티티 전 계층 노출), 구(JCF/File Service) + 신(Basic+Repository) 3중 공존
- 핵심 지적:
  - 🔴 `findByChannelIdAndUserId` 파라미터 순서 인터페이스/구현/호출부 불일치 → 오답 (JCF에서만 우연히 상쇄)
  - 🟡 `JavaFileIOApplication` 배선 오류(messageFileService에 JCF 서비스 주입) + `BasicMessageService.save` 검증 유실 (두 버그가 서로 가림)
  - 🟡 `static Map data` 상태 공유(숨은 전역) — JCF 레포 3개 + JCFMessageService
  - 🟡 `service/file/*` dead code + `load()/fileSave()` 6곳 복붙(DRY 위반, 이미 예외 처리가 어긋남)
  - 🟡 예외/반환 정책 혼재(repo null / service throw, bare RuntimeException)
  - 멘티 질문 4개 답변 작성 (static 싱글톤 / BaseEntity abstract / File 효율 / MVC·DTO 변환 위치)
- 멘토 리뷰 확인 결과: 형은 순서 버그·배선·변수명·예외 체이닝 등 7개 코멘트. 누락분(검증 유실, static 공유, dead code, 멘티 질문 4개 미응답) 보강 제안함.

## 이번 세션에서 깊게 다룬 교육 주제 (재사용 가능)
- **예외 체이닝**: 감싸서 다시 던질 땐 원인(`e`) 항상 보존. 메시지=사람용/원인=디버깅용, 역할이 달라 둘 다 필요. `ClassNotFoundException`도 예외 아님. 멀티 catch(`IOException | ClassNotFoundException`)로 통일. `FileNotFoundException`은 정상 흐름이라 삼켜도 됨(단 IOException 하위이므로 위쪽 catch에).
- **DRY / Single Source of Truth**: 직렬화 로직을 `AbstractFileRepository<T>` 등 한 곳으로 추출.
- **싱글턴 vs DI**: static 필드 공유는 싱글턴 아니라 전역변수. 유일성은 객체가 아니라 조립 지점(팩토리/컨테이너)이 보장. = Spring 싱글톤 빈 원리.
- **파일 vs 메모리 접근 비용**: 메모리(RAM)는 원본이라 접근≈0, 파일은 디스크 I/O + 직렬화/역직렬화라 비쌈. → 1회 로드 + 시점 flush, 내구성 vs 성능 트레이드오프.
- **RAM(메모리) vs 디스크(저장장치)**: 휘발성·빠름 vs 비휘발성·느림. 영속화의 이유.

## 다음에 이어서 할 수 있는 것
- 도출한 리뷰 항목을 라인별 PR 코멘트 문구로 변환
- 남은 학생 PR 리뷰 (동일 프로세스)
