#!/bin/bash

# 세션 자동 저장 스크립트
# SessionEnd 훅에서 호출됨
# 파일명 형식: YYYY-MM-DD_{keyword}.md

set -euo pipefail

# 프로젝트 루트
PROJECT_ROOT="/Users/kangjune-heo/workspace/highjune/highjune-archiving"
SESSIONS_DIR="$PROJECT_ROOT/sessions"

# stdin에서 JSON 읽기
input=$(cat)

# session_id 추출
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

# 날짜 생성 (YYYY-MM-DD 형식)
date_str=$(date +"%Y-%m-%d")
timestamp=$(date +"%H%M%S")

# 세션 내용 추출
session_content=$(echo "$input" | jq -r '.transcript // .content // "No content"')

# 프로젝트 분류
project_category="general"
sub_category=""

# 키워드 추출 함수
extract_keyword() {
    local content="$1"
    local keyword=""

    # 우선순위별 키워드 매칭
    if echo "$content" | grep -qiE "(카카오.*투표|투표.*자동화|kakao.*vote)"; then
        keyword="kakao-vote"
    elif echo "$content" | grep -qiE "(아키텍처|architecture|설계)"; then
        keyword="architecture"
    elif echo "$content" | grep -qiE "(디버그|debug|버그|bug|에러|error)"; then
        keyword="debug"
    elif echo "$content" | grep -qiE "(배포|deploy|docker|ci.?cd)"; then
        keyword="deploy"
    elif echo "$content" | grep -qiE "(테스트|test)"; then
        keyword="test"
    elif echo "$content" | grep -qiE "(리팩토링|refactor)"; then
        keyword="refactor"
    elif echo "$content" | grep -qiE "(세션|session|정리|구조|structure)"; then
        keyword="structure"
    elif echo "$content" | grep -qiE "(설정|config|setup)"; then
        keyword="setup"
    elif echo "$content" | grep -qiE "(문서|documentation|readme)"; then
        keyword="docs"
    elif echo "$content" | grep -qiE "(api|엔드포인트|endpoint)"; then
        keyword="api"
    elif echo "$content" | grep -qiE "(데이터베이스|database|db|mysql|jpa)"; then
        keyword="database"
    elif echo "$content" | grep -qiE "(인증|auth|로그인|login)"; then
        keyword="auth"
    elif echo "$content" | grep -qiE "(모니터링|monitoring|grafana|prometheus|loki|elk|로그|log)"; then
        keyword="monitoring"
    elif echo "$content" | grep -qiE "(메트릭|metric|cpu|메모리|memory|디스크|disk)"; then
        keyword="metrics"
    else
        keyword="general"
    fi

    echo "$keyword"
}

# 키워드 기반 분류
if echo "$session_content" | grep -qiE "(테니스|tennis|snt|tennis-record-k)"; then
    project_category="tennis-record-k"

    # tennis-record-k 내에서 하위 분류
    if echo "$session_content" | grep -qiE "(카카오톡|투표|kakao|vote|automation)"; then
        sub_category="kakao-vote-automation"
    else
        sub_category="general"
    fi
fi

# 키워드 추출
keyword=$(extract_keyword "$session_content")

# 프로젝트별 디렉토리 생성
if [ -n "$sub_category" ]; then
    project_dir="$SESSIONS_DIR/$project_category/$sub_category"
else
    project_dir="$SESSIONS_DIR/$project_category"
fi
mkdir -p "$project_dir"

# 파일명 생성: YYYY-MM-DD_keyword.md
# 같은 날짜에 같은 키워드가 있으면 숫자 suffix 추가
base_filename="${date_str}_${keyword}"
session_file="$project_dir/${base_filename}.md"

# 중복 파일 처리
counter=1
while [ -f "$session_file" ]; do
    session_file="$project_dir/${base_filename}_${counter}.md"
    ((counter++))
done

# 상대 경로 계산 (메시지용)
filename=$(basename "$session_file")
if [ -n "$sub_category" ]; then
    relative_path="$project_category/$sub_category/$filename"
    category_display="$project_category > $sub_category"
else
    relative_path="$project_category/$filename"
    category_display="$project_category"
fi

# raw 파일명도 동일 형식으로
raw_filename="${base_filename}_raw.json"
raw_file="$project_dir/$raw_filename"
counter=1
while [ -f "$raw_file" ]; do
    raw_file="$project_dir/${base_filename}_${counter}_raw.json"
    ((counter++))
done

# raw 데이터 저장
echo "$input" > "$raw_file"

# 세션 저장
cat > "$session_file" <<EOF
# Session: $session_id
**Date**: $(date +"%Y-%m-%d %H:%M:%S")
**Category**: $category_display
**Keyword**: $keyword

---

## Session Content

$session_content

---

**Session ID**: $session_id
**Saved at**: $(date)
EOF

# 성공 메시지 출력 (JSON 형식)
echo "{\"systemMessage\": \"✅ Session saved: $relative_path\"}"