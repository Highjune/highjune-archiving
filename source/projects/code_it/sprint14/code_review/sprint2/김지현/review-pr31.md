# 코드 리뷰 — [김지현] sprint2 (PR #31, #22의 리팩터링 후속)

- **PR**: https://github.com/codeit-bootcamp-spring/14-sprint-mission/pull/31
- **작성자**: pengji-dev (김지현)
- **성격**: 이전 #22를 대폭 리팩터링 (+709 / -723, 29 files). 지난 리뷰 반영 확인 목적.
- **이전 리뷰**: `review.md` (PR #22)

---

## 총평 — 지난 리뷰를 아주 잘 반영했습니다 👍

#22에서 지적한 핵심들이 대부분 해결됐고, 구조가 한 단계 올라갔어요.

| #22 지적 | #31 반영 |
|---|---|
| `updatedAt` 미갱신 (setter 사용) | ✅ **해결** — `@Setter` 제거, `update()`가 `super.updateTime()` 호출 |
| `JCF*Service`/`File*Service` 완전 중복 | ✅ **해결** — 6개 삭제, `Basic*Service`로 일원화 |
| File 레포 `loadData` 예외 삼킴(빈 Map 반환) | ✅ **해결** — 로깅 후 `throw`(원인 e 보존) |
| 서비스가 `System.out.println` | ✅ **해결** — slf4j 로깅 도입 |
| (은솔님 Q였던) BaseEntity abstract | ✅ **도입** — `abstract class BaseEntity` |

추가로 **ChannelType enum 도입**, Message 필드 정리(`userId`→`authorId`), main을 `setup*`/`messageCreateTest` 패턴으로 정돈까지 했어요. 반영 속도와 완성도가 좋습니다.

---

## 🟡 아직 남은 것 / 새로 보이는 것

### 1. `serialVersionID` 오타 여전 (U 빠짐)
📁 `entity/BaseEntity.java:567`
```java
private static final long serialVersionID = 1L;   // 정확히는 serialVersionUID
```
#22에서 짚었던 오타가 **BaseEntity로 옮겨지면서도 그대로** 복사됐어요. 이제 한 곳(BaseEntity)에만 있으니 고치기도 더 쉬워요 → `serialVersionUID`로. (이름이 틀리면 직렬화 버전 필드로 인식되지 않음)

### 2. `.dat` 파일 여전히 커밋됨
`channels.dat`, `messages.dat`, `users.dat`가 계속 저장소에 올라오고 있어요(diff에 binary 변경으로 잡힘). `.gitignore`에 `*.dat` 추가 + `git rm --cached`로 정리 권장.

### 3. `findById`가 Repository 계층에서 도메인 예외를 던짐 (계층 책임)
📁 `repository/file/FileChannelRepository.java`
```java
public Channel findById(UUID id) {
    Channel channel = Optional.ofNullable(loadData().get(id))
            .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 채널입니다."));
    ...
}
```
"없으면 예외" 정책을 명확히 한 건 좋아요. 다만 **"존재하지 않는 채널입니다" 같은 도메인성 판단/메시지는 보통 Service의 책임**이에요. Repository는 저장/조회에 집중(없으면 `null`이나 `Optional` 반환)하고, Service가 그걸 받아 예외를 던지는 게 일반적인 분리입니다. 지금은 Repository가 던지고 Service(`BasicChannelService.findById`)는 그대로 통과시켜요. 정답이 하나는 아니지만, "검증/예외 정책은 어느 계층이 갖는가"를 한 번 정리해두면 좋아요.
> 연관: `delete`는 `repository.delete(id)`를 바로 호출해서, 없는 id를 지울 때 `findById`처럼 예외가 나는지/조용한지 흐름이 findById와 다를 수 있어요. delete/update/find의 "없을 때" 동작을 통일하면 일관적입니다.

### 4. File 레포가 매 연산마다 `loadData()` (캐시 없음)
`save`/`findById`/`findAll`/`delete`가 매번 파일 전체를 역직렬화합니다. 지금 규모엔 문제없지만, 다른 학생들처럼 **생성자에서 1회 로드 → 메모리 캐시 유지 → 쓰기 때만 flush**로 바꾸면 조회가 디스크를 안 타서 훨씬 빨라져요. (다음 개선 후보)

---

## 🔵 Minor / Nit

- **`User`만 `@Setter` 잔존**: `Channel`/`Message`는 setter를 제거해 `update()`로만 바꾸게 했는데, `User`는 `username/email/password`에 `@Setter`가 남아 있어요. setter로 바꾸면 `updateTime()`을 안 거쳐 `updatedAt`이 안 바뀌므로, User도 setter 제거 + `update()`로 통일하는 게 안전합니다(방금 고친 버그의 재발 방지).
- **옛 데모 코드가 `Application`에 대량 주석**으로 남아 있어요. 새 `main`이 깔끔하니 주석 블록은 삭제 권장.
- **`throw new RuntimeException(e)`**: 원인은 잘 넘겼는데(👍), 메시지를 함께 주면(`"채널 파일 읽기 실패: " + FILE_NAME`) 로그에서 더 빨리 원인을 좁힐 수 있어요.

---

## 정리

지난 리뷰의 **가장 중요한 버그(updatedAt 미갱신)와 구조 문제(서비스 중복, 예외 삼킴)**를 정확히 잡았고, 로깅·enum·abstract까지 스스로 발전시켰어요. 남은 건 대부분 위생/일관성 수준입니다.

| 순위 | 항목 |
|---|---|
| 1 | `serialVersionID` → `serialVersionUID` 오타 (BaseEntity) |
| 2 | `.dat` 커밋 정리 (gitignore) |
| 3 | findById 예외의 계층 책임(Repository vs Service) 정리 |
| 4 | File 레포 캐시(1회 로드+flush) |
| 5 | User `@Setter` 제거, 옛 주석 코드 삭제 |

반영 퀄리티가 좋아서, 남긴다면 1·2번(간단·확실)만 콕 짚고 3·4는 "다음 개선 방향"으로 부드럽게 전하면 충분합니다.
