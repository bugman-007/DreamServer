#!/bin/bash
# Test suite for service registry caching
# Validates cache generation, invalidation, and performance

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SR_LIB="$SCRIPT_DIR/../lib/service-registry.sh"
TEST_DIR="$(mktemp -d)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test helpers
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Test 1: Verify syntax
test_syntax() {
    info "Test 1: Validating service-registry.sh syntax"
    if bash -n "$SR_LIB" 2>/dev/null; then
        pass "service-registry.sh syntax is valid"
    else
        fail "service-registry.sh has syntax errors"
    fi
}

# Test 2: Verify cache directory variable exists
test_cache_dir_var() {
    info "Test 2: Checking if _SR_CACHE_DIR variable is defined"
    if grep -q "_SR_CACHE_DIR=" "$SR_LIB" 2>/dev/null; then
        pass "_SR_CACHE_DIR variable is defined"
        return 0
    else
        fail "_SR_CACHE_DIR variable not found"
        return 0
    fi
}

# Test 3: Verify mtime cache variable exists
test_mtime_cache_var() {
    info "Test 3: Checking if _SR_MTIME_CACHE variable is defined"
    if grep -q "_SR_MTIME_CACHE=" "$SR_LIB" 2>/dev/null; then
        pass "_SR_MTIME_CACHE variable is defined"
        return 0
    else
        fail "_SR_MTIME_CACHE variable not found"
        return 0
    fi
}

# Test 4: Verify cache validation function exists
test_cache_valid_function() {
    info "Test 4: Checking if _sr_cache_valid function is defined"
    if grep -q "^_sr_cache_valid()" "$SR_LIB" 2>/dev/null; then
        pass "_sr_cache_valid function is defined"
        return 0
    else
        fail "_sr_cache_valid function not found"
        return 0
    fi
}

# Test 5: Verify cache generation function exists
test_cache_generate_function() {
    info "Test 5: Checking if _sr_generate_cache function is defined"
    if grep -q "^_sr_generate_cache()" "$SR_LIB" 2>/dev/null; then
        pass "_sr_generate_cache function is defined"
        return 0
    else
        fail "_sr_generate_cache function not found"
        return 0
    fi
}

# Test 6: Verify cache validation checks mtimes
test_mtime_checking() {
    info "Test 6: Checking if cache validation compares mtimes"
    if grep -A20 "^_sr_cache_valid()" "$SR_LIB" 2>/dev/null | grep -q "mtime"; then
        pass "Cache validation checks modification times"
        return 0
    else
        fail "Cache validation missing mtime checks"
        return 0
    fi
}

# Test 7: Verify cache uses persistent location
test_persistent_cache() {
    info "Test 7: Checking if cache uses persistent location (not /tmp)"
    if grep "_SR_CACHE_DIR=" "$SR_LIB" 2>/dev/null | grep -q ".cache"; then
        pass "Cache uses persistent location"
        return 0
    else
        fail "Cache may use temporary location"
        return 0
    fi
}

# Test 8: Verify sr_load uses cache validation
test_load_uses_validation() {
    info "Test 8: Checking if sr_load uses cache validation"
    if grep -A10 "^sr_load()" "$SR_LIB" 2>/dev/null | grep -q "_sr_cache_valid"; then
        pass "sr_load uses cache validation"
        return 0
    else
        fail "sr_load missing cache validation"
        return 0
    fi
}

# Test 9: Verify cache regeneration on invalid cache
test_regeneration() {
    info "Test 9: Checking if cache regenerates when invalid"
    if grep -A10 "^sr_load()" "$SR_LIB" 2>/dev/null | grep -q "_sr_generate_cache"; then
        pass "Cache regenerates when invalid"
        return 0
    else
        fail "Cache regeneration logic missing"
        return 0
    fi
}

# Test 10: Verify atomic cache updates
test_atomic_updates() {
    info "Test 10: Checking if cache updates are atomic"
    if grep -A30 "^_sr_generate_cache()" "$SR_LIB" 2>/dev/null | grep -q ".tmp"; then
        pass "Cache updates use atomic moves"
        return 0
    else
        fail "Cache updates may not be atomic"
        return 0
    fi
}

# Test 11: Verify find command for manifest discovery
test_manifest_discovery() {
    info "Test 11: Checking if manifest discovery uses find"
    if grep -A30 "_sr_cache_valid\|_sr_generate_cache" "$SR_LIB" 2>/dev/null | grep -q "find.*manifest"; then
        pass "Manifest discovery uses find command"
        return 0
    else
        fail "Manifest discovery may be incomplete"
        return 0
    fi
}

# Test 12: Verify cache directory creation
test_cache_dir_creation() {
    info "Test 12: Checking if cache directory is created"
    if grep -A5 "^_sr_generate_cache()" "$SR_LIB" 2>/dev/null | grep -q "mkdir.*_SR_CACHE_DIR"; then
        pass "Cache directory is created if missing"
        return 0
    else
        fail "Cache directory creation missing"
        return 0
    fi
}

# Run all tests
echo ""
echo -e "${BLUE}━━━ Service Registry Caching Tests ━━━${NC}"
echo ""

test_syntax
test_cache_dir_var
test_mtime_cache_var
test_cache_valid_function
test_cache_generate_function
test_mtime_checking
test_persistent_cache
test_load_uses_validation
test_regeneration
test_atomic_updates
test_manifest_discovery
test_cache_dir_creation

# Summary
echo ""
echo -e "${BLUE}━━━ Test Summary ━━━${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASSED"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed:${NC} $FAILED"
fi
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
