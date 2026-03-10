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

# ═══════════════════════════════════════════════════════════
# Phase 2 Tests: Issue Alignment Validation
# ═══════════════════════════════════════════════════════════

echo ""
echo "═══ Phase 2: Issue Alignment Validation ═══"

# ─── Test 25: Issue with 3+ pillars → block ──────────────
echo ""
echo "25. Issue with 3 pillars/phases blocks"
export PR_BODY="Closes #116"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Testing Suite Revamp"
export ISSUE_BODY_TEXT="## Overview
Revamp the testing suite.

### Pillar 1: Test Infrastructure
Rebuild test-utils.

### Pillar 2: LLM Prompt Engineering
Improve code review prompts.

### Pillar 3: Self-Updating PR Template
Auto-generate PR templates.

## Acceptance Criteria
- [ ] Tests pass"
run_test "3 pillars blocks" "block"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 26: Issue with 2 pillars → no block from pillars
echo ""
echo "26. Issue with 2 pillars does not block (on pillars alone)"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Memory API improvements"
export ISSUE_BODY_TEXT="## Overview
Improve memory API.

### Phase 1: Read path optimization
Speed up reads.

### Phase 2: Write path optimization
Speed up writes.

## Acceptance Criteria
- [ ] Reads are faster
- [ ] Writes are faster"
run_test "2 pillars passes" "pass"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 27: Issue with 15+ ACs across 5+ sections → warn
echo ""
echo "27. Issue with 16 acceptance criteria across 6 sections warns"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Big feature"
export ISSUE_BODY_TEXT="## Overview
Big change.

## Section A
Details.

## Section B
Details.

## Section C
Details.

## Section D
Details.

## Section E
Details.

## Section F
Details.

## Acceptance Criteria
- [ ] AC 1
- [ ] AC 2
- [ ] AC 3
- [ ] AC 4
- [ ] AC 5
- [ ] AC 6
- [ ] AC 7
- [ ] AC 8
- [ ] AC 9
- [ ] AC 10
- [ ] AC 11
- [ ] AC 12
- [ ] AC 13
- [ ] AC 14
- [ ] AC 15
- [ ] AC 16"
run_test "16 ACs 6 sections warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 28: 15 ACs but only 5 sections → no warn ──────
echo ""
echo "28. 15 ACs but only 5 sections does not warn"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Medium feature"
export ISSUE_BODY_TEXT="## Overview
A feature.

## Design
Details.

## Implementation
Details.

## Testing
Details.

## Rollout
Details.

## Acceptance Criteria
- [ ] AC 1
- [ ] AC 2
- [ ] AC 3
- [ ] AC 4
- [ ] AC 5
- [ ] AC 6
- [ ] AC 7
- [ ] AC 8
- [ ] AC 9
- [ ] AC 10
- [ ] AC 11
- [ ] AC 12
- [ ] AC 13
- [ ] AC 14
- [ ] AC 15"
run_test "15 ACs 5 sections passes" "pass"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 29: PR touches workflows, issue doesn't mention CI → warn
echo ""
echo "29. PR modifies workflows but issue doesn't mention CI"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml"
export ISSUE_TITLE="Improve API routes"
export ISSUE_BODY_TEXT="## Overview
Improve the REST API routes for better error handling.

## Acceptance Criteria
- [ ] Better error messages"
run_test "workflow mismatch warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 30: PR touches workflows, issue DOES mention CI → no alignment warn
echo ""
echo "30. PR modifies workflows and issue mentions CI (no alignment warn)"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml"
export ISSUE_TITLE="Improve CI pipeline and API routes"
export ISSUE_BODY_TEXT="## Overview
Update the CI workflow and API routes.

## Acceptance Criteria
- [ ] CI passes
- [ ] Routes improved"
run_test "workflow match passes" "pass"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 31: PR touches docs, issue doesn't mention docs → warn
echo ""
echo "31. PR modifies docs but issue doesn't mention documentation"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
docs/Architecture.md"
export ISSUE_TITLE="Implement memory API"
export ISSUE_BODY_TEXT="## Overview
Implement the memory substrate API.

## Acceptance Criteria
- [ ] API works"
run_test "docs mismatch warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 32: PR touches PR template, issue doesn't mention templates → warn
echo ""
echo "32. PR modifies PR template but issue doesn't mention templates"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/pull_request_template.md"
export ISSUE_TITLE="Improve API"
export ISSUE_BODY_TEXT="## Overview
Better API.

