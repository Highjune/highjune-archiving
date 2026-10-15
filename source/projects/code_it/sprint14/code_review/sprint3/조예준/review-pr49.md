# 코드 리뷰 — 조예준 sprint3 (PR #49)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/49
- **작성자**: joyejun (조예준)
- **범위**: Spring Boot 전환 + 엔티티 재설계 + Repository 인터페이스/JCF·File 구현 분리 + Basic 서비스
- **규모**: +1002 / -329, 47 files, 4 commits
- **멘토에게**: "기본 요구사항 작성. 추가 기능(심화)은 이어서 작성 예정" — 질문 없음, 진행 중 상태

> diff 전체(1757줄) 확인 완료.

---

## 총평 — sprint2 대비 성장 폭이 큼 👍

- **엔티티 재설계가 제대로 됨**: 오타 클래스 `Chennel` 삭제 → `Channel` + `ChannelType` enum, `Message`가 sendMessage/receiveMessage 임시 모델에서 **content + channelId + authorId** 실제 도메인 모델로, `User`도 username/email/password로 정리. 옛 잔재(JCFChennelService, JCFUserServie 등)를 **지우면서** 새 구조를 만든 점이 특히 좋음.
- **계층 구조 정석**: Repository 인터페이스(`Optional` 반환) + `jcf`/`file` 구현체, `BasicXxxService` + `@RequiredArgsConstructor` 생성자 주입, 조회 실패는 `orElseThrow(NoSuchElementException)` — 표준 예외 선택도 정확.
- **직렬화 구현 정확**: `serialVersionUID` 이름 정확, try-with-resources, `Optional.ofNullable` 처리.
- 엔티티 `update()`가 실제 값이 바뀔 때만 `updatedAt` 갱신하는 디테일도 좋음.

다만 아래 🔴 1~2번 때문에 **지금 이 브랜치는 빌드/실행이 안 되는 상태**라, 이것부터 잡아야 함.

---

## 🔴 Critical (빌드가 안 되는 문제)

### 1. `JavaApplication`의 package 선언이 폴더와 다름 → 컴파일 에러
📍 `discodeit/JavaApplication.java` 1행
```java
package com.sprint.mission.discodeit3;   // ← discodeit"3"
```
파일 위치는 `com/sprint/mission/discodeit/`인데 패키지 선언이 `discodeit3`이라 **컴파일 자체가 실패**해요. 아마 이름을 잠깐 바꿨다가 남은 흔적 같은데, `package com.sprint.mission.discodeit;`으로 되돌려야 합니다. (이거 하나 때문에 `./gradlew build`가 통째로 안 됨)

### 2. `gradle-wrapper.properties`가 `gradle-wrapper.yaml`로 rename됨 → gradlew 실행 불가
📍 `gradle/wrapper/gradle-wrapper.yaml`
Gradle 래퍼는 **`gradle-wrapper.properties`라는 파일명을 그대로 찾도록 하드코딩**되어 있어서, `.yaml`로 바꾸면 `./gradlew`가 gradle 배포판을 못 찾아 실패해요. 내용도 properties 형식 그대로라(yaml 아님) 확장자만 바뀐 상태 → **파일명을 `gradle-wrapper.properties`로 되돌리기.** (application.yaml 작업하다가 실수로 같이 바뀐 듯)

### 3. `application.yaml` 위치가 `src/resources/` → Spring이 못 읽음
📍 `codeit/src/resources/application.yaml`
Spring Boot는 **`src/main/resources/`** 만 클래스패스로 인식해요. 지금 위치(`src/resources/`)면 이 파일은 무시됩니다. 지금은 app name뿐이라 티가 안 나지만, 심화(구현체 스위칭 설정)를 여기에 넣는 순간 "설정했는데 동작 안 함"으로 이어져요 → `src/main/resources/`로 이동.

---

## 🟡 Major

### 4. JCF 레포는 빈 등록이 안 됨 + 심화(yaml 스위칭) 미구현
- `JCFUserRepository` 등 JCF 구현체 3개엔 `@Repository`가 없어서 **Spring 빈이 아님** → 현재 Spring에서 선택 가능한 건 File뿐.
- File 레포의 `@Qualifier("FileChannelRepository")`는 주입받는 쪽에서 안 쓰고 있어 현재 의미 없음.
- 심화 요구사항은 **yaml 설정으로 JCF/File 스위칭**: 두 구현체 다 빈으로 등록 + `@ConditionalOnProperty(name = "discodeit.repository.type", havingValue = "jcf"/"file")` + yaml에 `discodeit.repository.type: file`. (이어서 작성하겠다고 하신 부분 — 이 방향으로)

