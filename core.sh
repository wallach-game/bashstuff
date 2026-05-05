#!/usr/bin/env bash
# Bash Runtime Extension — core
#
# Provides:
#   * isolated per-run runtime directory under /dev/shm
#   * require()      — fetch + source a module by URL
#   * _resolve_deps  — pull in `# @dep <name> <url>` declarations

: "${APP_NAME:=bashrt}"
: "${INSTANCE_ID:=${APP_NAME}_$(date +%s)_$$}"
: "${RUNTIME_DIR:=/dev/shm/$INSTANCE_ID}"

DEPS_DIR="$RUNTIME_DIR/deps"
OBJ_DIR="$RUNTIME_DIR/objects"
LOCK_DIR="$RUNTIME_DIR/locks"
TMP_DIR="$RUNTIME_DIR/tmp"

mkdir -p "$DEPS_DIR" "$OBJ_DIR" "$LOCK_DIR" "$TMP_DIR"

if [[ -z "${DEBUG:-}" ]]; then
  trap 'rm -rf "$RUNTIME_DIR"' EXIT
fi

require() {
  local name="$1"
  local url="$2"
  local file="$DEPS_DIR/$name.sh"

  mkdir -p "$DEPS_DIR"

  if [[ ! -f "$file" ]]; then
    curl -fsSL "$url" -o "$file"
  fi

  _resolve_deps "$file"
  # shellcheck disable=SC1090
  source "$file"
}

_resolve_deps() {
  local file="$1"
  local _kw1 _kw2 dep_name dep_url

  while read -r _kw1 _kw2 dep_name dep_url; do
    [[ -n "$dep_name" && -n "$dep_url" ]] || continue
    require "$dep_name" "$dep_url"
  done < <(grep '^# @dep' "$file")
}
