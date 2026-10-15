# ELK Stack 상세 설계

## 개요

Elasticsearch + Logstash + Kibana 스택 설계입니다. 
**참고용으로 작성되었으며, 홈서버 환경에서는 PLG 스택을 권장합니다.**

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Kibana (Port 5601)                             │
│                         http://snt.o-r.kr:5601                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │   Discover       │  │   Dashboard      │  │   Visualize      │       │
│  │  (로그 검색)      │  │  (대시보드)       │  │   (시각화)        │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                     ┌───────────▼───────────┐
                     │    Elasticsearch      │
                     │     (Port 9200)       │
                     │   로그 저장/검색        │
                     │    (4-8GB RAM)        │
                     └───────────┬───────────┘
                                 │
                     ┌───────────▼───────────┐
                     │      Logstash         │
                     │     (Port 5044)       │
                     │   로그 수집/파싱        │
                     │    (1-2GB RAM)        │
                     └───────────┬───────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
        ┌─────▼─────┐      ┌─────▼─────┐     ┌─────▼─────┐
        │ Filebeat  │      │ Filebeat  │     │ Metricbeat│
        │ (snt-app) │      │ (mysql)   │     │ (시스템)   │
        └───────────┘      └───────────┘     └───────────┘
```

---

## 컴포넌트 상세

### 1. Elasticsearch

**역할**: 로그 저장 및 전문 검색 엔진

**특징**:
- 전문 검색 (Full-text search)
- 분산 저장 가능
- 실시간 검색

**리소스 요구사항**:
- RAM: **최소 4GB, 권장 8GB** (JVM 힙 사이즈)
- Disk: 로그량에 따라 다름 (압축 저장)

**설정 예시** (`elasticsearch.yml`):
```yaml
cluster.name: snt-cluster
node.name: snt-node-1
network.host: 0.0.0.0
discovery.type: single-node

# 메모리 설정 (jvm.options에서 설정)
# -Xms4g
# -Xmx4g
```

---

### 2. Logstash

**역할**: 로그 수집, 파싱, 변환

**특징**:
- 다양한 입력 플러그인 (Filebeat, Kafka, HTTP 등)
- 필터링 및 변환 (grok, mutate, date 등)
- 다양한 출력 대상

**리소스 요구사항**:
- RAM: 1-2GB

**설정 예시** (`logstash.conf`):
```ruby
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][type] == "spring-boot" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{NUMBER:pid} --- \[%{DATA:thread}\] %{DATA:logger} : %{GREEDYDATA:log_message}" 
      }
    }
    date {
      match => [ "timestamp", "yyyy-MM-dd HH:mm:ss.SSS" ]
      target => "@timestamp"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "snt-logs-%{+YYYY.MM.dd}"
  }
}
```

---

### 3. Filebeat

**역할**: 경량 로그 수집기 (Logstash 대신 직접 사용 가능)

**특징**:
- Logstash보다 훨씬 가벼움
- 직접 Elasticsearch로 전송 가능
- Docker 로그 수집 지원

**리소스 요구사항**:
- RAM: ~100MB

**설정 예시** (`filebeat.yml`):
```yaml
filebeat.inputs:
  - type: container
    paths:
      - '/var/lib/docker/containers/*/*.log'
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"

output.logstash:
  hosts: ["logstash:5044"]

# 또는 직접 Elasticsearch로
# output.elasticsearch:
#   hosts: ["elasticsearch:9200"]
```

---

### 4. Metricbeat (선택)

**역할**: 시스템/서비스 메트릭 수집

**수집 대상**:
- 시스템 메트릭 (CPU, 메모리, 디스크)
- Docker 컨테이너 메트릭
- MySQL 메트릭

**리소스 요구사항**:
- RAM: ~100MB

---

### 5. Kibana

**역할**: 시각화 및 로그 탐색

**주요 기능**:
- Discover: 로그 검색 및 탐색
- Dashboard: 시각화 대시보드
- Dev Tools: Elasticsearch 쿼리 실행

**리소스 요구사항**:
- RAM: ~1GB

---

## Docker Compose 구성

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    restart: always
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - elk
    mem_limit: 6g

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    restart: always
    ports:
      - "5044:5044"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
    depends_on:
      - elasticsearch
    networks:
      - elk
    mem_limit: 2g

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    restart: always
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - elk
    mem_limit: 1g

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    container_name: filebeat
    restart: always
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - logstash
    networks:
      - elk

networks:
  elk:
    driver: bridge

volumes:
  elasticsearch-data:
```

---

## 리소스 총합

| 컴포넌트 | RAM (최소) | RAM (권장) |
|---------|-----------|-----------|
| Elasticsearch | 4GB | 8GB |
| Logstash | 1GB | 2GB |
| Kibana | 512MB | 1GB |
| Filebeat | 100MB | 100MB |
| **총합** | **5.6GB** | **11.1GB** |

---

## PLG vs ELK 비교

| 항목 | PLG Stack | ELK Stack |
|-----|-----------|-----------|
| RAM 사용량 | ~1.2GB | ~6-11GB |
| 로그 검색 | 라벨 기반 + grep | 전문 검색 |
| 복잡한 쿼리 | 제한적 | 강력함 |
| 메트릭 수집 | 내장 (Prometheus) | 별도 (Metricbeat) |
| 학습 곡선 | 보통 | 높음 |
| 운영 복잡도 | 낮음 | 높음 |
| 홈서버 적합 | 적합 | 부적합 |

---

## 홈서버에서 ELK를 사용하려면

만약 ELK를 사용해야 한다면:

### 경량화 방안

1. **Elasticsearch 단독 사용** (Logstash 없이)
   - Filebeat → Elasticsearch 직접 전송
   - RAM 절약: ~2GB

2. **메모리 제한**
   ```yaml
   ES_JAVA_OPTS=-Xms2g -Xmx2g
   ```

3. **인덱스 보존 기간 단축**
   ```json
   {
     "policy": {
       "phases": {
         "delete": {
           "min_age": "3d",
           "actions": { "delete": {} }
         }
       }
     }
   }
   ```

4. **복제본 비활성화** (단일 노드)
   ```
   index.number_of_replicas: 0
   ```

### 최소 구성 (Elasticsearch + Kibana + Filebeat)

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
    mem_limit: 3g
    # ... 나머지 설정

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    mem_limit: 512m
    # ... 나머지 설정

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    # ... 나머지 설정
```

이 경우에도 총 **~4GB RAM** 필요합니다.

---

## 결론

| 환경 | 권장 스택 |
|-----|---------|
| 홈서버 (RAM 16GB 이하) | **PLG Stack** |
| 충분한 리소스 (RAM 32GB+) | ELK Stack 고려 가능 |
| 복잡한 로그 분석 필수 | ELK Stack |
| 메트릭 + 로그 통합 | PLG Stack |

현재 홈서버 환경(RAM 16GB, 가용 12GB)에서는 **PLG Stack을 강력히 권장**합니다.

---

## 변경 이력

| 날짜 | 내용 |
|-----|-----|
| 2026-04-16 | 초안 작성 (참고용) |