### 5. sprint3 신규 도메인 미착수 (진행 중인 부분)
`ReadStatus` / `UserStatus` / `BinaryContent` 엔티티와 DTO 도입이 sprint3 범위인데 아직 없어요. 본인도 이어서 작성한다고 했으니, 다음 순서 제안: ① 1~3번 수정(빌드 복구) → ② 심화 스위칭(4번) → ③ 신규 도메인 + DTO.

### 6. `DiscodeitApplication`의 셋업/테스트 코드가 전부 주석 처리
📍 `DiscodeitApplication.main()` — `setupUser`/`setupChannel`/`messageCreateTest` 호출이 모두 주석이라 **Spring으로 실행해도 아무것도 검증되지 않아요.** (1번 컴파일 에러 때문에 실행해보지 못한 상태로 보임) 1번 고친 뒤 주석을 풀고 실제로 돌려서 확인 필요.

### 7. `.gitignore` 수정 실수 → .DS_Store 12개 + .ser 데이터 파일 커밋됨
📍 `.gitignore` 마지막 줄
```
.DS_Store.idea      ← 두 항목이 한 줄로 합쳐짐
```
`.DS_Store`와 `.idea`가 한 줄로 붙어 **둘 다 매칭이 안 되는 패턴**이 됐어요. 그래서 이번 PR에 `.DS_Store` 12개가 올라왔습니다. 실행 산출물인 `file-data-map/*.ser` 3개도 커밋됐고요.
```
.DS_Store
.idea/
file-data-map/
```
로 줄을 나눠 넣고, 이미 커밋된 파일은 `git rm --cached`로 제거하세요.

---

## 🔵 Minor / Nit

- **엉뚱한 import**: `ChannelRepository`(인터페이스!)에 `@RequestMapping` import, File 레포 3개에 `@Controller`/`RequestMapping` import, Basic 서비스 3개에 미사용 `@Qualifier`, `JavaApplication`에 미사용 `RequiredArgsConstructor`, `BasicUserService`에 미사용 `ChannelRepository` import — IDE 자동완성 실수들. ⌥⌘O(import 정리)로 일괄 정돈.
- **createdAt/updatedAt이 `Long`(epochSecond)**: `Instant.now().getEpochSecond()`는 초 단위라 정밀도가 떨어져요. 필드를 `Instant` 타입 그대로 두는 게 요구사항에도 맞고 (Instant도 Serializable) 더 정확합니다.
- **엔티티 `id`에 final이 없어짐**: 직렬화 때문에 final을 뺀 거라면 — 역직렬화는 final 필드도 복원 가능하니 `id`, `createdAt`은 final 유지 가능.
- **HELP.md** — Spring Initializr 생성물, 삭제해도 됨.
- PR 본문의 IoC/DI 설명은 방향이 정확함 (JavaApplication=직접 생성 vs DiscodeitApplication=컨테이너가 관리 → 결합도 감소). 잘 이해하고 있음.

---

## 정리 (우선순위)

| 순위 | 항목 | 위치 |
|---|---|---|
| 1 | 🔴 package `discodeit3` → `discodeit` (컴파일 에러) | `JavaApplication.java:1` |
| 2 | 🔴 `gradle-wrapper.yaml` → `gradle-wrapper.properties` 복원 | `gradle/wrapper/` |
| 3 | 🔴 `application.yaml`을 `src/main/resources/`로 이동 | `src/resources/` |
| 4 | .gitignore 줄 분리 + .DS_Store/.ser 제거 | `.gitignore` |
| 5 | JCF 레포 빈 등록 + @ConditionalOnProperty 스위칭 (심화) | `repository/jcf`, `file` |
| 6 | DiscodeitApplication 주석 해제 후 실제 실행 확인 | `DiscodeitApplication` |
| 7 | 신규 도메인(ReadStatus/UserStatus/BinaryContent) + DTO | (이어서 작성 예정) |

구조와 방향은 sprint2 대비 확실히 좋아졌고, 남은 건 대부분 "실수 복구 + 이어서 채우기"예요. 특히 1~2번은 브랜치를 받은 사람 누구도 빌드할 수 없는 상태라 가장 먼저 잡아야 합니다.
