#!/usr/bin/env bash
# Bash Runtime Extension — object storage
#
# File-per-object storage rooted at $OBJ_DIR (set by core.sh).
# Layout: $OBJ_DIR/<type>/<id>/{data,meta}

obj_path() {
  echo "$OBJ_DIR/$1/$2"
}

obj_put() {
  local type="$1"
  local id="$2"
  local data="$3"

  local dir
  dir="$(obj_path "$type" "$id")"

  mkdir -p "$dir"

  printf "%s" "$data" > "$dir/data"
  {
    printf "created=%s\n" "$(date +%s)"
    printf "type=%s\n" "$type"
  } > "$dir/meta"
}

obj_get() {
  local file
  file="$(obj_path "$1" "$2")/data"

  [[ -f "$file" ]] && cat "$file"
}

obj_del() {
  rm -rf "$(obj_path "$1" "$2")"
}

obj_exists() {
  [[ -d "$(obj_path "$1" "$2")" ]]
}

obj_lock() {
  local type="$1"
  local id="$2"
  shift 2

  local lock="$LOCK_DIR/${type}_${id}.lock"

  mkdir -p "$LOCK_DIR"

  flock "$lock" "$@"
}
