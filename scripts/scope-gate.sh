#!/usr/bin/env bash
# scope-gate.sh — Mechanical PR scope gate (Phase 1 + Phase 2)
#
# Evaluates whether a PR is focused enough to review by checking:
#   Phase 1:
#     1. Issue reference (required)
#     2. Size thresholds (lines changed)
#     3. Workstream cohesion (distinct areas of concern)
#   Phase 2:
#     4. Issue scope detection (multi-concern issues)
#     5. Workstream vs issue alignment (PR changes match issue scope)
#
# Inputs (env vars):
#   PR_BODY       — full PR description text
#   ADDITIONS     — number of added lines
#   DELETIONS     — number of deleted lines
#   CHANGED_FILES — newline-separated list of changed file paths
#   ISSUE_TITLE   — title of the referenced issue (Phase 2, optional)
#   ISSUE_BODY_TEXT — body of the referenced issue (Phase 2, optional)
#
# Outputs (env vars, written to $GITHUB_OUTPUT if set):
#   VERDICT       — "pass" | "warn" | "block"
#   COMMENT_BODY  — markdown comment to post on the PR
#
# Exit codes:
#   0 — pass or warn
#   1 — block
#
set -euo pipefail

# ── Helpers ────────────────────────────────────────────────

VERDICT="pass"
FINDINGS=()
WARNINGS=()

block() { VERDICT="block"; FINDINGS+=("🚫 $1"); }
warn()  { if [ "$VERDICT" != "block" ]; then VERDICT="warn"; fi; WARNINGS+=("⚠️ $1"); }
info()  { FINDINGS+=("ℹ️ $1"); }

# ── Check 1: Issue Reference ──────────────────────────────

ISSUE_NUM=""
if [ -n "${PR_BODY:-}" ]; then
  # Match: Closes #N, Fixes #N, Refs #N, Implements #N (case-insensitive)
  ISSUE_NUM=$(echo "$PR_BODY" | grep -oiP '(?:closes?|fixes?|refs?|implements?)\s+#(\d+)' | grep -oP '\d+' | head -1 || true)
fi

if [ -z "$ISSUE_NUM" ]; then
  block "Every PR must reference an issue. Add \`Closes #N\` to the PR description."
fi

# ── Check 2: Size Thresholds ─────────────────────────────

ADDITIONS="${ADDITIONS:-0}"
DELETIONS="${DELETIONS:-0}"
TOTAL=$((ADDITIONS + DELETIONS))

if [ "$TOTAL" -gt 1500 ]; then
  block "PR is ${TOTAL} lines — too large for reliable review. Split into focused PRs under 800 lines."
elif [ "$TOTAL" -gt 800 ]; then
  warn "PR is ${TOTAL} lines — review quality drops above 800. Consider splitting."
fi

# ── Check 3: Workstream Cohesion ──────────────────────────

declare -A WORKSTREAMS
WORKSTREAM_FILES=""

categorize_file() {
  local file="$1"
  local cat=""
  case "$file" in
    crates/pi-daemon-test-utils/*)            cat="test-infra" ;;
    crates/*/tests/*.rs|crates/*/tests/*/*.rs) cat="test-code" ;;
    crates/*/src/*.rs|crates/*/src/*/*.rs)     cat="source" ;;
    .github/workflows/*.yml)                   cat="ci-workflows" ;;
    docs/*.md|docs/**/*.md)                    cat="docs" ;;
    .github/pull_request_template*)            cat="pr-template" ;;
    scripts/*)                                 cat="scripts" ;;
    Cargo.toml|Cargo.lock|*/Cargo.toml)        cat="deps" ;;
    CHANGELOG.md|CHANGELOG*)                   cat="changelog" ;;
    *)                                         cat="other" ;;
  esac
  echo "$cat"
}

