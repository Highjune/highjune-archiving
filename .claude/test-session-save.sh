#!/bin/bash

# SessionEnd 훅 테스트 스크립트

SCRIPT_DIR="/Users/kangjune-heo/workspace/highjune/highjune-archiving/.claude/save-session.sh"

echo "=== Testing SessionEnd hook ==="
echo ""

# 테스트 1: tennis-record-k > kakao-vote-automation
echo "Test 1: Tennis + Kakao Vote Automation"
test_session1='{
  "session_id": "test-vote-'$(date +%s)'",
  "transcript": "테니스 경기 후 카카오톡 투표를 자동화하고 싶어. tennis-record-k 프로젝트에 vote automation을 추가해줘.",
  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}'
echo "$test_session1" | $SCRIPT_DIR
echo ""

sleep 1

# 테스트 2: tennis-record-k > general
echo "Test 2: Tennis General"
test_session2='{
  "session_id": "test-tennis-'$(date +%s)'",
  "transcript": "tennis-record-k 프로젝트의 JPA 설정에 대해 알려줘. snt 앱 개발 중이야.",
  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}'
echo "$test_session2" | $SCRIPT_DIR
echo ""

sleep 1

# 테스트 3: general
echo "Test 3: General (no project)"
test_session3='{
  "session_id": "test-general-'$(date +%s)'",
  "transcript": "Python으로 웹 스크래핑하는 방법 알려줘.",
  "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
}'
echo "$test_session3" | $SCRIPT_DIR
echo ""

# 결과 확인
echo "=== Sessions directory structure ==="
tree /Users/kangjune-heo/workspace/highjune/highjune-archiving/sessions/ 2>/dev/null || find /Users/kangjune-heo/workspace/highjune/highjune-archiving/sessions/ -type f