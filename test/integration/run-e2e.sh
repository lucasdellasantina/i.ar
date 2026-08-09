#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# run-e2e.sh -- End-to-end test runner using test agents
#
# Runs two test agents:
#   1. "test" personality (one-shot) -- exercises all tools and containers
#   2. "test-continuous" personality (autonomous, 1 cycle) -- exercises
#      memory/state features
#
# Usage:
#   ./test/integration/run-e2e.sh --personalization PATH [OPTIONS]
#
# Options:
#   --model NAME        Ollama model (default: same as iar.sh default)
#   --ctx N             Context window size
#   --no-containers     Skip container tests (disable sidecar containers)
#   --skip-continuous   Only run the one-shot test agent
#   --timeout SECONDS   Per-agent timeout (default: 600)
#   --help, -h          Show this help
#
# Exit codes:
#   0 -- all tests passed
#   1 -- one or more tests failed
#   2 -- infrastructure error (agent couldn't start)
# =============================================================================

REPO_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")"
IAR_SH="${REPO_DIR}/utils/iar.sh"

# --- Defaults ---
PERSONALIZATION=""
MODEL=""
CTX=""
NO_CONTAINERS=""
SKIP_CONTINUOUS=0
TIMEOUT=600
EXTRA_ARGS=()

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --personalization) PERSONALIZATION="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --ctx) CTX="$2"; shift 2 ;;
        --no-containers) NO_CONTAINERS="--no-containers"; shift ;;
        --skip-continuous) SKIP_CONTINUOUS=1; shift ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 --personalization PATH [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --model NAME        Ollama model name"
            echo "  --ctx N             Context window size"
            echo "  --no-containers     Disable sidecar containers"
            echo "  --skip-continuous   Only run one-shot test agent"
            echo "  --timeout SECONDS   Per-agent timeout (default: 600)"
            exit 0
            ;;
        *) EXTRA_ARGS+=("$1"); shift ;;
    esac
done

if [[ -z "${PERSONALIZATION}" ]]; then
    echo "Error: --personalization is required"
    echo "Usage: $0 --personalization PATH [OPTIONS]"
    exit 2
fi

# --- Build common args ---
COMMON_ARGS=(
    --personalization "${PERSONALIZATION}"
    --project test
    --timeout "${TIMEOUT}"
)

if [[ -n "${MODEL}" ]]; then
    COMMON_ARGS+=(--model "${MODEL}")
fi

if [[ -n "${CTX}" ]]; then
    COMMON_ARGS+=(--ctx "${CTX}")
fi

if [[ -n "${NO_CONTAINERS}" ]]; then
    COMMON_ARGS+=(--no-containers)
fi

# --- Results tracking ---
ONESHOT_RESULT="UNKNOWN"
CONTINUOUS_RESULT="UNKNOWN"
ONESHOT_OUTPUT=""
CONTINUOUS_EXIT=0

# --- Run one-shot test agent ---
echo "============================================"
echo "  Running one-shot test agent (features)"
echo "============================================"
echo ""

ONESHOT_OUTPUT=$("${IAR_SH}" --one-shot \
    "${COMMON_ARGS[@]}" \
    --agent test \
    --prompt "Execute the full test plan from docs/test/plan.md. Run every test in order. Report PASS, FAIL, or SKIP for each test. Produce your final report between the one-shot delimiters." \
    2>&1) || true

echo "${ONESHOT_OUTPUT}"
echo ""

# Check for pass/fail indicators in the output
if echo "${ONESHOT_OUTPUT}" | grep -q "=== BEGIN FINAL RESPONSE ==="; then
    # Extract the final response
    RESPONSE=$(echo "${ONESHOT_OUTPUT}" | sed -n '/=== BEGIN FINAL RESPONSE ===/,/=== END FINAL RESPONSE ===/p' | sed '1d;$d')
    
    if echo "${RESPONSE}" | grep -qi "0 failed\|0 fail\b"; then
        ONESHOT_RESULT="PASS"
    elif echo "${RESPONSE}" | grep -qiE "[1-9]+ failed|[1-9]+ fail\b"; then
        ONESHOT_RESULT="FAIL"
    else
        # Can't determine -- treat as fail
        ONESHOT_RESULT="UNKNOWN"
    fi
else
    ONESHOT_RESULT="NO_RESPONSE"
fi

echo "One-shot test agent result: ${ONESHOT_RESULT}"
echo ""

# --- Run continuous test agent ---
if [[ ${SKIP_CONTINUOUS} -eq 0 ]]; then
    echo "============================================"
    echo "  Running continuous test agent (memory)"
    echo "============================================"
    echo ""

    "${IAR_SH}" --loop \
        "${COMMON_ARGS[@]}" \
        --agent test-continuous \
        --max-cycles 1 \
        2>&1 || CONTINUOUS_EXIT=$?

    echo ""
    echo "Continuous test agent exit code: ${CONTINUOUS_EXIT}"

    # Exit code 0 = LOOP_COMPLETE (success)
    # Exit code 2 = LOOP_COMPLETE (success, per iar-agent-cycle.el convention)
    if [[ ${CONTINUOUS_EXIT} -eq 0 ]] || [[ ${CONTINUOUS_EXIT} -eq 2 ]]; then
        CONTINUOUS_RESULT="PASS"
    else
        CONTINUOUS_RESULT="FAIL"
    fi

    echo "Continuous test agent result: ${CONTINUOUS_RESULT}"
    echo ""
fi

# --- Summary ---
echo "============================================"
echo "  E2E TEST SUMMARY"
echo "============================================"
echo "  One-shot (features):    ${ONESHOT_RESULT}"
if [[ ${SKIP_CONTINUOUS} -eq 0 ]]; then
    echo "  Continuous (memory):    ${CONTINUOUS_RESULT}"
fi
echo "============================================"

# --- Exit code ---
FAILURES=0
if [[ "${ONESHOT_RESULT}" != "PASS" ]]; then
    FAILURES=$((FAILURES + 1))
fi
if [[ ${SKIP_CONTINUOUS} -eq 0 ]] && [[ "${CONTINUOUS_RESULT}" != "PASS" ]]; then
    FAILURES=$((FAILURES + 1))
fi

if [[ ${FAILURES} -gt 0 ]]; then
    echo ""
    echo "To debug interactively:"
    echo "  ${IAR_SH} ${COMMON_ARGS[*]} --agent test"
    echo "  (then C-c a test, watch it fail, C-c p mirror to debug)"
    exit 1
fi

echo ""
echo "All E2E tests passed."
exit 0