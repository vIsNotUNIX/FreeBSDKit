#!/bin/sh
#
# BPC Integration Test Runner
#
# Copyright (c) 2026 Kory Heard
# SPDX-License-Identifier: BSD-2-Clause
#

set -e

# Configuration
HARNESS="${HARNESS:-.build/debug/bpc-test-harness}"
SOCKET_DIR="${SOCKET_DIR:-/tmp}"
TIMEOUT="${TIMEOUT:-30}"

# Colors (if terminal supports them)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Test counters
PASSED=0
FAILED=0
TOTAL=0

# Clean up function
cleanup() {
    # Kill any background processes
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    # Remove socket files
    rm -f "${SOCKET_PATH}" "${SOCKET_PATH}.ready" 2>/dev/null || true
}

trap cleanup EXIT

# Run a single test
run_test() {
    TEST_NAME="$1"
    TOTAL=$((TOTAL + 1))

    echo ""
    echo "=========================================="
    echo "Test: ${TEST_NAME}"
    echo "=========================================="

    # Create unique socket path for this test
    SOCKET_PATH="${SOCKET_DIR}/bpc-test-$$.sock"
    rm -f "${SOCKET_PATH}" "${SOCKET_PATH}.ready" 2>/dev/null || true

    # Start server in background
    echo "[runner] Starting server..."
    "${HARNESS}" server "${SOCKET_PATH}" "${TEST_NAME}" &
    SERVER_PID=$!

    # Wait for server to be ready (ready file or timeout)
    WAIT_COUNT=0
    while [ ! -f "${SOCKET_PATH}.ready" ]; do
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt 50 ]; then
            echo "${RED}[runner] Timeout waiting for server to start${NC}"
            kill "$SERVER_PID" 2>/dev/null || true
            wait "$SERVER_PID" 2>/dev/null || true
            FAILED=$((FAILED + 1))
            return 1
        fi
        sleep 0.1
    done

    # Run client
    echo "[runner] Starting client..."
    CLIENT_EXIT=0
    timeout "$TIMEOUT" "${HARNESS}" client "${SOCKET_PATH}" "${TEST_NAME}" || CLIENT_EXIT=$?

    # Wait for server to finish
    SERVER_EXIT=0
    wait "$SERVER_PID" || SERVER_EXIT=$?
    SERVER_PID=""

    # Check results
    if [ $CLIENT_EXIT -eq 0 ] && [ $SERVER_EXIT -eq 0 ]; then
        echo "${GREEN}[runner] Test ${TEST_NAME}: PASSED${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "${RED}[runner] Test ${TEST_NAME}: FAILED${NC}"
        echo "[runner] Client exit: ${CLIENT_EXIT}, Server exit: ${SERVER_EXIT}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Run pair test (single process)
run_pair_test() {
    TOTAL=$((TOTAL + 1))

    echo ""
    echo "=========================================="
    echo "Test: pair"
    echo "=========================================="

    PAIR_EXIT=0
    timeout "$TIMEOUT" "${HARNESS}" pair || PAIR_EXIT=$?

    if [ $PAIR_EXIT -eq 0 ]; then
        echo "${GREEN}[runner] Test pair: PASSED${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "${RED}[runner] Test pair: FAILED (exit: ${PAIR_EXIT})${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "Summary"
    echo "=========================================="
    echo "Total:  ${TOTAL}"
    echo "${GREEN}Passed: ${PASSED}${NC}"
    if [ $FAILED -gt 0 ]; then
        echo "${RED}Failed: ${FAILED}${NC}"
    else
        echo "Failed: 0"
    fi
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main
main() {
    echo "BPC Integration Test Runner"
    echo "Harness: ${HARNESS}"
    echo ""

    # Check that harness exists
    if [ ! -x "${HARNESS}" ]; then
        echo "${RED}Error: Test harness not found or not executable: ${HARNESS}${NC}"
        echo "Run 'swift build' first."
        exit 1
    fi

    # Run all tests
    run_pair_test || true
    run_test "simple-message" || true
    run_test "large-message" || true
    run_test "descriptors" || true
    run_test "request-reply" || true
    run_test "messages-stream" || true

    # Print summary
    print_summary
}

# Allow running specific tests
if [ $# -gt 0 ]; then
    case "$1" in
        pair)
            run_pair_test
            ;;
        *)
            run_test "$1"
            ;;
    esac
    print_summary
else
    main
fi
