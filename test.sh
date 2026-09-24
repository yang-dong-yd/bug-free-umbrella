#!/usr/bin/env bash
# Real, minimal test gate for a repository that currently contains only
# standards and configuration files (no application code yet).
#
# It asserts this repository's own invariants, so it can genuinely fail:
#   1. the required standards files exist and are non-empty;
#   2. .releaserc.json is valid JSON and never commits to the default branch;
#   3. the release workflow calls the shared reusable workflow at an explicit ref;
#   4. the workflow YAML parses;
#   5. no fail-closed placeholder is left in the CI workflow.
#
# Replace this file with the project's own suite as soon as the first code lands.
set -euo pipefail

cd "$(dirname "$0")"

failed=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; failed=1; }

# 1. Required files exist and are non-empty.
for f in AGENTS.md .releaserc.json \
         .github/workflows/ci.yml .github/workflows/release.yml; do
  if [[ -s "$f" ]]; then
    pass "$f is present and non-empty"
  else
    fail "$f is missing or empty"
  fi
done

# 2. .releaserc.json is valid JSON.
if python3 -m json.tool .releaserc.json >/dev/null 2>&1; then
  pass ".releaserc.json is valid JSON"
else
  fail ".releaserc.json is not valid JSON"
fi

# 3. The release job must never commit to the default branch.
if grep -q '"@semantic-release/git"' .releaserc.json; then
  fail ".releaserc.json must not enable @semantic-release/git"
else
  pass ".releaserc.json does not enable @semantic-release/git"
fi

# 4. The release pipeline is called at an explicit ref.
if grep -qE 'uses:[[:space:]]+nexform-tech/repo-template/\.github/workflows/release\.yml@[^[:space:]]+' \
     .github/workflows/release.yml; then
  pass "release.yml calls the shared reusable workflow at an explicit ref"
else
  fail "release.yml does not call the shared reusable workflow at an explicit ref"
fi

# 5. The workflow YAML parses (skipped when no YAML parser is available).
if python3 -c 'import yaml' >/dev/null 2>&1; then
  if python3 -c '
import sys, yaml
for path in sys.argv[1:]:
    yaml.safe_load(open(path, encoding="utf-8"))
' .github/workflows/ci.yml .github/workflows/release.yml >/dev/null 2>&1; then
    pass "workflow YAML parses"
  else
    fail "workflow YAML does not parse"
  fi
else
  printf 'skip - PyYAML unavailable, YAML parse check skipped\n'
fi

# 6. The CI workflow must not fall back to the fail-closed placeholder.
if grep -q 'no test toolchain configured' .github/workflows/ci.yml; then
  fail "ci.yml still contains the fail-closed placeholder"
else
  pass "ci.yml contains no leftover placeholder"
fi

printf '\n'
if [[ "$failed" -ne 0 ]]; then
  printf 'test gate failed\n'
  exit 1
fi
printf 'test gate passed\n'
