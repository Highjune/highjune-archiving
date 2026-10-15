# PLG Stack 상세 설계

## 개요

Prometheus + Loki + Grafana 스택을 tennis-record-k 홈서버 환경에 구축하기 위한 상세 설계입니다.

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Grafana (Port 3000)                            │
│                         http://snt.o-r.kr:3000                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │  System Dashboard │  │   App Dashboard  │  │   Log Explorer   │       │
│  │  (CPU/Mem/Disk)   │  │  (JVM/Requests)  │  │   (App Logs)     │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
└────────────────────┬────────────────────────────┬───────────────────────┘
                     │                            │
         ┌───────────▼───────────┐    ┌───────────▼───────────┐
         │     Prometheus        │    │        Loki           │
         │     (Port 9090)       │    │     (Port 3100)       │
         │   메트릭 저장 (15일)   │    │   로그 저장 (7일)      │
         └───────────┬───────────┘    └───────────┬───────────┘
                     │                            │
     ┌───────────────┼───────────────┐            │
     │               │               │            │
┌────▼────┐   ┌──────▼──────┐  ┌─────▼─────┐  ┌───▼────┐
│  node   │   │   snt-app   │  │ cAdvisor  │  │Promtail│
│exporter │   │  /actuator  │  │(Port 8080)│  │        │
│(:9100)  │   │  /metrics   │  │           │  │        │
└─────────┘   └─────────────┘  └───────────┘  └────────┘
     │               │               │            │
     └───────────────┴───────────────┴────────────┘
                         │
              ┌──────────┴──────────┐
              │   Docker Compose    │
              │    (monitoring)     │
              └─────────────────────┘
```

---

## 컴포넌트 상세

### 1. Prometheus (메트릭 수집)

**역할**: 시계열 메트릭 데이터 수집 및 저장

**수집 대상**:
| 타겟 | 엔드포인트 | 수집 내용 |
|-----|-----------|---------|
| snt-app | `:8090/actuator/prometheus` | JVM, HTTP 요청, 커스텀 메트릭 |
| node_exporter | `:9100/metrics` | CPU, 메모리, 디스크, 네트워크 |
| cAdvisor | `:8080/metrics` | 컨테이너별 리소스 사용량 |
| MySQL (선택) | `:9104/metrics` | MySQL 쿼리, 커넥션 |

**설정 예시** (`prometheus.yml`):
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Spring Boot Application
  - job_name: 'snt-app'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['snt-app:8090']
    
  # System Metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
    
  # Docker Container Metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    
  # MySQL (optional)
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysqld-exporter:9104']
```

**리소스 요구사항**:
- RAM: ~500MB
- Disk: ~1GB/월 (retention 15일 기준)

---

### 2. Loki (로그 수집)

**역할**: 로그 데이터 수집 및 저장 (라벨 기반 인덱싱)

**특징**:
- Elasticsearch와 달리 로그 내용을 인덱싱하지 않음
- 라벨(job, container, level 등)로 필터링 후 grep 방식 검색
- 저장 공간 효율적

**설정 예시** (`loki-config.yml`):
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  retention_period: 168h  # 7일

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  retention_enabled: true
```

**리소스 요구사항**:
- RAM: ~256MB
- Disk: ~500MB/월

---

### 3. Promtail (로그 수집 에이전트)

**역할**: Docker 컨테이너 로그를 수집하여 Loki로 전송

**설정 예시** (`promtail-config.yml`):
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log

    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[a-zA-Z0-9][a-zA-Z0-9_.-]+))
          source: tag
      - labels:
          container_name:
      - output:
          source: output
```

**리소스 요구사항**:
- RAM: ~50MB

---

### 4. node_exporter (시스템 메트릭)

**역할**: 호스트 시스템 메트릭 노출

**수집 메트릭**:
| 메트릭 | 설명 |
|-------|-----|
| `node_cpu_seconds_total` | CPU 사용량 |
| `node_memory_MemAvailable_bytes` | 가용 메모리 |
| `node_filesystem_avail_bytes` | 디스크 가용 공간 |
| `node_network_receive_bytes_total` | 네트워크 수신 바이트 |
| `node_load1` | 1분 로드 평균 |

**리소스 요구사항**:
- RAM: ~20MB

---

### 5. cAdvisor (컨테이너 메트릭)

**역할**: Docker 컨테이너별 리소스 사용량 노출

