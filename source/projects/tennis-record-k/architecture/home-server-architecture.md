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
| 3306 | 닫힘 | home-mysql | 바인딩 `127.0.0.1`(10/15) · ufw 삭제(10/24) · 모뎀·공유기 포워딩 삭제(10/25). 외부에서 timeout |
| 8080 | 닫힘 | (없음) | 죽은 모뎀 포워딩 규칙 → 2026-10-25 삭제 |
| 8090 | 닫힘 | snt-app | nginx 뒤에서만 접근 (정상) |
| 18080 | 닫힘 | jenkins-server | 내부망에서만 접근 (정상) |
| 3000 | 닫힘 (LAN 전용) | grafana | `192.168.35.122:3000` 바인딩, 포워딩 없음. 밖에서는 SSH 터널 (§6-3) |

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
| `/etc/nginx/sites-enabled/snt.o-r.kr` | server 블록 1개. 443: `proxy_pass http://localhost:8090` + WebSocket 헤더. 80: `301 → https`. 인증서는 certbot 관리(`/etc/letsencrypt/live/snt.o-r.kr/`), `certbot.timer`로 매일 자동 갱신 확인됨 (2026-10-15 실측). `server_name`의 옛 WAN IP `192.168.75.66`은 2026-10-15 제거(백업 `.bak-20261015`) |
| `/home/highjune/services/jenkins/docker-compose.yml` | 2026-10-15 `JAVA_OPTS=-Xmx1g -Xms256m` 추가. 메모리 4.84GB → 0.44GB. 백업 `docker-compose.yml.bak-20261015` |
| 맥북 `~/.ssh/config` | `Host snt` 별칭 (키 `id_ed25519_highjune`). `ssh snt`로 접속. 비밀번호 인증은 아직 켜져 있음 |
| `/etc/sudoers.d/highjune` | `NOPASSWD:ALL` (2026-10-15). 원격 자동화용 |

## 6. 알려진 리스크 / 할 일

| # | 항목 | 심각도 | 조치 |
|---|---|---|---|
| 1 | **3306 공인 IP 노출** | ~~높음~~ | **완료 2026-10-25**: 모뎀 `snt-record-db` + 공유기 3306 규칙 삭제 (§6-2). DB는 SSH 터널로 접속 |
| 2 | SSH 비밀번호 인증 | 중간 | 키 등록 완료(2026-10-15). `PasswordAuthentication no`는 Tailscale 도입과 함께 |
| 2-1 | MySQL이 `0.0.0.0:3306`으로 바인딩 | ~~중간~~ | **완료 2026-10-15**: compose `127.0.0.1:3306:3306`. 앱은 `mysql_db:3306`(docker 네트워크)라 무영향. 포워딩 규칙은 10/25 삭제 완료 |
| 3 | 정전 시 공유기 WAN IP 변동 → 모뎀 포워딩 3개(22/80/443) 수동 수정 | 중간 | 모뎀 DHCP 고정 할당(192.168.75.231) 또는 Tailscale |
| 4 | 죽은 포워딩 규칙 8080(모뎀)·8090(공유기) | ~~낮음~~ | **완료 2026-10-25** 삭제 |
| 5 | nginx 설정·인증서 갱신 방식이 문서화 안 됨 | 낮음 | `/etc/nginx` 와 certbot 타이머 확인 후 기록 |

## 6-0. MySQL compose 분리 (2026-10-24)

`tennis-mysql`이 테니스 compose 안에 있어 테니스 배포(`compose down`) 때마다 쿠폰 DB까지 내려가던 문제를 해소.

| 디렉토리 | 서비스 | 컨테이너 | 비고 |
|---|---|---|---|
| `/home/highjune/services/mysql` | `mysql_db` | **home-mysql** | 공용 MySQL. 비밀번호는 `.env`. 볼륨 `snt-record_mysql-data`(external, 기존 데이터 그대로) |
| `/home/highjune/services/snt-record` | `app` | snt-app | mysql 제거, 네트워크 external |
| `/home/highjune/services/couponnote` | `api` | couponnote-api | `DB_HOST=home-mysql`로 변경 |

