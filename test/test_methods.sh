#!/usr/bin/env bash
# Tests for methods.sh — obj_call dispatcher and the sample user type.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# shellcheck source=test/lib.sh
source "$HERE/lib.sh"

APP_NAME="test_methods"
INSTANCE_ID="test_methods_$$_$RANDOM"
# shellcheck source=core.sh
source "$REPO/core.sh"
require "object"  "file://$REPO/object.sh"
require "methods" "file://$REPO/methods.sh"
# shellcheck source=examples/user.sh
source "$REPO/examples/user.sh"

# ---------------------------------------------------------------------------
# Idempotency: re-sourcing methods.sh is a no-op
# ---------------------------------------------------------------------------
printf 'methods.sh: idempotency\n'
assert_eq "METHODS_LOADED set after first source" "1" "$METHODS_LOADED"
# Re-source by hand. Using the cached file under DEPS_DIR is fine — same body.
source "$DEPS_DIR/methods.sh"
assert_eq "METHODS_LOADED still 1 after re-source" "1" "$METHODS_LOADED"

# ---------------------------------------------------------------------------
# Dispatch through obj_call
# ---------------------------------------------------------------------------
printf '\nmethods.sh: obj_call dispatch\n'

user_create alice "Alice" "alice@example.com"
assert_true "object created via constructor" obj_exists user alice

assert_eq "obj_call user/alice greet"  "Hello, Alice!"        "$(obj_call user alice greet)"
assert_eq "obj_call user/alice email"  "alice@example.com"    "$(obj_call user alice email)"
assert_eq "obj_call user/alice name"   "Alice"                "$(obj_call user alice name)"

# Method that mutates state
obj_call user alice set_email "alice@new.example.com"
assert_eq "set_email persisted via obj_call" \
  "alice@new.example.com" "$(obj_call user alice email)"

obj_call user alice rename "Alicia"
assert_eq "rename persisted via obj_call" "Hello, Alicia!" "$(obj_call user alice greet)"

# Multi-line method output
out=$(obj_call user alice describe)
assert_contains "describe shows id"    "$out" "user/alice"
assert_contains "describe shows name"  "$out" "Alicia"
assert_contains "describe shows email" "$out" "alice@new.example.com"

# Pass-through args: extra positionals reach the method
foo_echo() { echo "id=$1 a=$2 b=$3"; }
obj_put foo 1 ''
assert_eq "obj_call passes positional args through" \
  "id=1 a=hello b=world" "$(obj_call foo 1 echo hello world)"
obj_del foo 1
unset -f foo_echo

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------
printf '\nmethods.sh: error handling\n'

assert_false "obj_call: unknown method on known type" obj_call user alice nope
assert_false "obj_call: missing object"               obj_call user nobody greet
assert_false "obj_call: unknown type"                  obj_call ghost x greet
assert_false "obj_call: too few args"                  obj_call user

# stderr must mention what went wrong (a contract test, not just exit code)
err=$(obj_call user alice nope 2>&1 1>/dev/null || true)
assert_contains "unknown-method error mentions method name" "$err" "nope"
assert_contains "unknown-method error mentions function name" "$err" "user_nope"

err=$(obj_call user nobody greet 2>&1 1>/dev/null || true)
assert_contains "missing-object error mentions type/id" "$err" "user/nobody"

# ---------------------------------------------------------------------------
# obj_method_exists
# ---------------------------------------------------------------------------
printf '\nmethods.sh: obj_method_exists\n'

assert_true  "obj_method_exists user/greet"      obj_method_exists user greet
assert_true  "obj_method_exists user/set_email"  obj_method_exists user set_email
assert_false "obj_method_exists user/unknown"    obj_method_exists user unknown
assert_false "obj_method_exists ghost/greet"     obj_method_exists ghost greet

# ---------------------------------------------------------------------------
# obj_methods <type> introspection
# ---------------------------------------------------------------------------
printf '\nmethods.sh: obj_methods introspection\n'

methods=$(obj_methods user)
assert_contains "obj_methods includes greet"     "$methods" "greet"
assert_contains "obj_methods includes email"     "$methods" "email"
assert_contains "obj_methods includes set_email" "$methods" "set_email"
assert_contains "obj_methods includes describe"  "$methods" "describe"
assert_contains "obj_methods includes create"    "$methods" "create"

# unknown type produces no output, exits 0
ghost_methods=$(obj_methods ghost)
assert_eq "obj_methods on unknown type is empty" "" "$ghost_methods"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
# Note on locking: obj_lock execs its <command> via `flock`, so it can only run
# external programs, not bash functions like obj_call. To run a method under a
# lock, wrap it in a sub-bash: `obj_lock <t> <id> bash -c 'source ...; obj_call ...'`.
# That's an obj_lock contract issue, not something methods.sh owns, so it isn't
# tested here.

obj_del user alice

summary
