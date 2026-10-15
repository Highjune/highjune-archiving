# 홈서버 아키텍처 (현재 상태)

- 기준일: 2026-10-15 (외부 포트는 맥북에서 `nc`/`curl`로 실측)
- 원본 설정 문서: `tennis-record-k/CLAUDE.md` "개발 운영" / "네트워크 인프라" 섹션
- 비밀번호·키 값은 이 문서에 적지 않는다. compose 파일과 Jenkins Credentials를 본다.

## 1. 전체 구성도

```mermaid
flowchart TB
    subgraph INTERNET["인터넷"]
        USER["사용자 브라우저"]
        GH["GitHub<br/>Highjune/tennis-record-k<br/>(release 브랜치)"]
        HUB["DockerHub<br/>highjunea37/tennis-record-k"]
        DNS["o-r.kr DDNS<br/>snt.o-r.kr → <공인 IP>"]
    end

    subgraph HOME["집 네트워크"]
        MODEM["모뎀 192.168.75.1<br/>공인 IP <공인 IP><br/>NAT + 포트포워딩"]
        ROUTER["공유기<br/>WAN 192.168.75.231 (모뎀이 할당, 재부팅 시 변동)<br/>LAN 192.168.35.1"]
        subgraph PC["미니PC (Intel, Ubuntu) 192.168.35.122"]
            NGINX["nginx 1.18 (호스트 프로세스)<br/>:80 → 301 https<br/>:443 TLS 종료"]
            subgraph DOCKER["Docker"]
                APP["snt-app<br/>Spring Boot (Kotlin)<br/>:8090"]
                DB["tennis-mysql<br/>MySQL 8.0<br/>:3306"]
                JENKINS["jenkins-server<br/>:18080 (UI) / :50000"]
            end
        end
    end

    USER -->|"https://snt.o-r.kr"| DNS
    DNS --> MODEM
    MODEM -->|"22, 80, 443, 3306, 8080"| ROUTER
    ROUTER --> PC
    NGINX -->|"proxy_pass"| APP
    APP -->|"app-network"| DB
    JENKINS -->|"pollSCM 2분"| GH
    JENKINS -->|"docker push"| HUB
    JENKINS -->|"docker.sock 공유 → compose pull/up"| APP
```

## 2. 외부에서 열린 포트 (실측)

| 외부 포트 | 상태 | 뒤에 있는 것 | 비고 |
|---|---|---|---|
| 22 | 열림 | sshd (비밀번호 인증) | 외부 SSH 가능 |
| 80 | 열림 | nginx → `301 https://snt.o-r.kr/` | |
| 443 | 열림 | nginx → snt-app :8090 | `Server: nginx/1.18.0 (Ubuntu)` |
| 3306 | **열림** | tennis-mysql | 공인 IP로 MySQL 직접 접속 가능. 닫아야 함 |
| 8080 | 닫힘 | (없음) | 앱이 8090으로 바뀌어 죽은 포워딩 규칙 |
| 8090 | 닫힘 | snt-app | nginx 뒤에서만 접근 (정상) |
| 18080 | 닫힘 | jenkins-server | 내부망에서만 접근 (정상) |

## 3. 요청이 흐르는 순서

```
브라우저 → DNS(snt.o-r.kr) → <공인 IP>:443
  → 모뎀 포트포워딩(443 → 192.168.75.231)
  → 공유기 → 192.168.35.122:443
  → nginx (443 소켓을 점유 중인 유일한 프로세스)
  → proxy_pass → 127.0.0.1:8090 (snt-app 컨테이너)
  → app-network → tennis-mysql:3306
```

nginx가 "제일 먼저" 받는 이유는 특별한 설정이 아니라 **OS 소켓 바인딩**이다. 한 포트는 한 프로세스만 listen할 수 있고, nginx 설정의 `listen 80; listen 443 ssl;`이 그 포트를 잡고 있으니 그 포트로 오는 패킷은 전부 nginx에게 간다. 컨테이너들은 8090/3306/18080처럼 다른 포트를 쓰므로 충돌이 없다.

## 4. 배포 파이프라인

```mermaid
sequenceDiagram
    participant Dev as 로컬 (맥북)
    participant GH as GitHub release
    participant J as jenkins-server
    participant Hub as DockerHub
    participant C as snt-app

    Dev->>GH: git push origin release
    J->>GH: pollSCM (2분마다)
    J->>J: ./gradlew clean bootJar
    J->>Hub: docker build --platform amd64 && push :latest
    J->>C: cd /home/highjune/services/snt-record && compose pull/down/up
    Note over J,C: Jenkins 컨테이너가 /var/run/docker.sock을 마운트해 호스트 docker를 직접 제어
```

- `main`이 아니라 **`release` 브랜치 푸시가 운영 배포 트리거**
- Jenkins UI(18080)는 외부에서 못 들어가므로 release 푸시가 유일한 원격 배포 경로
- GitHub 인증: Deploy Key(`id_rsa_jenkins.pub`) + Jenkins Credential `highjune-github-ssh`

## 5. 디렉토리

| 경로 | 내용 |
|---|---|
| `/home/highjune/services/snt-record/docker-compose.yml` | mysql_db + app 정의 (비밀번호 포함) |
| `/home/highjune/services/jenkins/` | Dockerfile, docker-compose.yml, run_docker_compose.sh |
| `/etc/nginx/sites-enabled/` (추정) | snt.o-r.kr server 블록. 실제 파일명·certbot 여부는 서버에서 확인 필요 |

## 6. 알려진 리스크 / 할 일

| # | 항목 | 심각도 | 조치 |
|---|---|---|---|
| 1 | **3306 공인 IP 노출** | 높음 | 모뎀 포트포워딩에서 `snt-record-db` 규칙 삭제. DB는 SSH 터널로 접속 |
| 2 | SSH 비밀번호 인증 | 중간 | 키 인증으로 전환 후 `PasswordAuthentication no` |
| 3 | 정전 시 공유기 WAN IP 변동 → 포워딩 5개 수동 수정 | 중간 | 공유기에 고정 IP 또는 모뎀 DMZ |
| 4 | 죽은 포워딩 규칙 8080 | 낮음 | 삭제 |
| 5 | nginx 설정·인증서 갱신 방식이 문서화 안 됨 | 낮음 | `/etc/nginx` 와 certbot 타이머 확인 후 기록 |

## 7. 예정: 쿠폰 어필리에이트 사이트

- 같은 nginx에 `server_name coupon.<도메인>` 블록 추가 → 새 컨테이너(예: :8081)로 proxy_pass
- 도메인은 별도 구매, DNS는 Cloudflare로 관리 (DDNS 자동 갱신 + 정적 호스팅 동시 활용)
- 상세는 결정되면 `features/coupon-site/`에 기록

## 8. 목표 아키텍처 (2026-10-15 계획)

README의 "목표 아키텍처" 섹션이 정본. 요지:

- 게이트웨이는 **nginx 하나**. Spring Cloud Gateway 등 별도 게이트웨이 두지 않음
- 신규: `coupon` 정적 사이트(nginx root), `coupon-api`(:8081, Docker), `tennis-mysql`에 `coupon` 스키마
- 모니터링: Prometheus + Grafana + Loki/promtail + node-exporter + cAdvisor (Docker, `grafana.<도메인>`으로 nginx 뒤에서 노출)
- 외부 포트는 22/80/443만. 3306·8080 포워딩 삭제
- Jenkins executor 1, `-Xmx2g`
