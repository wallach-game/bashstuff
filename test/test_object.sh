#!/usr/bin/env bash
# Tests for object.sh — file-per-object CRUD + flock-based locking.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# shellcheck source=test/lib.sh
source "$HERE/lib.sh"

APP_NAME="test_object"
INSTANCE_ID="test_object_$$_$RANDOM"
# shellcheck source=core.sh
source "$REPO/core.sh"
require "object" "file://$REPO/object.sh"

# ---------------------------------------------------------------------------
# obj_put / obj_get / obj_exists / obj_del
# ---------------------------------------------------------------------------
printf 'object.sh: basic CRUD\n'

obj_put user 1 '{"name":"alice"}'

assert_file_exists "data file written"  "$OBJ_DIR/user/1/data"
assert_file_exists "meta file written"  "$OBJ_DIR/user/1/meta"
assert_eq          "obj_get returns stored payload" '{"name":"alice"}' "$(obj_get user 1)"
assert_true        "obj_exists returns 0 when present"     obj_exists user 1
assert_false       "obj_exists returns nonzero when missing" obj_exists user 999

# meta should record type=user
meta=$(cat "$OBJ_DIR/user/1/meta")
assert_contains "meta records type=user" "$meta" "type=user"
assert_contains "meta records created="  "$meta" "created="

# overwrite
obj_put user 1 '{"name":"alice2"}'
assert_eq "obj_put overwrites existing payload" '{"name":"alice2"}' "$(obj_get user 1)"

# delete
obj_del user 1
assert_false       "obj_exists returns nonzero after delete" obj_exists user 1
assert_file_missing "object dir removed" "$OBJ_DIR/user/1"

# ---------------------------------------------------------------------------
# obj_get on missing object: returns empty + non-fatal
# (current contract: prints nothing; exit status is best-effort.)
# ---------------------------------------------------------------------------
printf '\nobject.sh: obj_get on missing\n'

out=$(obj_get user 9999)
assert_eq "obj_get on missing prints empty" "" "$out"

# ---------------------------------------------------------------------------
# Multiple types isolated under their own subtree
# ---------------------------------------------------------------------------
printf '\nobject.sh: types are isolated\n'

obj_put user    42 'u-payload'
obj_put session 42 's-payload'

assert_eq "user/42 payload"    "u-payload" "$(obj_get user 42)"
assert_eq "session/42 payload" "s-payload" "$(obj_get session 42)"
obj_del user 42
assert_true  "session/42 still exists after deleting user/42" obj_exists session 42
assert_false "user/42 gone after delete"                       obj_exists user 42
obj_del session 42

# ---------------------------------------------------------------------------
# obj_lock: runs the command, returns its exit status, holds the lock
# ---------------------------------------------------------------------------
printf '\nobject.sh: obj_lock\n'

obj_put user 7 'init'
out=$(obj_lock user 7 sh -c 'echo locked-write')
assert_eq "obj_lock runs the command and captures stdout" "locked-write" "$out"

assert_true  "obj_lock returns 0 on success" obj_lock user 7 true
assert_false "obj_lock propagates failure"   obj_lock user 7 false

# Mutual exclusion: a second flock attempt with -n must fail while the first holds it.
held_log=$(mktemp)
obj_lock user 7 bash -c '
  # Inside the lock: try to grab it again non-blocking from a sibling shell.
  # Should fail because we already hold it.
  if flock -n "'"$LOCK_DIR"'/user_7.lock" -c "echo got-it"; then
    echo "FAIL: nested non-blocking flock unexpectedly succeeded"
  else
    echo OK
  fi
' > "$held_log" 2>&1
held_out=$(cat "$held_log")
rm -f "$held_log"
assert_eq "non-blocking flock contends correctly while obj_lock holds the file" "OK" "$held_out"

obj_del user 7

summary
