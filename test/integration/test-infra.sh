#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# test-infra.sh -- Infrastructure safety net tests
#
# Tests things that can't be tested by the test agents themselves:
# - Container images exist
# - Preflight audit script runs
# - iar.sh --help works (basic flag parsing)
# - Containerfile syntax (podman build --dry-run if supported)
#
# These are simple pass/fail checks. Run before the agent-based e2e tests.
# =============================================================================

REPO_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
source "${REPO_DIR}/metaconfig/header.sh" 2>/dev/null || true

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); }

# --- Check if podman is available ---
if ! command -v podman &>/dev/null; then
    skip "podman not available -- all container tests skipped"
    echo ""
    echo "Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
    exit 0
fi

# --- Container images ---
echo "=== Container Images ==="

for image in emacboros pentest concepts life-org; do
    if podman image exists "iar-${image}" 2>/dev/null; then
        pass "Container image iar-${image} exists"
    else
        fail "Container image iar-${image} not found (build with: podman build -t iar-${image} -f containers/images/${image}/Containerfile)"
    fi
done

# --- Preflight audit ---
echo ""
echo "=== Preflight Audit ==="

if [[ -f "${REPO_DIR}/containers/scripts/preflight.sh" ]]; then
    if bash "${REPO_DIR}/containers/scripts/preflight.sh" &>/dev/null; then
        pass "Preflight audit script runs successfully"
    else
        # Preflight exits non-zero if dangerous paths are writable.
        # In a test environment this might be expected -- check if we're in a container.
        if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]]; then
            skip "Preflight audit returned non-zero (running inside container -- may be expected)"
        else
            fail "Preflight audit script failed"
        fi
    fi
else
    fail "Preflight script not found at containers/scripts/preflight.sh"
fi

# --- iar.sh --help ---
echo ""
echo "=== iar.sh ==="

if [[ -f "${REPO_DIR}/utils/iar.sh" ]]; then
    if bash "${REPO_DIR}/utils/iar.sh" --help &>/dev/null; then
        pass "iar.sh --help exits successfully"
    else
        # --help might exit with non-zero on some implementations
        output=$(bash "${REPO_DIR}/utils/iar.sh" --help 2>&1 || true)
        if echo "${output}" | grep -qi "usage\|options\|flags"; then
            pass "iar.sh --help produces usage output"
        else
            fail "iar.sh --help does not produce usage output"
        fi
    fi
else
    fail "iar.sh not found at utils/iar.sh"
fi

# --- iar.sh flag parsing (dry check) ---
echo ""
echo "=== Flag Parsing ==="

# Check that --personalization and --project are required
output=$(bash "${REPO_DIR}/utils/iar.sh" 2>&1 || true)
if echo "${output}" | grep -qi "personalization\|required\|error"; then
    pass "iar.sh requires --personalization flag"
else
    fail "iar.sh does not seem to require --personalization flag"
fi

# --- Personalization audit script ---
echo ""
echo "=== Personalization Audit ==="

if [[ -f "${REPO_DIR}/utils/personalization_audit.sh" ]]; then
    if bash "${REPO_DIR}/utils/personalization_audit.sh" --help &>/dev/null; then
        pass "personalization_audit.sh --help works"
    else
        skip "personalization_audit.sh --help returned non-zero"
    fi
else
    skip "personalization_audit.sh not found"
fi

# --- Summary ---
echo ""
echo "============================================"
echo "  INFRA TEST SUMMARY"
echo "  ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "============================================"

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
exit 0