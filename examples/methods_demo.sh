#!/usr/bin/env bash
# End-to-end demo of methods.sh + the user sample type.
# Mirrors example.sh's shape but exercises obj_call dispatch.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

APP_NAME="methods_demo"
# shellcheck source=../core.sh
source "$REPO/core.sh"

require "object"  "file://$REPO/object.sh"
require "methods" "file://$REPO/methods.sh"
require "args"    "file://$REPO/args.sh"

# Load the sample type. (Types aren't required modules — they're just .sh
# files that happen to follow the <type>_<method> naming convention.)
# shellcheck source=user.sh
source "$HERE/user.sh"

# --- construct (positional and --flag forms both work, courtesy of args) ---
user_create alice "Alice"   "alice@example.com"
user_create --id bob --name "Bob" --email "bob@example.com"

# --- dispatch through obj_call --------------------------------------------
echo "obj_call user alice greet  -> $(obj_call user alice greet)"
echo "obj_call user bob   greet  -> $(obj_call user bob greet)"
echo "obj_call user alice email  -> $(obj_call user alice email)"

# --- mutate via methods ----------------------------------------------------
obj_call user alice set_email "alice@new.example.com"
obj_call user bob   rename    "Robert"

echo
echo "--- after mutations ---"
obj_call user alice describe
obj_call user bob   describe

# --- introspection ---------------------------------------------------------
echo
echo "methods on type 'user':"
obj_methods user | sed 's/^/  - /'

# --- error handling --------------------------------------------------------
echo
echo "--- error paths (expected to fail) ---"
obj_call user alice nope         2>&1 || true
obj_call user nobody greet       2>&1 || true
obj_call ghost x      greet      2>&1 || true
