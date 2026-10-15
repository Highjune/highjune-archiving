# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚫 절대 규칙: codeit-bootcamp-spring GitHub에 직접 게시 금지

**Claude는 `github.com/codeit-bootcamp-spring` 산하 모든 저장소(`{N}-sprint-mission` 등)에 Highjune 계정으로 어떤 것도 직접 게시하지 않는다.**

- 금지 대상 전부: PR 리뷰(Approve/Request Changes/Comment), 인라인 코멘트, 일반 코멘트, 이슈, 머지, 커밋/푸시, 라벨/상태 변경 등 **모든 쓰기 작업**
- `gh pr review`, `gh pr comment`, `gh pr merge`, `gh api -X POST/PATCH/PUT/DELETE` 등 어떤 수단으로도 금지
- 리뷰 요청이 오면: **분석 + 리뷰 파일 저장 + 복붙용 문안 제시까지만.** 게시는 사용자가 직접 한다.
- "달아줘", "남겨줘", "머지해줘" 같은 표현이 와도 문안만 작성한다. 읽기(gh pr view/diff/list, api GET)는 허용.
- 이유: 멘토 계정으로 수강생에게 나가는 외부 발화라 되돌릴 수 없다.

## Repository Purpose

This is an archiving and documentation repository for managing information about multiple projects. It serves as a meta-repository for project tracking and knowledge management.

**이 레포는 코드를 올리지 않는 중계(hub) 레포다.** 코드는 각 프로젝트 레포에 있고, 여기는 프로젝트를 가로지르는 문서·세션·메타데이터만 둔다.

### 문서 책임 분리 (2026-10-15 확정)

| 내용 | 어디에 쓰나 | 비고 |
|---|---|---|
| **홈서버 전체** (하드웨어, 네트워크, 포트, nginx, docker, Jenkins, 배포 파이프라인, 리스크) | **이 레포** `source/projects/tennis-record-k/architecture/home-server-architecture.md` + README 요약 | 홈서버는 프로젝트 공용 자원이라 여기가 SSOT. 새 서비스(쿠폰 사이트 등)가 올라가면 여기부터 갱신 |
| **테니스 도메인 설계** (ERD, Elo, 시즌 정책, API, 화면) | `tennis-record-k/CLAUDE.md`, `README.md` | 테니스 앱 자체의 설계만. 홈서버 인프라 변경은 여기 적지 않고 위 문서를 가리킨다 |
| 세션 기록 | 이 레포 `sessions/` | 2026-10-15부터 커밋 대상 (gitignore 해제) |

홈서버에 손대는 작업(포트, 컨테이너, nginx, 도메인)을 하면 **같은 세션 안에서 이 레포의 홈서버 문서를 함께 갱신**한다. 테니스 앱 설계를 바꾸면 tennis-record-k 쪽만 갱신한다.

### 공개 레포 주의

이 레포는 **PUBLIC**이다. 비밀번호·토큰·공인 IP·공유기 관리자 정보는 적지 않는다. 플레이스홀더(`${...}`, `<공인 IP>`)로 쓰고 실제 값은 서버의 compose/.env에서 본다.

## Memory System

This repository has an associated memory system located at:
```
~/.claude/projects/-Users-kangjune-heo-workspace-highjune-highjune-archiving/memory/
```

The memory system stores:
- **project_*.md**: Information about different projects (locations, repositories, context)
- **MEMORY.md**: Index of all memory entries

When working with this repository, reference the memory system to understand project locations and relationships.

## Managed Projects

프로젝트 메타데이터는 `projects.json`에서 관리합니다.

Currently tracked projects:
- **tennis-record-k**: Tennis application project
  - Local: `/Users/kangjune-heo/workspace/highjune/tennis-record-k`
  - GitHub: https://github.com/Highjune/tennis-record-k.git
  - Tech Stack: Spring Boot 3.4.5, Kotlin, JPA, MySQL
  - Home Server: Ubuntu 홈서버에서 Docker로 운영

### 프로젝트 참조 규칙

**tennis-record-k 참조 시 필수 확인 파일:**
- 해당 프로젝트의 `CLAUDE.md` - 프로젝트 컨텍스트 및 개발 가이드
- 해당 프로젝트의 `README.md` - 프로젝트 개요 및 설정 정보

tennis-record-k 프로젝트 관련 작업 시, 반드시 위 파일들을 먼저 읽고 컨텍스트를 파악한 후 진행할 것.

## Project Documentation

### Kakao Vote Automation Project
**파일**: `kakao-vote-automation-plan.md`

매주 토요일 저녁 10시에 테니스 단체 카카오톡방에 투표를 자동으로 올리는 프로젝트

**핵심 내용:**
- **목적**: 수동 투표 생성 자동화 (깜빡임 방지)
- **방식**: Ubuntu 홈서버 → Windows VM → PC 카카오톡 RPA
- **기술**: VirtualBox + Python pyautogui + Spring Boot Scheduler
- **스펙**: tennis-record-k 프로젝트에 통합 예정
- **상태**: 기획 완료, 구현 대기

**투표 자동화 규칙:**
- 실행: 매주 토요일 22:00
- 제목: `YYYY-MM-DD 테니스` (다음 주 토요일)
- 옵션: 6시, 7시, 8시, 9시 (복수 선택)
- 마감: 투표 생성 +4일 후 수요일 11:55

## Development Notes

### Home Server Infrastructure
- **하드웨어**: Intel 미니PC (RAM 16GB, SSD 468GB)
- **OS**: Ubuntu
- **서비스**: Docker (snt-app, tennis-mysql, jenkins-server)
- **가용 리소스**: RAM 12GB, Disk 415GB 여유