**수집 메트릭**:
| 메트릭 | 설명 |
|-------|-----|
| `container_cpu_usage_seconds_total` | 컨테이너 CPU 사용량 |
| `container_memory_usage_bytes` | 컨테이너 메모리 사용량 |
| `container_network_receive_bytes_total` | 컨테이너 네트워크 수신 |
| `container_fs_usage_bytes` | 컨테이너 파일시스템 사용량 |

**리소스 요구사항**:
- RAM: ~100MB

---

### 6. Grafana (시각화)

**역할**: 대시보드 및 알림

**추천 대시보드**:
| ID | 이름 | 용도 |
|---|-----|-----|
| 1860 | Node Exporter Full | 시스템 모니터링 |
| 893 | Docker Container | 컨테이너 모니터링 |
| 4701 | JVM Micrometer | Spring Boot JVM |
| 12900 | Spring Boot Statistics | HTTP 요청 통계 |

**리소스 요구사항**:
- RAM: ~256MB

---

## Docker Compose 구성

```yaml
version: '3.8'

services:
  # 메트릭 수집
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'
    networks:
      - monitoring

  # 로그 저장
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: always
    ports:
      - "3100:3100"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/local-config.yaml
      - loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - monitoring

  # 로그 수집
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: always
    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/config.yml
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring

  # 시스템 메트릭
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: always
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  # 컨테이너 메트릭
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: always
    ports:
      - "8081:8080"  # 8080은 snt-app 로컬용으로 사용 중
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

  # 시각화
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}  # .env 로 주입
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus-data:
  loki-data:
  grafana-data:
```

---

## Spring Boot 연동

### 1. 의존성 추가 (build.gradle.kts)

```kotlin
dependencies {
    // Actuator
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    
    // Micrometer Prometheus Registry
    runtimeOnly("io.micrometer:micrometer-registry-prometheus")
}
```

### 2. application.yml 설정

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
  endpoint:
    health:
      show-details: always
  metrics:
    tags:
      application: snt-app
```

### 3. 커스텀 메트릭 예시 (Kotlin)

```kotlin
@Component
class GameMetrics(private val meterRegistry: MeterRegistry) {
    
    private val gameCounter = Counter.builder("snt.games.recorded")
        .description("Number of games recorded")
        .register(meterRegistry)
    
    fun recordGame() {
        gameCounter.increment()
    }
}
```

---

## 디렉토리 구조

```
/home/highjune/services/monitoring/
├── docker-compose.yml
├── prometheus/
│   └── prometheus.yml
├── loki/
│   └── loki-config.yml
├── promtail/
│   └── promtail-config.yml
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── datasources.yml
        └── dashboards/
            └── dashboards.yml
```

---

## 포트 정리

| 서비스 | 포트 | 외부 노출 |
|-------|-----|---------|
| Grafana | 3000 | O (포트포워딩 필요) |
| Prometheus | 9090 | X (내부용) |
| Loki | 3100 | X (내부용) |
| node_exporter | 9100 | X (내부용) |
| cAdvisor | 8081 | X (내부용) |

---

## 리소스 총합

| 컴포넌트 | RAM | Disk/월 |
|---------|-----|---------|
| Prometheus | 500MB | 1GB |
| Loki | 256MB | 500MB |
| Grafana | 256MB | 100MB |
| Promtail | 50MB | - |
| node_exporter | 20MB | - |
| cAdvisor | 100MB | - |
| **총합** | **~1.2GB** | **~1.6GB** |

현재 가용 RAM 12GB 기준으로 충분히 운영 가능합니다.

---

## 구현 순서

### Phase 1: 기본 구축
1. [ ] Docker Compose 파일 작성
2. [ ] Prometheus 설정
3. [ ] Grafana 설정 및 데이터소스 연결
4. [ ] node_exporter로 시스템 메트릭 수집
5. [ ] 기본 대시보드 구성

### Phase 2: 애플리케이션 연동
1. [ ] snt-app에 Actuator + Micrometer 추가
2. [ ] Prometheus에서 snt-app 메트릭 수집
3. [ ] JVM/HTTP 대시보드 추가

### Phase 3: 로그 수집
1. [ ] Loki 설정
2. [ ] Promtail로 Docker 로그 수집
3. [ ] Grafana에서 로그 조회

### Phase 4: 고급 기능
1. [ ] cAdvisor 추가
2. [ ] 알림 규칙 설정
3. [ ] 커스텀 메트릭 추가

---

## 변경 이력

| 날짜 | 내용 |
|-----|-----|
| 2026-04-16 | 초안 작성 |
