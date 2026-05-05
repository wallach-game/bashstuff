#!/usr/bin/env bash
# Example: load object.sh via require() and exercise the API.
#
# require() uses curl, which understands file:// URLs — so we can demo the
# loader against a local file without any external hosting.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="example"
# shellcheck source=core.sh
source "$HERE/core.sh"

require "object" "file://$HERE/object.sh"

obj_put user 123 '{"name":"alice","email":"alice@example.com"}'
obj_put user 456 '{"name":"bob","email":"bob@example.com"}'

echo "user 123 exists? $(obj_exists user 123 && echo yes || echo no)"
echo "user 999 exists? $(obj_exists user 999 && echo yes || echo no)"

echo "user 123 -> $(obj_get user 123)"
echo "user 456 -> $(obj_get user 456)"

obj_lock user 123 sh -c 'echo "[locked write] mutating user 123"'

obj_del user 456
echo "after delete, user 456 exists? $(obj_exists user 456 && echo yes || echo no)"

echo "runtime dir: $RUNTIME_DIR"
ls -R "$OBJ_DIR"
