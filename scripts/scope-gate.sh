#!/usr/bin/env bash
# scope-gate.sh — Mechanical PR scope gate (Phase 1)
#
# Evaluates whether a PR is focused enough to review by checking:
#   1. Issue reference (required)
#   2. Size thresholds (lines changed)
#   3. Workstream cohesion (distinct areas of concern)
#
# Inputs (env vars):
#   PR_BODY       — full PR description text
#   ADDITIONS     — number of added lines
#   DELETIONS     — number of deleted lines
#   CHANGED_FILES — newline-separated list of changed file paths
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
*🔬 Scope Gate v1 · Phase 1: Mechanical checks · No LLM*"
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
*🔬 Scope Gate v1 · Phase 1: Mechanical checks · No LLM*"
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
