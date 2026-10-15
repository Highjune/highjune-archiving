# 카카오톡 투표 자동화 프로젝트

## 프로젝트 개요

### 현재 상황
- **문제점**: 매주 토요일 저녁 10시에 테니스 단체 카카오톡방에 투표를 수동으로 올림
- **참여 인원**: 약 20명
- **빈도**: 매주 1회
- **이슈**: 담당자가 자주 깜빡함

### 자동화 목표
카카오톡 공식 투표 기능을 사용하여 **완전 자동으로** 투표를 생성 및 게시

---

## 투표 상세 요구사항

### 투표 생성 규칙
- **실행 시간**: 매주 토요일 22:00 (한국시간)
- **제목 형식**: `YYYY-MM-DD 테니스` (다음 주 토요일 날짜, +7일)
- **옵션**: 고정 4개 - "6시", "7시", "8시", "9시"
- **복수 선택**: 활성화
- **마감 시간**: 투표 생성일 기준 +4일 뒤 수요일 오전 11:55

### 예시
```
[2026-04-05 토요일 22:00 투표 생성]

제목: 2026-04-12 테니스
옵션:
  □ 6시
  □ 7시
  □ 8시
  □ 9시
복수 선택: 가능
마감: 2026-04-09 (수) 11:55
```

---

## 기술적 제약사항

### 카카오톡 API 현황
❌ **일반 사용자 대상 메시지 자동 전송 API 없음**
- 카카오 비즈니스 API: 기업→사용자 단방향만 지원
- 단체방 투표 자동화 공식 기능 없음
- 투표 예약 기능 없음 (일반 메시지 예약만 가능)

❌ **비공식 자동화 시도 시 리스크**
- 이용약관 위반 가능성
- 계정 정지 위험

---

## 검토한 대안들

### 1. Android Tasker + AutoInput
**구현**: Android 기기에서 Accessibility 권한으로 자동화
- ✅ 완전 자동화 가능
- ❌ Android 기기 필요
- ❌ 계정 정지 리스크

### 2. PC 카카오톡 + RPA 툴 (Python/AutoHotkey)
**구현**: 화면 좌표 기반 클릭 자동화
- ✅ 로직 커스터마이징 자유로움
- ❌ PC 24시간 가동 또는 토요일에만 켜기
- ❌ 화면 해상도/창 위치 고정 필요

### 3. iOS Shortcuts 준자동화
**구현**: 알림 + 클립보드 복사
- ✅ iPhone/iPad 가능
- ✅ 계정 정지 리스크 없음
- ❌ 완전 자동은 아님 (2-3번 터치 필요)

### 4. 플랫폼 전환 (텔레그램/디스코드 봇)
**구현**: 공식 Bot API 사용
- ✅ 완벽한 자동화
- ❌ 20명 모두 플랫폼 이동 필요 (현실적으로 불가능)
- ❌ 사용자가 원하지 않음

---

## 최종 선택: Windows VM + Python 자동화

### 아키텍처
```
우분투 홈서버 (24시간 가동)
  └─ VirtualBox
      └─ Windows 10 VM (토요일 22시에만 가동)
          ├─ PC 카카오톡
          └─ Python + pyautogui
```

### 작동 흐름
```
매주 토요일 21:55 (자동)
  ↓
① Spring Boot Scheduler 트리거
  ↓
② Windows VM 자동 시작 (vboxmanage)
  ↓
③ VM 내부 Python 스크립트 실행
  ↓
④ PC 카카오톡 자동 실행
  ↓
⑤ 단체방 열기
  ↓
⑥ '+' 버튼 클릭 → '투표' 선택
  ↓
⑦ 제목 입력: f"{next_saturday} 테니스"
  ↓
⑧ 옵션 입력: "6시", "7시", "8시", "9시"
  ↓
⑨ 복수 선택 체크
  ↓
⑩ 마감일 설정: next_wednesday 11:55
  ↓
⑪ 전송 버튼 클릭
  ↓
⑫ VM 자동 종료

👤 사용자 개입: 0회
```

---

## 홈서버 리소스 현황

### 서버 정보
- **하드웨어**: Intel 미니PC
- **OS**: Ubuntu
- **운영 방식**: 24시간 상시 가동
- **위치**: `/home/highjune/services/`

### 메모리 (free -h)
```
총 RAM: ~16GB (추정)
사용 가능: 12GB
Windows VM 할당: 3GB (충분함 ✅)
```

### 디스크 (df -h)
```
루트 파티션 (/dev/nvme0n1p2):
├─ 전체: 468GB
├─ 사용: 30GB (Docker, Jenkins 등)
├─ 남음: 415GB (89% 여유)
└─ Windows VM: 25GB 할당 (문제없음 ✅)
```

