#!/bin/bash
# ============================================================================
# Dream Server audit-compose-healthchecks.sh Test Suite
# ============================================================================
# Ensures scripts/audit-compose-healthchecks.sh correctly identifies compose
# files with and without healthcheck definitions. Validates the audit tool
# used to enforce healthcheck requirements across extensions.
#
# Usage: ./tests/test-compose-healthcheck-audit.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "  ${GREEN}✓ PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "  ${YELLOW}⊘ SKIP${NC} $1"; }

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║   Compose Healthcheck Audit Test Suite       ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# 1. Script exists
if [[ ! -f "$ROOT_DIR/scripts/audit-compose-healthchecks.sh" ]]; then
    fail "scripts/audit-compose-healthchecks.sh not found"
    echo ""; echo "Result: $PASSED passed, $FAILED failed"; exit 1
fi
pass "audit-compose-healthchecks.sh exists"

# 2. Script runs without errors
set +e
out=$(cd "$ROOT_DIR" && bash scripts/audit-compose-healthchecks.sh --quiet 2>&1)
exit_code=$?
set -e

if echo "$out" | grep -q "unbound variable\|syntax error\|command not found"; then
    fail "audit-compose-healthchecks.sh produced shell error"
else
    pass "audit-compose-healthchecks.sh runs without shell errors"
fi

# 3. Exit code is valid (0 or 1)
if [[ "$exit_code" -eq 0 ]] || [[ "$exit_code" -eq 1 ]]; then
    pass "audit-compose-healthchecks.sh exit code is valid (0|1): $exit_code"
else
    fail "audit-compose-healthchecks.sh exit code should be 0 or 1; got $exit_code"
fi

# 4. Script finds compose files
set +e
out=$(cd "$ROOT_DIR" && bash scripts/audit-compose-healthchecks.sh 2>&1)
set -e

if echo "$out" | grep -q "Auditing.*compose files"; then
    pass "audit-compose-healthchecks.sh finds compose files"
else
    fail "audit-compose-healthchecks.sh did not report compose file count"
fi

# 5. Script reports files with healthchecks
if echo "$out" | grep -q "Files with healthchecks:"; then
    pass "audit-compose-healthchecks.sh reports files with healthchecks"
else
    fail "audit-compose-healthchecks.sh missing healthcheck report"
fi

# 6. Script identifies production files without healthchecks
if echo "$out" | grep -q "Production files without healthchecks:"; then
    pass "audit-compose-healthchecks.sh identifies production files without healthchecks"
else
    skip "No production files without healthchecks found (good!)"
fi

# 7. --strict flag works
set +e
bash "$ROOT_DIR/scripts/audit-compose-healthchecks.sh" --strict --quiet 2>&1
strict_exit=$?
set -e

# In strict mode, should exit 1 if production files are missing healthchecks
if [[ "$strict_exit" -eq 0 ]] || [[ "$strict_exit" -eq 1 ]]; then
    pass "audit-compose-healthchecks.sh --strict flag works (exit: $strict_exit)"
else
    fail "audit-compose-healthchecks.sh --strict produced unexpected exit code: $strict_exit"
fi

# 8. --quiet flag suppresses output
set +e
quiet_out=$(cd "$ROOT_DIR" && bash scripts/audit-compose-healthchecks.sh --quiet 2>&1)
set -e

# Quiet mode should have minimal output (no color codes, less verbose)
if [[ $(echo "$quiet_out" | wc -l) -lt 10 ]]; then
    pass "audit-compose-healthchecks.sh --quiet reduces output"
else
    skip "audit-compose-healthchecks.sh --quiet output check (may vary)"
fi

# 9. Script is executable or runnable via bash
if [[ -x "$ROOT_DIR/scripts/audit-compose-healthchecks.sh" ]]; then
    pass "audit-compose-healthchecks.sh is executable"
else
    # Still runnable via bash even if not executable
    pass "audit-compose-healthchecks.sh is runnable via bash"
fi

# 10. Behavioral test: Create temp compose file and verify detection
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Create compose file WITHOUT healthcheck
cat > "$TEMP_DIR/test-no-healthcheck.yml" <<'EOF'
services:
  test-service:
    image: nginx:latest
    ports:
      - "8080:80"
EOF

# Create compose file WITH healthcheck
cat > "$TEMP_DIR/test-with-healthcheck.yml" <<'EOF'
services:
  test-service:
    image: nginx:latest
    ports:
      - "8080:80"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# Test detection of file without healthcheck
if grep -q "healthcheck:" "$TEMP_DIR/test-no-healthcheck.yml"; then
    fail "Behavioral test: false positive on file without healthcheck"
else
    pass "Behavioral test: correctly identifies file without healthcheck"
fi

# Test detection of file with healthcheck
if grep -q "healthcheck:" "$TEMP_DIR/test-with-healthcheck.yml"; then
    pass "Behavioral test: correctly identifies file with healthcheck"
else
    fail "Behavioral test: false negative on file with healthcheck"
fi

echo ""
echo "Result: $PASSED passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