# Count files per workstream
if [ -n "${CHANGED_FILES:-}" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    cat=$(categorize_file "$file")
    WORKSTREAMS[$cat]=$(( ${WORKSTREAMS[$cat]:-0} + 1 ))
    WORKSTREAM_FILES="${WORKSTREAM_FILES}${cat}|${file}\n"
  done <<< "$CHANGED_FILES"
fi

# source + test-code always count as one workstream per Google eng-practices
# (tests belong with their source code)
HAS_SOURCE=${WORKSTREAMS[source]:-0}
HAS_TEST_CODE=${WORKSTREAMS[test-code]:-0}
MERGED_SOURCE_TESTS=0
if [ "$HAS_SOURCE" -gt 0 ] && [ "$HAS_TEST_CODE" -gt 0 ]; then
  MERGED_SOURCE_TESTS=1
fi

# Count meaningful workstreams (exclude deps, changelog — always expected)
MEANINGFUL_COUNT=0
MEANINGFUL_NAMES=()
for ws in "${!WORKSTREAMS[@]}"; do
  case "$ws" in
    deps|changelog) continue ;;  # always expected, don't count
  esac
  # If we merged source+test-code, skip test-code as separate
  if [ "$MERGED_SOURCE_TESTS" -eq 1 ] && [ "$ws" = "test-code" ]; then
    continue
  fi
  if [ "$MERGED_SOURCE_TESTS" -eq 1 ] && [ "$ws" = "source" ]; then
    MEANINGFUL_NAMES+=("source+tests")
  else
    MEANINGFUL_NAMES+=("$ws")
  fi
  MEANINGFUL_COUNT=$((MEANINGFUL_COUNT + 1))
done

# Sort for stable output
IFS=$'\n' MEANINGFUL_NAMES=($(sort <<< "${MEANINGFUL_NAMES[*]}")); unset IFS

if [ "$MEANINGFUL_COUNT" -ge 4 ]; then
  block "PR contains ${MEANINGFUL_COUNT} distinct workstreams ($(IFS=', '; echo "${MEANINGFUL_NAMES[*]}")). Split each concern into its own PR."
elif [ "$MEANINGFUL_COUNT" -ge 3 ] && [ "$TOTAL" -gt 500 ]; then
  warn "PR spans ${MEANINGFUL_COUNT} workstreams at ${TOTAL} lines ($(IFS=', '; echo "${MEANINGFUL_NAMES[*]}")). Consider splitting."
fi

# ── Check 4: Issue Scope Detection (Phase 2) ─────────────
# Detect multi-concern issues by structural signals in the issue body.
# Only runs if we successfully extracted an issue number AND have issue text.

ISSUE_BODY_TEXT="${ISSUE_BODY_TEXT:-}"
ISSUE_TITLE="${ISSUE_TITLE:-}"
ISSUE_COMBINED="${ISSUE_TITLE} ${ISSUE_BODY_TEXT}"

if [ -n "$ISSUE_NUM" ] && [ -n "$ISSUE_BODY_TEXT" ]; then
  # Count distinct pillars/phases/sections (## headers with numbered parts)
  PILLARS=$(echo "$ISSUE_BODY_TEXT" | grep -ciE "^#{1,3} .*(pillar|phase|part|section|step) [0-9]" || echo 0)

  # Count acceptance criteria (unchecked checkboxes)
  AC_COUNT=$(echo "$ISSUE_BODY_TEXT" | grep -c "^- \[ \]" || echo 0)

  # Count distinct implementation sections (## headers)
  IMPL_SECTIONS=$(echo "$ISSUE_BODY_TEXT" | grep -cE "^## " || echo 0)

  if [ "$PILLARS" -ge 3 ]; then
    block "Issue #${ISSUE_NUM} describes ${PILLARS} pillars/phases — split into ${PILLARS} separate issues first, then create one PR per issue."
  fi

  if [ "$AC_COUNT" -gt 15 ] && [ "$IMPL_SECTIONS" -gt 5 ]; then
    warn "Issue #${ISSUE_NUM} has ${AC_COUNT} acceptance criteria across ${IMPL_SECTIONS} sections — likely too broad for one PR."
  fi
fi

# ── Check 5: Workstream vs Issue Alignment (Phase 2) ─────
# Compare the PR's workstream categories against what the issue describes.
# Only runs if we have issue text AND there are workstreams to check.