### 현재 실행 중인 서비스
| 컨테이너 | 이미지 | 포트 | RAM 예상 |
|----------|--------|------|----------|
| snt-app | highjunea37/tennis-record-k | 8090 | ~500MB |
| tennis-mysql | mysql:8.0 | 3306 | ~300MB |
| jenkins-server | jenkins-jenkins | 18080, 50000 | ~500MB |

**VM 추가 후 예상:**
- 기존 서비스: ~4GB
- Windows VM: ~3GB (토요일 22시에만)
- 여유: 9GB ✅

---

## 구현 계획

### Phase 1: VM 환경 구축
**소요 시간**: 1-2시간

```bash
# VirtualBox 설치
sudo apt update
sudo apt install virtualbox virtualbox-ext-pack

# Windows 10 ISO 다운로드
# - Microsoft 공식 평가판 (90일 무료)
# - 또는 정품 라이선스

# VM 생성
# - RAM: 3GB
# - 디스크: 25GB (동적 할당)
# - CPU: 2 코어

# VM 내부 설치
# - Windows 10
# - PC 카카오톡
# - Python 3.x
# - 필요 패키지: pyautogui, schedule, pywin32
```

### Phase 2: Python 자동화 스크립트 작성
**소요 시간**: 2-3시간

```python
# vote_bot.py
import pyautogui
import datetime
import time

def calculate_dates():
    """다음 토요일 및 수요일 마감일 계산"""
    today = datetime.date.today()
    next_saturday = today + datetime.timedelta(days=7)
    deadline_wednesday = today + datetime.timedelta(days=4)
    deadline_time = "11:55"
    return next_saturday, deadline_wednesday, deadline_time

def activate_kakao_window():
    """카카오톡 창 활성화"""
    # pywin32로 윈도우 찾기
    pass

def open_chat_room(room_name="테니스"):
    """단체방 열기"""
    # 채팅방 검색 및 클릭
    pass

def create_vote(title, options, deadline):
    """투표 생성"""
    # + 버튼 클릭
    # 투표 메뉴 선택
    # 제목/옵션 입력
    # 마감일 설정
    # 전송
    pass

def post_vote():
    """메인 실행 함수"""
    next_sat, deadline_wed, deadline_time = calculate_dates()
    title = f"{next_sat} 테니스"
    options = ["6시", "7시", "8시", "9시"]
    
    activate_kakao_window()
    open_chat_room()
    create_vote(title, options, f"{deadline_wed} {deadline_time}")
    
    # 완료 후 VM 종료
    # os.system("shutdown /s /t 30")

if __name__ == "__main__":
    post_vote()
```

### Phase 3: Spring Boot 스케줄러 통합
**소요 시간**: 30분

**프로젝트**: tennis-record-k

**디렉토리 구조**:
```
src/main/kotlin/com/snt/tennis_record_k/
└── services/
    └── kakao/
        ├── application/
        │   └── KakaoVoteScheduler.kt
        └── infrastructure/
            └── WindowsVmController.kt
```

**KakaoVoteScheduler.kt**:
```kotlin
package com.snt.tennis_record_k.services.kakao.application

import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.io.BufferedReader
import java.io.InputStreamReader

@Component
class KakaoVoteScheduler {
    
    // 매주 토요일 21:55 (VM 시작)
    @Scheduled(cron = "0 55 21 * * SAT", zone = "Asia/Seoul")
    fun startKakaoVoteBot() {
        println("🤖 카카오톡 투표 봇 시작...")
        
        try {
            // Windows VM 시작
            val process = ProcessBuilder(
                "vboxmanage", "startvm", "win10-kakao", "--type", "headless"
            ).start()
            
            val exitCode = process.waitFor()
            
            if (exitCode == 0) {
                println("✅ Windows VM 시작 완료")
            } else {
                println("❌ VM 시작 실패: $exitCode")
            }
        } catch (e: Exception) {
            println("❌ 오류 발생: ${e.message}")
            e.printStackTrace()
        }
    }
    
    // VM 상태 확인 (선택사항)
    @Scheduled(cron = "0 0 23 * * SAT", zone = "Asia/Seoul")
    fun checkVmStatus() {
        val process = ProcessBuilder("vboxmanage", "list", "runningvms").start()
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val output = reader.readText()
        println("🔍 실행 중인 VM: $output")
    }
}
```

### Phase 4: 테스트 및 최적화
**소요 시간**: 1-2시간

