#!/usr/bin/env bash
# Sample type — `user` — built on object.sh + methods.sh.
#
# Demonstrates the convention: every public function is named user_<method>.
# Each method takes the object id as $1 and may take more positional args.
# obj_call <type> <id> <method> [args] dispatches to user_<method> "$id" [args].
#
# Payload format is intentionally simple key=value lines (no jq / JSON), so
# this file is self-contained and works on any standard Linux box.

# Depends on object.sh (obj_put / obj_get) and optionally args.sh for named
# arguments. Bootstrap order is shown in methods_demo.sh.

[[ -n "${USER_TYPE_LOADED:-}" ]] && return 0
USER_TYPE_LOADED=1

# --- internal helpers -------------------------------------------------------

# _user_field <id> <key>  ->  value (or empty if missing)
_user_field() {
  local id=$1 key=$2
  obj_get user "$id" \
    | awk -F= -v k="$key" '$1==k { sub(/^[^=]*=/, ""); print; exit }'
}

# _user_write <id> <name> <email>
_user_write() {
  local id=$1 name=$2 email=$3
  obj_put user "$id" "name=$name
email=$email"
}

# --- public API -------------------------------------------------------------

# Constructor — call directly, NOT through obj_call (no object exists yet).
# Demonstrates the args helper: positional and --flag forms both work.
#
#   user_create alice "Alice" "alice@x.com"
#   user_create --id alice --name Alice --email alice@x.com
#   user_create alice --email alice@x.com --name Alice
user_create() {
  eval "$(args id name email= -- "$@")"
  _user_write "$id" "$name" "$email"
}

# user_greet <id>          ->  prints "Hello, <name>!"
user_greet() {
  local id=$1
  local name
  name=$(_user_field "$id" name)
  echo "Hello, $name!"
}

# user_name <id>           ->  prints stored name
user_name() {
  _user_field "$1" name
}

# user_email <id>          ->  prints stored email
user_email() {
  _user_field "$1" email
}

# user_set_email <id> <email>
user_set_email() {
  local id=$1 email=$2
  local name
  name=$(_user_field "$id" name)
  _user_write "$id" "$name" "$email"
}

# user_rename <id> <new_name>
user_rename() {
  local id=$1 name=$2
  local email
  email=$(_user_field "$id" email)
  _user_write "$id" "$name" "$email"
}

# user_describe <id>       ->  pretty multi-line summary
user_describe() {
  local id=$1
  printf 'user/%s\n  name:  %s\n  email: %s\n' \
    "$id" "$(_user_field "$id" name)" "$(_user_field "$id" email)"
}