- 네트워크 `snt-record_app-network`는 이름 유지, 세 compose 모두 external 참조
- 테니스 앱은 `jdbc:mysql://mysql_db:3306`(서비스명)으로 접속하므로 코드 변경 없음
- 교체 순단 약 5초(18:24:00→05). 사전 덤프 `~/backup/mysql-all-20261024-1823.sql`, compose 백업 `*.bak-20261024-1823`
- 검증: 행 수 동일(824/61/622/5/34), 테니스 `compose down/up` 시 home-mysql 영향 없음 확인

## 6-1. DB 원격 접속 (2026-10-24)

sshd: 2026-10-24부터 인터넷 접속은 키 인증만(`PasswordAuthentication no`), 내부망 192.168.35.0/24는 `Match Address`로 비밀번호 허용. fail2ban sshd jail(5회/10분 → 1h 차단, 내부망 ignoreip) 가동.

ufw는 2026-10-24에 22/80/443만 남기고 3306·8080·8090·10002·30000 ALLOW를 삭제했다 (docker 공개 포트는 ufw를 우회하므로 실제 방어는 바인딩 주소 + 모뎀 포워딩).

MySQL 호스트 포트는 `127.0.0.1:3306` 바인딩(10/15). 외부에서는 **SSH 터널**(22 → 서버 내부 127.0.0.1:3306)로 접근하며, 2026-10-24 맥북 SSH 키를 `authorized_keys`에 등록해 키 인증 사용. 직접 공개 / SSH 터널 / 개인 VPN 세 구조 비교와 DataGrip 설정은 README "DB 원격 접속 아키텍처" 참고.

## 6-2. 모뎀·공유기 포워딩 정리 (2026-10-25)

집 내부망에서 두 NAT 장비의 포워딩 규칙을 22/80/443 세 개로 줄였다. 이로써 3306 방어는 compose 바인딩(1차) · ufw(2차) · 포워딩 없음(3차)의 3중.

| 장비 | 모델 | 관리 페이지 | 삭제한 규칙 | 남은 규칙 (→ 목적지) |
|---|---|---|---|---|
| 모뎀 (NAT 1) | DASAN H660N | `192.168.75.1` → 기본 설정 → NAT → Port 포워딩 | `snt-record-db` 3306, `snt-record-app` 8080 | SSH 22 · HTTP 80 · HTTPS 443 → `192.168.75.231`(공유기 WAN) |
| 공유기 (NAT 2) | MERCURY RUSH329AC | `192.168.35.1` → 고급 설정 → NAT/라우터 관리 → 포트포워드 | 3306, **8090** | 22 · 443 · 80 → `192.168.35.122`(미니PC) |

- 공유기에는 8080이 아니라 **8090**(앱 컨테이너 직통) 규칙이 있었다. 모뎀에 8090 규칙이 없어 실제로 뚫려 있진 않았지만, 모뎀 설정이 바뀌면 되살아나는 경로라 함께 삭제. 앱은 nginx 443 뒤에서만 접근
- 두 장비 모두 DMZ 비활성 확인
- **외부 검증** (check-host.net 해외 3개 노드, VPN 무관): 22·443 open / 3306·8080·8090 **Connection timed out**. refused가 아니라 timeout = 모뎀에서 폐기됨
- 검증 시 주의: 회사 VPN이 켜진 맥북에서 `nc`로 찌르면 VPN 아웃바운드 정책 때문에 3306·8080이 포워딩과 무관하게 timeout이 난다. 외부 포트 검증은 VPN 밖(폰 LTE, 외부 체크 서비스)에서 할 것
- 모뎀 관리 페이지는 회사 VPN 켠 상태에선 열리지 않는다. VPN이 default 경로를 터널로 가져가면서 맥북이 직접 붙은 대역(192.168.35.0/24)만 로컬로 남기고, 한 홉 바깥인 192.168.75.0/24는 터널로 보내기 때문. VPN을 끄거나 `sudo route -n add -net 192.168.75.0/24 192.168.35.1`(임시)로 우회