1. **좌표 캘리브레이션**
   - 카카오톡 UI 요소 좌표 확인
   - 해상도 고정 (예: 1024x768)
   
2. **에러 핸들링**
   - 카카오톡 미실행 시
   - 채팅방 못 찾을 시
   - 네트워크 끊김 시

3. **로깅**
   - 실행 로그 기록
   - 스크린샷 저장 (디버깅용)

4. **Dry-run 테스트**
   - 테스트 채팅방에서 먼저 실행
   - 날짜 계산 검증

---

## 예상 문제 및 해결 방안

### 1. 카카오톡 UI 변경
**문제**: 카카오톡 업데이트 시 버튼 위치 변경
**해결**: 
- 이미지 인식 방식 병행 (`pyautogui.locateOnScreen()`)
- 업데이트 자동 비활성화

### 2. VM 부팅 시간
**문제**: VM 시작에 30초~1분 소요
**해결**:
- 스케줄러를 21:55에 실행 (5분 여유)
- VM 내부에서 Windows 작업 스케줄러로 22:00에 Python 실행

### 3. 네트워크 불안정
**문제**: 홈서버 인터넷 끊김
**해결**:
- 재시도 로직 추가
- Slack/Discord로 실패 알림 (백업용)

### 4. 카카오톡 로그인 세션 만료
**문제**: 오랜 기간 후 재로그인 필요
**해결**:
- VM을 주기적으로(월 1회) 테스트 실행
- 로그인 상태 유지 옵션 활성화

---

## 대안 플랜 (백업)

### Plan B: 준자동화 (iOS Shortcuts)
완전 자동화 실패 시:
- iOS Shortcuts로 토요일 22시 알림
- 클립보드에 투표 내용 복사
- 사용자가 2-3번 탭으로 투표 생성

### Plan C: 담당자 로테이션
기술적 해결 불가 시:
- 매주 담당자 변경 (20명 순환)
- Google Calendar 리마인더

---

## 향후 확장 가능성

### 1. 댓글 자동 분석
- 투표 결과 크롤링
- 통계 분석 (가장 인기 있는 시간대)
- tennis-record-k DB에 저장

### 2. 투표 결과 알림
- 수요일 마감 후 결과 요약
- 참여율 통계

### 3. 다른 정기 메시지 자동화
- 월 정산 안내
- 시즌 종료 공지

---

## 타임라인

| 단계 | 작업 | 예상 소요 | 상태 |
|------|------|-----------|------|
| 1 | VirtualBox 설치 | 10분 | ⏸️ 대기 |
| 2 | Windows VM 구축 | 1시간 | ⏸️ 대기 |
| 3 | Python 스크립트 작성 | 2시간 | ⏸️ 대기 |
| 4 | Spring Boot 스케줄러 | 30분 | ⏸️ 대기 |
| 5 | 좌표 캘리브레이션 | 1시간 | ⏸️ 대기 |
| 6 | 테스트 실행 | 30분 | ⏸️ 대기 |
| 7 | 프로덕션 배포 | 10분 | ⏸️ 대기 |

**총 예상 소요 시간**: 5-6시간

---

## 참고 자료

### 관련 프로젝트
- **tennis-record-k**: `/Users/kangjune-heo/workspace/highjune/tennis-record-k`
- **GitHub**: https://github.com/Highjune/tennis-record-k.git

### 기술 문서
- VirtualBox CLI: https://www.virtualbox.org/manual/ch08.html
- pyautogui 문서: https://pyautogui.readthedocs.io/
- Spring Scheduler: https://spring.io/guides/gs/scheduling-tasks/

---

## 체크리스트

**시작 전 확인사항:**
- [ ] VirtualBox 설치 가능 여부 확인
- [ ] Windows 라이선스 확보 (평가판 or 정품)
- [ ] PC 카카오톡 로그인 가능 여부
- [ ] 테스트용 카카오톡 채팅방 준비

**개발 체크리스트:**
- [ ] Windows VM 생성 완료
- [ ] VM 네트워크 설정 (NAT/Bridge)
- [ ] Python 환경 설정
- [ ] pyautogui 좌표 테스트
- [ ] 날짜 계산 로직 검증
- [ ] Spring Boot 스케줄러 통합
- [ ] Dry-run 테스트 성공

**운영 체크리스트:**
- [ ] 첫 주 실제 실행 모니터링
- [ ] 로그 확인 자동화
- [ ] 실패 시 알림 설정
- [ ] 백업 플랜 준비

---

**최종 업데이트**: 2026-04-06
**작성자**: highjune
**프로젝트 상태**: 기획 완료, 구현 대기
