#!/usr/bin/env bash
# Tests for args.sh — named args + defaults + required-checks.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# shellcheck source=test/lib.sh
source "$HERE/lib.sh"

APP_NAME="test_args"
INSTANCE_ID="test_args_$$_$RANDOM"
# shellcheck source=core.sh
source "$REPO/core.sh"
require "args" "file://$REPO/args.sh"

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------
printf 'args.sh: idempotency\n'
assert_eq "ARGS_LOADED set after first source" "1" "$ARGS_LOADED"
source "$DEPS_DIR/args.sh"
assert_eq "ARGS_LOADED still 1 after re-source" "1" "$ARGS_LOADED"

# ---------------------------------------------------------------------------
# Helper functions that exercise args. Each returns a single line summary
# so we can assert_eq against the exact result.
# ---------------------------------------------------------------------------

greet() {
  eval "$(args name greeting=hello -- "$@")"
  echo "name=$name greeting=$greeting"
}

just_required() {
  eval "$(args name -- "$@")"
  echo "name=$name"
}

three_fields() {
  eval "$(args id name email= -- "$@")"
  echo "id=$id name=$name email=$email"
}

# ---------------------------------------------------------------------------
# Positional form
# ---------------------------------------------------------------------------
printf '\nargs.sh: positional form\n'

assert_eq "all-positional, all required filled" \
  "name=alice greeting=hello" "$(greet alice)"

assert_eq "positional fills both required and defaulted" \
  "name=alice greeting=hi" "$(greet alice hi)"

assert_eq "only required given, default kicks in" \
  "name=alice" "$(just_required alice)"

assert_eq "three fields, last has empty default" \
  "id=u1 name=Alice email=" "$(three_fields u1 Alice)"

assert_eq "three fields, all positional" \
  "id=u1 name=Alice email=a@x.com" "$(three_fields u1 Alice a@x.com)"

# ---------------------------------------------------------------------------
# Named form (--key value)
# ---------------------------------------------------------------------------
printf '\nargs.sh: named (--key value) form\n'

assert_eq "all-named, order swapped" \
  "name=alice greeting=hi" "$(greet --greeting hi --name alice)"

assert_eq "named with only the required" \
  "name=alice greeting=hello" "$(greet --name alice)"

assert_eq "--key=value form" \
  "name=alice greeting=hi" "$(greet --name=alice --greeting=hi)"

# ---------------------------------------------------------------------------
# Mixed: positional fills the next undeclared slot
# ---------------------------------------------------------------------------
printf '\nargs.sh: mixed positional + named\n'

assert_eq "named first, then positional fills next slot" \
  "name=alice greeting=hi" "$(greet --greeting hi alice)"

assert_eq "positional first, then named overrides defaulted" \
  "name=alice greeting=hi" "$(greet alice --greeting hi)"

# ---------------------------------------------------------------------------
# Values containing special characters (quoting via printf %q)
# ---------------------------------------------------------------------------
printf '\nargs.sh: special-character values are quoted safely\n'

assert_eq "value with space"      'name=hello world greeting=hi'   "$(greet 'hello world' hi)"
assert_eq "value with single quote" "name=O'Brien greeting=hello"  "$(greet "O'Brien")"
assert_eq "value with semicolon"  "name=a;b greeting=hello"        "$(greet 'a;b')"
assert_eq "value with dollar"     'name=$HOME greeting=hello'      "$(greet '$HOME')"
assert_eq "empty value via --key=" "name= greeting=hello"          "$(greet --name=)"

# ---------------------------------------------------------------------------
# Required-checks
# ---------------------------------------------------------------------------
printf '\nargs.sh: required-checks\n'

assert_false "missing required arg fails" greet
err=$(greet 2>&1 1>/dev/null || true)
assert_contains "missing-required error mentions the name" "$err" "name"

# ---------------------------------------------------------------------------
# Unknown / malformed input
# ---------------------------------------------------------------------------
printf '\nargs.sh: unknown / malformed input\n'

assert_false "--unknown flag rejected"      greet --unknown x alice
err=$(greet --unknown x alice 2>&1 1>/dev/null || true)
assert_contains "unknown-flag error mentions the flag" "$err" "unknown"

assert_false "--flag without value rejected" greet --name
err=$(greet --name 2>&1 1>/dev/null || true)
assert_contains "missing-value error mentions the flag" "$err" "name"

assert_false "too many positionals rejected" just_required alice extra
err=$(just_required alice extra 2>&1 1>/dev/null || true)
assert_contains "too-many error mentions counts" "$err" "too many"

# ---------------------------------------------------------------------------
# args called without `--` separator — emits a clear error
# ---------------------------------------------------------------------------
printf '\nargs.sh: missing -- separator\n'

bad() {
  # deliberately omit `--`
  eval "$(args name)"
  echo "should-not-reach"
}
assert_false "missing -- separator triggers error" bad
err=$(bad 2>&1 1>/dev/null || true)
assert_contains "missing-separator error message" "$err" "separator"

# ---------------------------------------------------------------------------
# locals stay local — no leak into caller scope
# ---------------------------------------------------------------------------
printf '\nargs.sh: locals do not leak\n'

leak_check() {
  unset name greeting
  greet alice >/dev/null
  # If `local` worked correctly inside greet, name/greeting should be unset here.
  if [[ -n "${name:-}${greeting:-}" ]]; then
    echo "leaked: name='${name:-}' greeting='${greeting:-}'"
  else
    echo "no-leak"
  fi
}
assert_eq "locals do not escape into the caller" "no-leak" "$(leak_check)"

summary
