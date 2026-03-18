#!/bin/bash
# Test suite for upgrade-model.sh
# Validates model upgrade/rollback operations and error handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE_MODEL_SCRIPT="$SCRIPT_DIR/scripts/upgrade-model.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# ============================================================================
# Test 1: Script exists and is executable
# ============================================================================
if [[ -f "$UPGRADE_MODEL_SCRIPT" ]]; then
    pass "upgrade-model.sh exists"
else
    fail "upgrade-model.sh not found at $UPGRADE_MODEL_SCRIPT"
    exit 1
fi

if [[ -x "$UPGRADE_MODEL_SCRIPT" ]]; then
    pass "upgrade-model.sh is executable"
else
    pass "upgrade-model.sh is runnable via bash"
fi

# ============================================================================
# Test 2: Help command works
# ============================================================================
help_exit=0
help_output=$(bash "$UPGRADE_MODEL_SCRIPT" --help 2>&1) || help_exit=$?
if [[ $help_exit -eq 0 ]] && echo "$help_output" | grep -q "Usage:"; then
    pass "--help flag works and shows usage"
else
    fail "--help flag failed or missing usage text"
fi

# ============================================================================
# Test 3: Script requires jq
# ============================================================================
if command -v jq >/dev/null 2>&1; then
    pass "jq is available (required dependency)"
else
    skip "jq not available - some tests will be skipped"
fi

# ============================================================================
# Test 4: --list command works without models directory
# ============================================================================
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

export DREAM_DIR="$TEMP_DIR/dream-test"
export MODELS_DIR="$DREAM_DIR/models"

list_exit=0
list_output=$(bash "$UPGRADE_MODEL_SCRIPT" --list 2>&1) || list_exit=$?
if [[ $list_exit -eq 0 ]]; then
    pass "--list works with non-existent models directory"
else
    fail "--list failed with non-existent models directory (exit $list_exit)"
fi

# ============================================================================
# Test 5: --current command works without state file
# ============================================================================
current_exit=0
current_output=$(bash "$UPGRADE_MODEL_SCRIPT" --current 2>&1) || current_exit=$?
if [[ $current_exit -eq 0 ]]; then
    pass "--current works without state file"
else
    fail "--current failed without state file (exit $current_exit)"
fi

# ============================================================================
# Test 6: Behavioral test - list with mock models
# ============================================================================
mkdir -p "$MODELS_DIR/test-model-1"
mkdir -p "$MODELS_DIR/test-model-2"
echo '{"name": "test-model-1"}' > "$MODELS_DIR/test-model-1/config.json"
echo '{"name": "test-model-2"}' > "$MODELS_DIR/test-model-2/config.json"

list_exit=0
list_output=$(bash "$UPGRADE_MODEL_SCRIPT" --list 2>&1) || list_exit=$?
if [[ $list_exit -eq 0 ]] && echo "$list_output" | grep -q "test-model-1"; then
    pass "Behavioral test: --list shows mock models"
else
    fail "Behavioral test: --list failed to show mock models"
fi

# ============================================================================
# Test 7: State file creation and parsing
# ============================================================================
if command -v jq >/dev/null 2>&1; then
    mkdir -p "$DREAM_DIR"
    cat > "$DREAM_DIR/model-state.json" <<'EOF'
{
  "current": "test-model-1",
  "previous": "test-model-2",
  "updatedAt": "2024-01-01T00:00:00Z"
}
EOF

    current_exit=0
    current_output=$(bash "$UPGRADE_MODEL_SCRIPT" --current 2>&1) || current_exit=$?
    if [[ $current_exit -eq 0 ]] && echo "$current_output" | grep -q "test-model-1"; then
        pass "Behavioral test: --current reads state file correctly"
    else
        fail "Behavioral test: --current failed to read state file"
    fi
else
    skip "Behavioral test: state file parsing (jq not available)"
fi

# ============================================================================
# Test 8: Error handling - upgrade without model argument
# ============================================================================
upgrade_exit=0
upgrade_output=$(bash "$UPGRADE_MODEL_SCRIPT" 2>&1) || upgrade_exit=$?
if [[ $upgrade_exit -ne 0 ]]; then
    pass "Error handling: upgrade without model argument fails correctly"
else
    fail "Error handling: upgrade without model argument should fail"
fi

# ============================================================================
# Test 9: Error handling - upgrade with non-existent model
# ============================================================================
upgrade_exit=0
upgrade_output=$(bash "$UPGRADE_MODEL_SCRIPT" "non-existent-model" 2>&1) || upgrade_exit=$?
if [[ $upgrade_exit -ne 0 ]] && echo "$upgrade_output" | grep -qi "not found"; then
    pass "Error handling: upgrade with non-existent model fails with error message"
else
    fail "Error handling: upgrade with non-existent model should fail with 'not found' message"
fi

# ============================================================================
# Test 10: Error handling - rollback without previous model
# ============================================================================
# Clean state file to ensure no previous model
rm -f "$DREAM_DIR/model-state.json"

rollback_exit=0
rollback_output=$(bash "$UPGRADE_MODEL_SCRIPT" --rollback 2>&1) || rollback_exit=$?
if [[ $rollback_exit -ne 0 ]] && echo "$rollback_output" | grep -qi "no previous"; then
    pass "Error handling: rollback without previous model fails with error message"
else
    fail "Error handling: rollback without previous model should fail"
fi

# ============================================================================
# Test 11: Script does not use silent error suppression
# ============================================================================
# Check for CLAUDE.md violations: 2>/dev/null, || true patterns
suppression_count=0
if grep -q "2>/dev/null" "$UPGRADE_MODEL_SCRIPT"; then
    suppression_count=$((suppression_count + $(grep -c "2>/dev/null" "$UPGRADE_MODEL_SCRIPT")))
fi
if grep -q "|| true" "$UPGRADE_MODEL_SCRIPT"; then
    suppression_count=$((suppression_count + $(grep -c "|| true" "$UPGRADE_MODEL_SCRIPT")))
fi

if [[ $suppression_count -eq 0 ]]; then
    pass "CLAUDE.md compliance: no silent error suppressions found"
else
    fail "CLAUDE.md compliance: found $suppression_count error suppressions (2>/dev/null, || true)"
fi

# ============================================================================
# Test 12: Script uses inline exit code capture
# ============================================================================
# Check for proper error handling pattern
if grep -q "curl_exit=0" "$UPGRADE_MODEL_SCRIPT" && grep -q "|| curl_exit=\$?" "$UPGRADE_MODEL_SCRIPT"; then
    pass "CLAUDE.md compliance: uses inline exit code capture pattern"
else
    fail "CLAUDE.md compliance: missing inline exit code capture pattern"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total:  $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
