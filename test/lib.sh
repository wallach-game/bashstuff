#!/usr/bin/env bash
# Minimal assertion helpers for the bashstuff test suite.
#
# Each test file sources this, calls assert_*/run_test, then `summary` at the
# end and exits with its return code. The top-level runner aggregates by
# checking each test file's exit status.

TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  ok   - %s\n' "$1"
}

_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_TESTS+=("$1")
  printf '  FAIL - %s\n' "$1"
}

# assert_eq <desc> <expected> <actual>
assert_eq() {
  local desc=$1 expected=$2 actual=$3
  if [[ "$expected" == "$actual" ]]; then
    _pass "$desc"
  else
    _fail "$desc (expected '$expected', got '$actual')"
  fi
}

# assert_true <desc> <cmd...>   -- passes if cmd exits 0
assert_true() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    _pass "$desc"
  else
    _fail "$desc (cmd '$*' exited $?)"
  fi
}

# assert_false <desc> <cmd...>  -- passes if cmd exits non-zero
assert_false() {
  local desc=$1
  shift
  if ! "$@" >/dev/null 2>&1; then
    _pass "$desc"
  else
    _fail "$desc (cmd '$*' unexpectedly exited 0)"
  fi
}

# assert_file_exists <desc> <path>
assert_file_exists() {
  local desc=$1 path=$2
  if [[ -e "$path" ]]; then
    _pass "$desc"
  else
    _fail "$desc (no such path: $path)"
  fi
}

# assert_file_missing <desc> <path>
assert_file_missing() {
  local desc=$1 path=$2
  if [[ ! -e "$path" ]]; then
    _pass "$desc"
  else
    _fail "$desc (path still exists: $path)"
  fi
}

# assert_contains <desc> <haystack> <needle>
assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ "$haystack" == *"$needle"* ]]; then
    _pass "$desc"
  else
    _fail "$desc (expected to contain '$needle', got '$haystack')"
  fi
}

summary() {
  local total=$((TESTS_PASSED + TESTS_FAILED))
  printf '\n--- %d/%d passed ---\n' "$TESTS_PASSED" "$total"
  if ((TESTS_FAILED > 0)); then
    printf 'FAILURES:\n'
    for f in "${FAILED_TESTS[@]}"; do
      printf '  - %s\n' "$f"
    done
    return 1
  fi
  return 0
}