if [ -n "$ISSUE_NUM" ] && [ -n "$ISSUE_BODY_TEXT" ] && [ ${#WORKSTREAMS[@]} -gt 0 ]; then
  ALIGNMENT_WARNINGS=()

  # Helper: count matching lines in issue text. Uses a temp variable to avoid
  # multiline grep -c output (grep -c counts per-input-line when piped).
  issue_mentions() {
    local pattern="$1"
    local count
    count=$(printf '%s' "$ISSUE_COMBINED" | grep -ciE "$pattern" || true)
    # grep -c on multiline input may return multiple counts; sum them
    local total=0
    for n in $count; do
      total=$((total + n))
    done
    echo "$total"
  }

  # Check: PR modifies workflow files but issue doesn't mention CI/workflows
  MENTIONS_WORKFLOWS=$(issue_mentions "workflow|ci(/cd)?|github.actions|\.yml|continuous.integration|pipeline")
  TOUCHES_WORKFLOWS=${WORKSTREAMS[ci-workflows]:-0}
  if [ "$TOUCHES_WORKFLOWS" -gt 0 ] && [ "$MENTIONS_WORKFLOWS" -eq 0 ]; then
    ALIGNMENT_WARNINGS+=("PR modifies ${TOUCHES_WORKFLOWS} workflow file(s) but issue #${ISSUE_NUM} doesn't mention CI/workflows.")
  fi

  # Check: PR modifies docs but issue doesn't mention documentation
  MENTIONS_DOCS=$(issue_mentions "doc(s|umentation)?|readme|\.md|writing|guide")
  TOUCHES_DOCS=${WORKSTREAMS[docs]:-0}
  if [ "$TOUCHES_DOCS" -gt 0 ] && [ "$MENTIONS_DOCS" -eq 0 ]; then
    ALIGNMENT_WARNINGS+=("PR modifies ${TOUCHES_DOCS} doc file(s) but issue #${ISSUE_NUM} doesn't mention documentation.")
  fi

  # Check: PR modifies PR template but issue doesn't mention templates
  MENTIONS_TEMPLATE=$(issue_mentions "template|pr.template|pull.request.template")
  TOUCHES_TEMPLATE=${WORKSTREAMS[pr-template]:-0}
  if [ "$TOUCHES_TEMPLATE" -gt 0 ] && [ "$MENTIONS_TEMPLATE" -eq 0 ]; then
    ALIGNMENT_WARNINGS+=("PR modifies the PR template but issue #${ISSUE_NUM} doesn't mention templates.")
  fi

  # Check: PR modifies scripts but issue doesn't mention scripts/tooling
  MENTIONS_SCRIPTS=$(issue_mentions "script|tooling|bash|shell|\.sh")
  TOUCHES_SCRIPTS=${WORKSTREAMS[scripts]:-0}
  if [ "$TOUCHES_SCRIPTS" -gt 0 ] && [ "$MENTIONS_SCRIPTS" -eq 0 ]; then
    ALIGNMENT_WARNINGS+=("PR modifies ${TOUCHES_SCRIPTS} script file(s) but issue #${ISSUE_NUM} doesn't mention scripts/tooling.")
  fi

  # Check: PR modifies test infrastructure but issue doesn't mention test-utils/infra
  MENTIONS_TEST_INFRA=$(issue_mentions "test.utils|test.infra|test.infrastructure|test.helpers|FullTestServer|TestClient")
  TOUCHES_TEST_INFRA=${WORKSTREAMS[test-infra]:-0}
  if [ "$TOUCHES_TEST_INFRA" -gt 0 ] && [ "$MENTIONS_TEST_INFRA" -eq 0 ]; then
    ALIGNMENT_WARNINGS+=("PR modifies ${TOUCHES_TEST_INFRA} test-infrastructure file(s) but issue #${ISSUE_NUM} doesn't mention test utils/infrastructure.")
  fi

  # Emit alignment warnings
  for aw in "${ALIGNMENT_WARNINGS[@]}"; do
    warn "${aw} Is this in scope?"
  done
fi

# ── Build Comment ─────────────────────────────────────────

FILE_COUNT=0
if [ -n "${CHANGED_FILES:-}" ]; then
  FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c '.' || true)
fi

build_workstream_table() {
  local table="| Workstream | Files |\n|------------|-------|\n"
  # Sort keys for deterministic output
  local sorted_keys
  IFS=$'\n' sorted_keys=($(for k in "${!WORKSTREAMS[@]}"; do echo "$k"; done | sort)); unset IFS
  for ws in "${sorted_keys[@]}"; do
    local label="$ws"
    # Show merged label when source + test-code are combined
    if [ "$MERGED_SOURCE_TESTS" -eq 1 ]; then
      if [ "$ws" = "source" ] || [ "$ws" = "test-code" ]; then
        label="${ws} *(counted as source+tests)*"
      fi
    fi
    table+="| ${label} | ${WORKSTREAMS[$ws]} |\n"
  done
  echo -e "$table"
}

COMMENT_BODY=""

case "$VERDICT" in
  block)
    COMMENT_BODY="## 🚫 Scope Gate: BLOCKED

