# 코드 리뷰 — 조준희 sprint3 (PR #36)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/36
- **작성자**: Joonehee-JO (조준희)
- **범위**: Spring 전환 + 신규 도메인 + 서비스 계층 분리(s1/s2) + Map(JCF) 레포 재구현 + DTO
- **규모**: +1850 / -919, 75 files, 56 commits
- **비고**: sprint1(#2)이 러프했던 학생 — 이번에 계층 분리까지 시도하며 성장 폭이 큼

> 확인한 핵심 파일: `ChannelServiceApp`(s1), `service/channel/ChannelServiceImpl`(s2), `DiscodeitApplication`, 전체 파일 목록. 나머지는 목록으로 파악.

---

## 총평 — 성장 폭이 큼, 새 구조 자체는 좋음 👍

- **서비스 계층 분리(s1/s2 = Application/Domain)**: `ChannelServiceApp`(여러 도메인 조합·흐름 제어)와 `service/channel/ChannelServiceImpl`(단일 도메인 검증·CRUD)를 나눈 게 김민재님 PR과 같은 정석 구조예요. 특히 **채널/메시지만 s1을 두고 유저는 안 나눈 판단이 합리적**입니다(질문 답변 참고).
- **Map(JCF) 레포로 재구현 + Spring DI**(`DiscodeitApplication`에서 `context.getBean`), DTO(`web/controller/dto`) 도입, `ChannelServiceImpl`이 `Optional.orElseThrow`로 조회 실패 처리 — 방향 다 좋아요.
- `findChannel`에서 채널 타입에 따라 분기하고 마지막 메시지 시각/유저 목록을 조립하는 흐름도 잘 짜였어요.

아래는 개선 포인트인데, **1번(잔재 정리)이 이 PR에서 가장 큽니다.**

---

## 🔴 1. sprint1 잔재가 대량으로 남아 있음 (절반 가까이 dead code)

새 구조(`repository/map/*`, `service/channel|message|user|...`, `ChannelServiceApp` 등)를 만들면서, **sprint1의 옛 코드를 지우지 않고 그대로 두셨어요.** `DiscodeitApplication`은 새 구조만 쓰므로 아래는 전부 죽은 코드예요:

- `repository/file/*` — `AbstractCrudRepository`, `Channel/BasicChannelCrudRepositoryImpl`, `message/`, `user/`, `FileCrudRepository`
- `service/file/*` — `BasicChannelServiceImpl`, `BasicMessageServiceImpl`, `BasicUserServiceImpl`, `FileChannelService`
- `sprint0/MainApplication`
- `global/config/Config`, `global/exception/CustomErrorCode`
- 위를 테스트하는 `test/.../repository/file/*` 테스트들

sprint1 리뷰에서도 "두 구현 트리를 하나로 정리하라"고 짚었던 부분인데 아직 남아 있어요. 이걸 지우면 **파일 수가 확 줄고, 어떤 게 진짜 코드인지 한눈에** 들어옵니다. 지금은 리뷰어/동료가 "file 레포가 진짜인가, map이 진짜인가?"부터 헷갈려요. → **옛 `file/`, `sprint0/`, `global/`, `service/file/` 삭제 권장.** (git이 이력을 남기니 지워도 됩니다.)

---

## 🟡 2. s1 서비스의 위치·네이밍이 s2와 섞여 혼란

- s1(`ChannelServiceApp`, `MessageServiceApp`, `ReadStatusServiceApp`)이 **`service/` 최상위**에 있고, s2 인터페이스(`service/channel/ChannelService`)는 하위 패키지에 있어요. 두 계층이 같은 트리에 섞여 있어 구분이 어렵습니다. **s1을 `service/application/` 같은 별도 패키지로 분리**하면 "s1/s2"가 위치만 봐도 구분돼요.
- **`service/MessageService.java`(최상위)** 와 **`service/message/MessageService.java`(하위)** 가 이름이 같아요. 같은 이름 두 개는 매우 혼란스러우니(무엇이 s1이고 s2인지) 정리가 필요합니다 — 최상위 쪽이 잔재라면 삭제, 아니면 이름 구분.
- 접미사 `~App`보다 `~ApplicationService`가 더 관례적이에요(선택).

## 🟡 3. s2에 null 검증이 과하게 반복됨 (질문 1-c와 연결)

`ChannelServiceImpl`의 거의 모든 메서드가 `Objects.isNull(...) → throw IllegalArgumentException("널입니다")`로 시작해요. 준희님도 질문에서 "널 검증을 다 넣었는데 어떻게 null이 들어오지?"를 고민하셨죠.
- 답변에서 말한 대로 **형식·null 검증은 경계(컨트롤러/DTO), 도메인 규칙은 서비스**로 나누면, s2 전반의 null 검증 상당수를 덜어낼 수 있어요. 특히 `makeChannel(channel)`의 null 체크는, 앱서비스가 항상 `Channel.init(...)`으로 만들어 넘기니 실질적으로 올 일이 없어요.

## 🟡 4. 예외 타입/메시지 일관성

전부 `IllegalArgumentException`인데 "널입니다"와 "존재하지 않습니다"가 섞여 있어요. 표준 예외로 성격을 맞추면 더 명확해져요:
- 조회 실패("존재하지 않습니다") → `NoSuchElementException`
- 잘못된 인자(널/형식) → `IllegalArgumentException`
- 상태 위반("프라이빗은 수정 불가") → `IllegalStateException`

(+ `ChannelServiceImpl.makeChannel`에 `//todo` 주석이 남아 있어요 — 정리 or 내용 채우기.)

---

## 🔵 Minor / Nit

- **테스트 파일이 폴더와 내용이 뒤바뀜(sprint1과 동일)**: `test/.../repository/file/Channel/BasicUserCrudRepositoryImplTest`(Channel 폴더인데 User 테스트), `test/.../repository/file/user/BasicChannelCrudRepositoryImplTest`(user 폴더인데 Channel 테스트). 게다가 이 테스트들은 1번의 dead code(`file/` 레포)를 대상으로 해요 → 잔재와 함께 정리.
- **오타/변수명**: `makedChannel`(→`madeChannel`/`createdChannel`), `userIdlist`(→`userIdList`).
- **커밋 56개** — 커밋 단위가 꽤 잘게 쪼개진 듯. sprint1 때 궁금해하셨던 커밋 컨벤션(한 커밋=한 논리적 변경)을 의식해보면 좋아요.

---

## 정리 (우선순위)

| 순위 | 항목 |
|---|---|
| 1 | 🔴 sprint1 잔재 삭제 (file/·sprint0/·global/·service/file/·옛 테스트) — 절반이 dead code |
| 2 | s1 위치·네이밍 정리 (application 패키지 분리, 최상위 MessageService 중복 해소) |
| 3 | s2 null 검증 과다 → 경계로 이관 (질문 1-c) |
| 4 | 예외 표준화(NoSuchElement/IllegalArgument/IllegalState), //todo 정리 |
| 5 | 스왑된 테스트 정리, 오타(makedChannel/userIdlist) |

새 구조를 만든 것 자체가 sprint1 대비 큰 성장이에요. **가장 먼저 1번(잔재 삭제)만 해도** 코드가 훨씬 읽기 좋아지고, 그다음 2~4로 다듬으면 김민재님/이은솔님 수준의 정돈된 구조에 가까워집니다.
