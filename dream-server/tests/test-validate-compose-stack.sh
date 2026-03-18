#!/bin/bash
# ============================================================================
# Dream Server validate-compose-stack.sh Test Suite
# ============================================================================
# Ensures scripts/validate-compose-stack.sh correctly validates Docker Compose
# stacks and that resolve-compose-stack.sh produces valid output for all GPU
# backends. Tests the actual runtime stack architecture.
#
# Usage: ./tests/test-validate-compose-stack.sh
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
echo "║   Compose Stack Validation Test Suite        ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# 1. validate-compose-stack.sh exists
if [[ ! -f "$ROOT_DIR/scripts/validate-compose-stack.sh" ]]; then
    fail "scripts/validate-compose-stack.sh not found"
    echo ""; echo "Result: $PASSED passed, $FAILED failed"; exit 1
fi
pass "validate-compose-stack.sh exists"

# 2. resolve-compose-stack.sh exists
if [[ ! -f "$ROOT_DIR/scripts/resolve-compose-stack.sh" ]]; then
    fail "scripts/resolve-compose-stack.sh not found"
    echo ""; echo "Result: $PASSED passed, $FAILED failed"; exit 1
fi
pass "resolve-compose-stack.sh exists"

# 3. Check if docker compose is available
if ! command -v docker >/dev/null; then
    skip "docker not available - skipping validation tests"
    echo ""; echo "Result: $PASSED passed, $FAILED failed (docker required for full tests)"
    exit 0
fi

docker_compose_exit=0
docker compose version >/dev/null 2>&1 || docker_compose_exit=$?
docker_compose_cmd_exit=0
command -v docker-compose >/dev/null 2>&1 || docker_compose_cmd_exit=$?

if [[ $docker_compose_exit -ne 0 ]] && [[ $docker_compose_cmd_exit -ne 0 ]]; then
    skip "docker compose not available - skipping validation tests"
    echo ""; echo "Result: $PASSED passed, $FAILED failed (docker compose required)"
    exit 0
fi
pass "docker compose is available"

# 4. Base compose file exists
if [[ ! -f "$ROOT_DIR/docker-compose.base.yml" ]]; then
    fail "docker-compose.base.yml not found"
else
    pass "docker-compose.base.yml exists"
fi

# 5. GPU overlay files exist
overlays=("nvidia" "amd" "apple" "arc" "intel")
for overlay in "${overlays[@]}"; do
    if [[ -f "$ROOT_DIR/docker-compose.$overlay.yml" ]]; then
        pass "docker-compose.$overlay.yml exists"
    else
        skip "docker-compose.$overlay.yml not found (optional)"
    fi
done

# 6. Test resolve-compose-stack.sh for each GPU backend
cd "$ROOT_DIR"
for backend in nvidia amd apple; do
    resolve_exit=0
    flags=$(bash scripts/resolve-compose-stack.sh --script-dir "$ROOT_DIR" --tier 1 --gpu-backend "$backend" 2>&1) || resolve_exit=$?

    if [[ $resolve_exit -eq 0 ]] && [[ -n "$flags" ]]; then
        pass "resolve-compose-stack.sh works for backend: $backend"
    else
        fail "resolve-compose-stack.sh failed for backend: $backend"
    fi
done

# 7. Validate base + nvidia overlay stack
if [[ -f "$ROOT_DIR/docker-compose.base.yml" ]] && [[ -f "$ROOT_DIR/docker-compose.nvidia.yml" ]]; then
    nvidia_exit=0
    docker compose -f docker-compose.base.yml -f docker-compose.nvidia.yml config --quiet 2>&1 || nvidia_exit=$?

    if [[ $nvidia_exit -eq 0 ]]; then
        pass "base + nvidia overlay validates successfully"
    else
        fail "base + nvidia overlay validation failed"
    fi
else
    skip "nvidia overlay not available"
fi

# 8. Validate base + amd overlay stack
if [[ -f "$ROOT_DIR/docker-compose.base.yml" ]] && [[ -f "$ROOT_DIR/docker-compose.amd.yml" ]]; then
    amd_exit=0
    docker compose -f docker-compose.base.yml -f docker-compose.amd.yml config --quiet 2>&1 || amd_exit=$?

    if [[ $amd_exit -eq 0 ]]; then
        pass "base + amd overlay validates successfully"
    else
        fail "base + amd overlay validation failed"
    fi
else
    skip "amd overlay not available"
fi

# 9. Validate base + apple overlay stack
if [[ -f "$ROOT_DIR/docker-compose.base.yml" ]] && [[ -f "$ROOT_DIR/docker-compose.apple.yml" ]]; then
    apple_exit=0
    docker compose -f docker-compose.base.yml -f docker-compose.apple.yml config --quiet 2>&1 || apple_exit=$?

    if [[ $apple_exit -eq 0 ]]; then
        pass "base + apple overlay validates successfully"
    else
        fail "base + apple overlay validation failed"
    fi
else
    skip "apple overlay not available"
fi

# 10. Test validate-compose-stack.sh with valid flags
validate_exit=0
bash scripts/validate-compose-stack.sh --compose-flags "-f docker-compose.base.yml" --quiet 2>&1 || validate_exit=$?

if [[ $validate_exit -eq 0 ]]; then
    pass "validate-compose-stack.sh accepts valid compose flags"
else
    fail "validate-compose-stack.sh failed with valid flags"
fi

# 11. Test validate-compose-stack.sh rejects missing --compose-flags
missing_flags_exit=0
bash scripts/validate-compose-stack.sh --quiet 2>&1 || missing_flags_exit=$?

if [[ $missing_flags_exit -ne 0 ]]; then
    pass "validate-compose-stack.sh rejects missing --compose-flags"
else
    fail "validate-compose-stack.sh should fail without --compose-flags"
fi

# 12. Count extension compose files
ext_compose_count=$(find extensions/services -name "compose.yaml" -o -name "compose.*.yaml" | wc -l)
if [[ $ext_compose_count -gt 0 ]]; then
    pass "found $ext_compose_count extension compose files"
else
    skip "no extension compose files found"
fi

# 13. Validate a sample extension compose file
sample_ext=$(find extensions/services -name "compose.yaml" | head -1)
if [[ -n "$sample_ext" ]] && [[ -f "$sample_ext" ]]; then
    ext_exit=0
    docker compose -f "$sample_ext" config --quiet 2>&1 || ext_exit=$?

    if [[ $ext_exit -eq 0 ]]; then
        pass "sample extension compose file validates: $(basename "$(dirname "$sample_ext")")"
    else
        fail "sample extension compose file failed validation"
    fi
else
    skip "no extension compose files to validate"
fi

echo ""
echo "Result: $PASSED passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
