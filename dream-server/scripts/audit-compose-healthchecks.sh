#!/usr/bin/env bash
# Audit Docker Compose files for missing healthcheck definitions
# Usage: scripts/audit-compose-healthchecks.sh [--strict]
#
# Returns:
#   0 - All compose files have healthchecks (or only warnings)
#   1 - Missing healthchecks found in production files (strict mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STRICT=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)
            STRICT=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if $QUIET; then
    RED="" YELLOW="" GREEN="" BLUE="" NC=""
fi

log() { $QUIET || echo -e "$1"; }

# Find all compose files
compose_files=()
while IFS= read -r -d '' file; do
    compose_files+=("$file")
done < <(find "$ROOT_DIR" -type f \( -name "compose.yaml" -o -name "compose.*.yaml" -o -name "docker-compose*.yml" \) -print0 2>/dev/null)

if [[ ${#compose_files[@]} -eq 0 ]]; then
    log "${YELLOW}No compose files found${NC}"
    exit 0
fi

log "${BLUE}Auditing ${#compose_files[@]} compose files for healthchecks...${NC}"
log ""

missing_production=()
missing_local=()
missing_stub=()
has_healthcheck=()

for file in "${compose_files[@]}"; do
    rel_path="${file#$ROOT_DIR/}"

    # Skip if file is a stub (services: {})
    if grep -q "^services:\s*{}\s*$" "$file" 2>/dev/null; then
        missing_stub+=("$rel_path")
        continue
    fi

    # Check if file has healthcheck definition
    if grep -q "healthcheck:" "$file" 2>/dev/null; then
        has_healthcheck+=("$rel_path")
    else
        # Categorize by file type
        if [[ "$rel_path" == *".local."* ]]; then
            missing_local+=("$rel_path")
        else
            missing_production+=("$rel_path")
        fi
    fi
done

# Report results
log "${GREEN}✓ Files with healthchecks: ${#has_healthcheck[@]}${NC}"

if [[ ${#missing_stub[@]} -gt 0 ]]; then
    log "${BLUE}ℹ Stub files (no services): ${#missing_stub[@]}${NC}"
fi

if [[ ${#missing_local[@]} -gt 0 ]]; then
    log "${YELLOW}⚠ Local dev files without healthchecks: ${#missing_local[@]}${NC}"
    if ! $QUIET; then
        for file in "${missing_local[@]}"; do
            echo "    - $file"
        done
    fi
fi

if [[ ${#missing_production[@]} -gt 0 ]]; then
    log "${RED}✗ Production files without healthchecks: ${#missing_production[@]}${NC}"
    if ! $QUIET; then
        for file in "${missing_production[@]}"; do
            echo "    - $file"
        done
    fi
    log ""
    log "${YELLOW}Recommendation: Add healthcheck definitions to production compose files${NC}"

    if $STRICT; then
        exit 1
    fi
fi

log ""
log "${GREEN}Audit complete${NC}"
exit 0