This PR is too broad to review reliably (**${TOTAL} lines**, **${FILE_COUNT} files**, **${MEANINGFUL_COUNT} workstreams**).

**Findings:**
$(printf '%s\n' "${FINDINGS[@]}")
$([ ${#WARNINGS[@]} -gt 0 ] && printf '%s\n' "${WARNINGS[@]}" || true)

**Workstream breakdown:**
$(build_workstream_table)

**How to fix:** Split this PR so each addresses a single concern. Keep source code and its tests together (one workstream), but separate CI changes, docs, and infrastructure into their own PRs.

---
*🔬 Scope Gate v2 · Phase 1+2: Mechanical checks + issue alignment · No LLM*"
    ;;
  warn)
    COMMENT_BODY="## ⚠️ Scope Gate: WARNING

This PR is getting broad (**${TOTAL} lines**, **${FILE_COUNT} files**, **${MEANINGFUL_COUNT} workstreams**).

**Warnings:**
$(printf '%s\n' "${WARNINGS[@]}")

**Workstream breakdown:**
$(build_workstream_table)

Review quality drops with larger PRs. Consider whether any changes could be a separate PR.

---
*🔬 Scope Gate v2 · Phase 1+2: Mechanical checks + issue alignment · No LLM*"
    ;;
  pass)
    # No comment on pass — no clutter
    COMMENT_BODY=""
    ;;
esac

# ── Output ────────────────────────────────────────────────

# Write verdict to GITHUB_OUTPUT for workflow steps
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "verdict=${VERDICT}" >> "$GITHUB_OUTPUT"
fi

# Write comment body to a well-known file for the workflow to pick up.
# This avoids passing markdown through GITHUB_OUTPUT multiline delimiters,
# which is fragile with special characters, pipes, and backticks.
COMMENT_FILE="${SCOPE_GATE_COMMENT_FILE:-/tmp/scope-gate-comment.md}"
if [ -n "$COMMENT_BODY" ]; then
  echo "$COMMENT_BODY" > "$COMMENT_FILE"
else
  # Ensure file exists but is empty (signals "pass, no comment")
  : > "$COMMENT_FILE"
fi

# Human-readable output for local testing
echo "━━━ Scope Gate Result ━━━"
echo "Verdict: ${VERDICT}"
echo "Lines: ${TOTAL} (+${ADDITIONS}/-${DELETIONS})"
echo "Files: ${FILE_COUNT}"
echo "Workstreams: ${MEANINGFUL_COUNT} ($(IFS=', '; echo "${MEANINGFUL_NAMES[*]}"))"
if [ ${#FINDINGS[@]} -gt 0 ]; then
  echo ""
  echo "Findings:"
  printf '  %s\n' "${FINDINGS[@]}"
fi
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo ""
  echo "Warnings:"
  printf '  %s\n' "${WARNINGS[@]}"
fi
if [ -n "$COMMENT_BODY" ]; then
  echo ""
  echo "━━━ Comment ━━━"
  echo "$COMMENT_BODY"
fi

# Exit code: 1 for block, 0 for pass/warn
if [ "$VERDICT" = "block" ]; then
  exit 1
fi
exit 0
