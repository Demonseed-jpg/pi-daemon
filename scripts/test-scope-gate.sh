#!/usr/bin/env bash
# test-scope-gate.sh — Exercise scope-gate.sh against real-world scenarios
#
# Runs the scope gate with simulated PR data and asserts the verdict.
# Uses the actual script — no mocking.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATE="${SCRIPT_DIR}/scope-gate.sh"
PASS=0
FAIL=0
TOTAL=0

run_test() {
  local name="$1"
  local expected_verdict="$2"
  # env vars PR_BODY, ADDITIONS, DELETIONS, CHANGED_FILES must be set by caller
  TOTAL=$((TOTAL + 1))

  local output verdict exit_code
  set +e
  output=$(bash "$GATE" 2>&1)
  exit_code=$?
  set -e

  # Extract verdict from output
  verdict=$(echo "$output" | grep '^Verdict:' | awk '{print $2}')

  if [ "$verdict" = "$expected_verdict" ]; then
    echo "  ✅ ${name} → ${verdict}"
    PASS=$((PASS + 1))
  else
    echo "  ❌ ${name} → expected '${expected_verdict}', got '${verdict}' (exit=${exit_code})"
    echo "     Output: $(echo "$output" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

echo "━━━ Scope Gate Tests ━━━"
echo ""

# ─── Test 1: Clean, focused PR ───────────────────────────
echo "1. Clean, focused PR (source + tests, small, has issue ref)"
export PR_BODY="Implements test improvements

Closes #42"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/src/server.rs
crates/pi-daemon-api/tests/api_integration.rs
Cargo.lock"
run_test "focused source+tests PR" "pass"

# ─── Test 2: No issue reference ──────────────────────────
echo ""
echo "2. Missing issue reference"
export PR_BODY="Some changes without an issue reference"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "no issue ref" "block"

# ─── Test 3: Too large (>1500 lines) ─────────────────────
echo ""
echo "3. Oversized PR (>1500 lines)"
export PR_BODY="Closes #99"
export ADDITIONS=1200
export DELETIONS=400
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/src/server.rs"
run_test "1600 lines blocks" "block"

# ─── Test 4: Warning zone (800-1500 lines) ───────────────
echo ""
echo "4. Warning zone (800-1500 lines)"
export PR_BODY="Closes #99"
export ADDITIONS=600
export DELETIONS=300
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/src/server.rs"
run_test "900 lines warns" "warn"

# ─── Test 5: 4+ workstreams → block ──────────────────────
echo ""
echo "5. Too many workstreams (4+)"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/tests/api_integration.rs
.github/workflows/ci.yml
docs/Architecture.md
.github/pull_request_template.md
scripts/test-local.sh"
run_test "4 workstreams blocks" "block"

# ─── Test 6: 3 workstreams at 500+ lines → warn ─────────
echo ""
echo "6. Three workstreams at 500+ lines"
export PR_BODY="Closes #50"
export ADDITIONS=400
export DELETIONS=200
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml
docs/Architecture.md
Cargo.toml"
run_test "3 workstreams 600 lines warns" "warn"

# ─── Test 7: 3 workstreams under 500 lines → pass ───────
echo ""
echo "7. Three workstreams but small (<500 lines)"
export PR_BODY="Closes #50"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml
docs/Architecture.md"
run_test "3 workstreams 150 lines passes" "pass"

# ─── Test 8: source + test-code merge as one ─────────────
echo ""
echo "8. Source + test-code count as one workstream"
export PR_BODY="Closes #50"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/src/server.rs
crates/pi-daemon-api/tests/api_integration.rs
crates/pi-daemon-kernel/tests/kernel_lifecycle.rs
crates/pi-daemon-kernel/src/kernel.rs"
run_test "source+tests = 1 workstream" "pass"

# ─── Test 9: test-infra alone ────────────────────────────
echo ""
echo "9. Test-utils crate is its own workstream (test-infra)"
export PR_BODY="Closes #50"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-test-utils/src/client.rs
crates/pi-daemon-test-utils/src/server.rs
crates/pi-daemon-api/tests/api_integration.rs
crates/pi-daemon-api/src/routes.rs"
run_test "test-infra + source+tests = 2 workstreams" "pass"

# ─── Test 10: deps + changelog never counted ─────────────
echo ""
echo "10. Deps and changelog don't count as workstreams"
export PR_BODY="Closes #50"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
Cargo.toml
Cargo.lock
CHANGELOG.md"
run_test "deps+changelog ignored" "pass"

# ─── Test 11: The PR #117 scenario ──────────────────────
echo ""
echo "11. Real-world: PR #117 scenario (22 files, 5 workstreams, 1877 lines)"
export PR_BODY="Closes #116"
export ADDITIONS=1877
export DELETIONS=662
export CHANGED_FILES="crates/pi-daemon-test-utils/src/server.rs
crates/pi-daemon-test-utils/src/client.rs
crates/pi-daemon-test-utils/src/macros.rs
crates/pi-daemon-test-utils/src/lib.rs
crates/pi-daemon-test-utils/tests/integration.rs
crates/pi-daemon-api/tests/api_integration.rs
crates/pi-daemon-api/tests/openai_integration.rs
crates/pi-daemon-api/tests/webchat_integration.rs
crates/pi-daemon-api/tests/websocket_integration.rs
crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-kernel/tests/kernel_lifecycle.rs
crates/pi-daemon-kernel/src/kernel.rs
.github/workflows/code-review.yml
.github/workflows/ci.yml
.github/workflows/sandbox-test.yml
docs/Testing.md
docs/PR-Reviews.md
docs/Contributing.md
.github/pull_request_template.md
scripts/test-local.sh
Cargo.toml
CHANGELOG.md"
run_test "PR #117 blocks (size + workstreams)" "block"

# ─── Test 12: Fixes/Refs variants ────────────────────────
echo ""
echo "12. Issue reference variants"

export PR_BODY="Fixes #10"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "Fixes #N accepted" "pass"

export PR_BODY="Refs #10"
run_test "Refs #N accepted" "pass"

export PR_BODY="closes #10"
run_test "lowercase closes accepted" "pass"

export PR_BODY="Implements #10"
run_test "Implements #N accepted" "pass"

# ─── Test 13: Empty PR ──────────────────────────────────
echo ""
echo "13. Edge case: empty/minimal PR"
export PR_BODY=""
export ADDITIONS=0
export DELETIONS=0
export CHANGED_FILES=""
run_test "empty PR blocks (no issue ref)" "block"

# ─── Test 14: Only deps changes ─────────────────────────
echo ""
echo "14. Only deps changes (Cargo.toml + Cargo.lock)"
export PR_BODY="Closes #77"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="Cargo.toml
Cargo.lock"
run_test "deps-only PR passes" "pass"

# ─── Test 15: Exactly at thresholds ──────────────────────
echo ""
echo "15. Boundary: exactly 800 lines (should pass, not warn)"
export PR_BODY="Closes #10"
export ADDITIONS=500
export DELETIONS=300
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "exactly 800 lines passes" "pass"

echo ""
echo "16. Boundary: exactly 801 lines (should warn)"
export PR_BODY="Closes #10"
export ADDITIONS=500
export DELETIONS=301
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "801 lines warns" "warn"

echo ""
echo "17. Boundary: exactly 1500 lines (should warn, not block)"
export PR_BODY="Closes #10"
export ADDITIONS=1000
export DELETIONS=500
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "exactly 1500 lines warns" "warn"

echo ""
echo "18. Boundary: exactly 1501 lines (should block)"
export PR_BODY="Closes #10"
export ADDITIONS=1000
export DELETIONS=501
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "1501 lines blocks" "block"

# ─── Test 19: Issue ref embedded in longer text ──────────
echo ""
echo "19. Issue ref buried in long PR body"
export PR_BODY="This is a long description.

## What changed
Lots of things.

## Why
Because reasons.

Closes #42

Some trailing text."
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "issue ref in long body" "pass"

# ─── Test 20: Multiple issue refs (takes first) ─────────
echo ""
echo "20. Multiple issue refs (takes first)"
export PR_BODY="Closes #42
Also refs #43"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "multiple refs takes first" "pass"

# ─── Test 21: Files in nested src dirs ───────────────────
echo ""
echo "21. Nested source directories"
export PR_BODY="Closes #10"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/handlers/auth.rs
crates/pi-daemon-api/src/middleware.rs"
run_test "nested src dirs categorized as source" "pass"

# ─── Test 22: Unknown file types fall to 'other' ────────
echo ""
echo "22. Unknown files categorized as 'other'"
export PR_BODY="Closes #10"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="README.md
.gitignore
deny.toml"
run_test "unknown files as other workstream" "pass"

# ─── Test 23: source + tests + test-infra = 2, not 3 ────
echo ""
echo "23. source + tests + test-infra = 2 workstreams (source+tests merged)"
export PR_BODY="Closes #10"
export ADDITIONS=100
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-api/tests/api_integration.rs
crates/pi-daemon-test-utils/src/client.rs"
run_test "source+tests+test-infra = 2 workstreams" "pass"

# ─── Test 24: Block wins over warn ───────────────────────
echo ""
echo "24. Block from issue ref + warn from size = block"
export PR_BODY="No issue ref here"
export ADDITIONS=600
export DELETIONS=300
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
run_test "block overrides warn" "block"

# ─── Summary ─────────────────────────────────────────────
echo ""
echo "━━━ Results ━━━"
echo "Passed: ${PASS}/${TOTAL}"
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: ${FAIL}/${TOTAL}"
  exit 1
else
  echo "All tests passed."
fi