## 6-3. 모니터링: Grafana + Prometheus + Loki (2026-10-29)

테니스(snt-app)·쿠폰노트(couponnote-api) 두 앱의 **지표와 로그를 Grafana 한 화면**에서 본다. 설계 그림: https://claude.ai/artifact/6YPwJmKub2kom7wN2beGqn · 구성 파일: [`../infra/monitoring/`](../infra/monitoring/) (서버 `/home/highjune/services/monitoring`, compose 1개).

| 구성 요소 | 역할 | 저장 | 메모리(실측) |
|---|---|---|---|
| Prometheus v3.4 | 앱 `/actuator/prometheus` + node-exporter + cAdvisor를 15s pull, 30일 보관. 라벨 `app=tennis|couponnote|host|docker` | 지표 | 86 MB |
| Loki 3.5 | 로그 저장소. 라벨(`app`, `container`, `level`)만 색인, 본문 압축. 30일 보관 | 로그 | 77 MB |
| Alloy 1.9 | docker.sock으로 전 컨테이너 로그를 읽어 Loki로 push. 컨테이너명 → `app` 라벨, ECS JSON의 log level → `level` 라벨(Boot 4 중첩·Boot 3.4 평탄 키 모두 처리) | 없음 | 53 MB |
| node-exporter / cAdvisor | 호스트·컨테이너별 CPU·메모리·디스크 | 없음 | 8 / 74 MB |
| Grafana 12 | 대시보드·로그 탐색. 데이터소스·대시보드는 파일 프로비저닝 | 없음 | 116 MB |

- **네트워크**: 모니터링 전용 `monitoring` 네트워크 + Prometheus만 `snt-record_app-network`에 추가로 붙어 `snt-app:8090`, `couponnote-api:8081`을 이름으로 수집. 앱·DB compose는 손대지 않음
- **접근**: Grafana만 `192.168.35.122:3000`(LAN 주소)에 바인딩. 집 WiFi에서는 브라우저로 바로(회사 VPN 켜도 192.168.35.0/24는 로컬 경로라 열림), 밖에서는 `ssh -N -L 3000:192.168.35.122:3000 snt`(`~/.ssh/config`의 `snt` 별칭, 풀어 쓰면 `highjune@snt.o-r.kr`) 후 `localhost:3000`. 모뎀·공유기에 3000 포워딩 없음 → 인터넷에서 timeout. 서버 IP가 바뀌면 grafana 컨테이너가 못 뜨므로 공유기 DHCP 고정 할당 권장
- **계정**: admin 계정 `highjune`, 비밀번호는 서버 `services/monitoring/.env`(600)에만. 회원가입 off
- **앱 쪽 변경**: 쿠폰노트는 이미 actuator + ECS JSON 로그. 테니스는 PR #24(actuator, `application=tennis` 태그, http 히스토그램, beta ECS 로그) → 10/29 20:44 release 머지·Jenkins 배포 후 Prometheus `tennis` 타깃 UP(머지 전엔 HTML 에러 페이지를 받아 DOWN)
- **nginx**: 두 vhost에 `location ^~ /actuator/ { return 404; }` — 그 전까지 `couponnote.kr/actuator/prometheus`가 인터넷에 열려 있었음
- **Docker 로그 로테이션**: 두 앱 compose에 `json-file max-size 10m × 3` (전엔 무제한). 컨테이너 재생성으로 각 5초 중단
- **대시보드**(폴더 "홈서버"): `홈서버 앱 개요 (테니스 · 쿠폰노트)` — `app` 드롭다운, 상태/요청·초/5xx/응답시간/힙/CPU, 상태코드별 요청, 평균·p95, 엔드포인트 TOP10, GC, JVM·Hikari, Loki 레벨별 로그량·최근 로그(`search` 변수) + 커뮤니티 JVM(Micrometer) 4701 · Node Exporter Full 1860 · cAdvisor 14282 (`${DS_PROMETHEUS}` → uid `prometheus`로 치환해 파일 프로비저닝)
- **검증(10/29)**: Prometheus 타깃 prometheus/couponnote/node/cadvisor UP, Grafana에서 PromQL 쿠폰노트 req/s·힙 91MB 조회, Loki `app` 라벨 5종(tennis, couponnote, mysql, jenkins, infra) 적재 확인. 합계 메모리 ≈ 420 MB. PR #24 배포 후 `tennis` UP, `jvm_memory_used_bytes{application="tennis"}` 수집, Loki `level` 라벨 tennis=INFO/ERROR·couponnote=WARN 확인
- **삽질**: ① Spring Boot 버전마다 ECS JSON 키 모양이 다름 — 쿠폰노트(Boot 4)는 중첩 `{"log":{"level"}}`, 테니스(Boot 3.4)는 평탄 `{"log.level"}`. Alloy `stage.json`에서 JMESPath `log.level`은 중첩만, `"log.level"`(따옴표 식별자)은 평탄만 잡으므로 둘 다 뽑아 `stage.template`으로 합침 ② 기동 직후 Loki가 7일 넘은 옛 Jenkins 로그를 "timestamp too old"로 거부 — 초기 백필 1회성 ③ 서버 안에서 `curl https://couponnote.kr`은 헤어핀 NAT 때문에 응답 없음 → 외부 확인은 맥북에서 ④ 쿠폰노트는 micrometer `application` 태그가 없어 Prometheus static label로 보강(JVM 대시보드 변수용)
- **다음**: 알림(Grafana alerting → 카카오 나에게 보내기/메일), `/go` 클릭·경기 입력 같은 앱 커스텀 카운터, Jenkins 지표, 쿠폰노트 PR로 `application` 태그·p95 히스토그램 추가

