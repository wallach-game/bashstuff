#!/usr/bin/env bash
# Tests for core.sh — runtime dir, require(), and dependency resolver.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

# shellcheck source=test/lib.sh
source "$HERE/lib.sh"

# ---------------------------------------------------------------------------
# Bootstrap a fresh runtime in this shell.
# Each `bash -c ...` child below also gets its own isolated runtime, but we
# need one in-process to inspect post-source state.
# ---------------------------------------------------------------------------
APP_NAME="test_core"
INSTANCE_ID="test_core_$$_$RANDOM"
# shellcheck source=core.sh
source "$REPO/core.sh"

printf 'core.sh: runtime dir is created on source\n'
assert_file_exists "RUNTIME_DIR exists"  "$RUNTIME_DIR"
assert_file_exists "DEPS_DIR exists"     "$DEPS_DIR"
assert_file_exists "OBJ_DIR exists"      "$OBJ_DIR"
assert_file_exists "LOCK_DIR exists"     "$LOCK_DIR"
assert_file_exists "TMP_DIR exists"      "$TMP_DIR"
assert_contains   "RUNTIME_DIR is under /dev/shm" "$RUNTIME_DIR" "/dev/shm/"

# ---------------------------------------------------------------------------
# require(): downloads (via file://) and sources a module
# ---------------------------------------------------------------------------
printf '\ncore.sh: require() loads a module from file://\n'

FIX_DIR="$(mktemp -d)"
cat > "$FIX_DIR/hello.sh" <<'EOF'
hello_say() { echo "hello-from-module"; }
EOF

require "hello" "file://$FIX_DIR/hello.sh"
assert_true "hello_say function defined after require" type -t hello_say
assert_eq   "hello_say returns expected output" "hello-from-module" "$(hello_say)"
assert_file_exists "module cached under DEPS_DIR" "$DEPS_DIR/hello.sh"

# Second require() must NOT re-download (mtime preserved).
mtime_before=$(stat -c %Y "$DEPS_DIR/hello.sh")
sleep 1
require "hello" "file://$FIX_DIR/hello.sh"
mtime_after=$(stat -c %Y "$DEPS_DIR/hello.sh")
assert_eq "second require() uses cache (mtime unchanged)" "$mtime_before" "$mtime_after"

# ---------------------------------------------------------------------------
# _resolve_deps: pulls in `# @dep <name> <url>` declarations transitively
# ---------------------------------------------------------------------------
printf '\ncore.sh: _resolve_deps follows @dep headers\n'

cat > "$FIX_DIR/leaf.sh" <<'EOF'
leaf_fn() { echo "leaf"; }
EOF

cat > "$FIX_DIR/branch.sh" <<EOF
# @dep leaf file://$FIX_DIR/leaf.sh
branch_fn() { echo "branch+\$(leaf_fn)"; }
EOF

require "branch" "file://$FIX_DIR/branch.sh"
assert_true "branch_fn defined" type -t branch_fn
assert_true "leaf_fn pulled in via @dep" type -t leaf_fn
assert_eq   "branch composes with leaf" "branch+leaf" "$(branch_fn)"

# ---------------------------------------------------------------------------
# Runtime directory cleanup on EXIT (default behavior)
# Verified in a child shell so the EXIT trap actually fires.
# ---------------------------------------------------------------------------
printf '\ncore.sh: EXIT trap removes RUNTIME_DIR (without DEBUG)\n'

child_runtime=$(bash -c '
  set -u
  APP_NAME=test_exit_trap
  INSTANCE_ID=test_exit_trap_$$_$RANDOM
  source "'"$REPO"'/core.sh"
  echo "$RUNTIME_DIR"
')
assert_file_missing "RUNTIME_DIR removed after child exits" "$child_runtime"

# DEBUG=1 disables the trap and the directory survives.
printf '\ncore.sh: DEBUG=1 keeps RUNTIME_DIR after exit\n'

child_runtime=$(DEBUG=1 bash -c '
  set -u
  APP_NAME=test_debug_keep
  INSTANCE_ID=test_debug_keep_$$_$RANDOM
  source "'"$REPO"'/core.sh"
  echo "$RUNTIME_DIR"
')
assert_file_exists "RUNTIME_DIR survives with DEBUG=1" "$child_runtime"
rm -rf "$child_runtime"

# Cleanup local fixtures (RUNTIME_DIR is removed by our own EXIT trap).
rm -rf "$FIX_DIR"

summary