## Acceptance Criteria
- [ ] Done"
run_test "template mismatch warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 33: PR touches scripts, issue doesn't mention scripts → warn
echo ""
echo "33. PR modifies scripts but issue doesn't mention scripts"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
scripts/deploy.sh"
export ISSUE_TITLE="API improvements"
export ISSUE_BODY_TEXT="## Overview
API work.

## Acceptance Criteria
- [ ] Done"
run_test "scripts mismatch warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 34: PR touches test-infra, issue doesn't mention it → warn
echo ""
echo "34. PR modifies test-infra but issue doesn't mention test utils"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
crates/pi-daemon-test-utils/src/client.rs"
export ISSUE_TITLE="API improvements"
export ISSUE_BODY_TEXT="## Overview
Improve API routes.

## Acceptance Criteria
- [ ] Done"
run_test "test-infra mismatch warns" "warn"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 35: No issue body (Phase 2 checks skipped gracefully)
echo ""
echo "35. No issue body — Phase 2 checks skipped gracefully"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml"
unset ISSUE_TITLE 2>/dev/null || true
unset ISSUE_BODY_TEXT 2>/dev/null || true
export ISSUE_TITLE=""
export ISSUE_BODY_TEXT=""
run_test "no issue body skips phase 2" "pass"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 36: Pillar block + alignment warn combined ─────
echo ""
echo "36. Multi-concern issue with alignment mismatch"
export PR_BODY="Closes #116"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
.github/workflows/ci.yml"
export ISSUE_TITLE="Testing Suite Revamp"
export ISSUE_BODY_TEXT="## Overview
Three-part overhaul.

### Pillar 1: Tests
More tests.

### Pillar 2: LLM Prompts
Better prompts.

### Pillar 3: PR Template
New template.

## Acceptance Criteria
- [ ] Done"
run_test "pillar block + alignment warn = block" "block"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 37: Issue mentions docs, PR changes docs → no warn
echo ""
echo "37. Issue mentions documentation, PR changes docs (no alignment warn)"
export PR_BODY="Closes #50"
export ADDITIONS=200
export DELETIONS=50
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs
docs/API-Reference.md"
export ISSUE_TITLE="API routes with documentation updates"
export ISSUE_BODY_TEXT="## Overview
Update API routes and update the documentation.

## Acceptance Criteria
- [ ] Routes updated
- [ ] Docs updated"
run_test "docs mentioned in issue passes" "pass"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 38: 5 pillars in issue → block ─────────────────
echo ""
echo "38. Issue with 5 phases blocks (even with small PR)"
export PR_BODY="Closes #100"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Multi-phase project"
export ISSUE_BODY_TEXT="## Overview
Five phases.

### Phase 1: Foundation
Build it.

### Phase 2: API
Route it.

### Phase 3: Testing
Test it.

### Phase 4: Docs
Document it.

### Phase 5: Deploy
Ship it.

## Acceptance Criteria
- [ ] Done"
run_test "5 phases blocks" "block"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 39: Step numbering also detected ────────────────
echo ""
echo "39. 'Step N' headers also counted as pillars"
export PR_BODY="Closes #100"
export ADDITIONS=50
export DELETIONS=10
export CHANGED_FILES="crates/pi-daemon-api/src/routes.rs"
export ISSUE_TITLE="Setup guide"
export ISSUE_BODY_TEXT="## Overview
Multi-step setup.

### Step 1: Install
Install deps.

### Step 2: Configure
Configure things.

### Step 3: Deploy
Deploy it.

## Acceptance Criteria
- [ ] Done"
run_test "3 steps blocks" "block"
unset ISSUE_TITLE ISSUE_BODY_TEXT

# ─── Test 40: Phase 1 + Phase 2 combined (real world) ────
echo ""
echo "40. Real-world: PR #117 with issue body (pillar block + size block + workstreams)"
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
export ISSUE_TITLE="Testing Suite Revamp: Enhanced Tests, LLM Prompt Engineering, Self-Updating PR Template"
export ISSUE_BODY_TEXT="## Overview
Three-pillar overhaul of the testing and review system.

### Pillar 1: Test Infrastructure
Rebuild test-utils with FullTestServer, expand integration tests.

### Pillar 2: LLM Prompt Engineering
Inject project docs into LLM review prompts, add scoring rubric.

### Pillar 3: Self-Updating PR Template
Auto-generate PR template with per-crate checklists.

## Acceptance Criteria
- [ ] Tests pass
- [ ] LLM prompts improved
- [ ] Template auto-updates"
run_test "PR #117 with issue body: multi-block" "block"
unset ISSUE_TITLE ISSUE_BODY_TEXT

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