## 7. 예정: 쿠폰 어필리에이트 사이트

- 같은 nginx에 `server_name coupon.<도메인>` 블록 추가 → 새 컨테이너(예: :8081)로 proxy_pass
- 도메인은 별도 구매, DNS는 Cloudflare로 관리 (DDNS 자동 갱신 + 정적 호스팅 동시 활용)
- 상세는 결정되면 `features/coupon-site/`에 기록

## 7-1. 2026-10-15 19:4x 외부 접속 두절 (미해결)

- 증상: couponnote-pipeline 빌드 #1이 `Finished: SUCCESS`로 끝난 직후부터 외부에서 22·80·443 전부 타임아웃. 공인 IP `ping`은 응답(모뎀 생존). snt.o-r.kr도 같이 불통.
- 가설: ① 공유기 WAN IP 변동으로 모뎀 포워딩 불일치(문서의 알려진 패턴) ② 서버 행/재부팅 ③ Gradle+docker build 부하(N100 4코어)로 일시 응답 불가. 현장 확인 전까지 **미규명**.
- 확인 순서(집에서): 미니PC 전원·화면 → 공유기 `192.168.35.1` 인터넷연결정보 IPv4가 `192.168.75.231`인지 → 모뎀 `192.168.75.1` 포워딩 로컬 IP 일치 여부 → `docker ps`로 couponnote-api 기동 여부.

## 8. 목표 아키텍처 (2026-10-15 계획)

README의 "목표 아키텍처" 섹션이 정본. 요지:

- 게이트웨이는 **nginx 하나**. Spring Cloud Gateway 등 별도 게이트웨이 두지 않음
- 신규: `coupon` 정적 사이트(nginx root), `coupon-api`(:8081, Docker), `tennis-mysql`에 `coupon` 스키마
- 모니터링: Prometheus + Grafana + Loki/promtail + node-exporter + cAdvisor (Docker, `grafana.<도메인>`으로 nginx 뒤에서 노출)
- 외부 포트는 22/80/443만. 3306·8080 포워딩 삭제
- Jenkins executor 1, `-Xmx2g`
