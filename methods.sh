#!/usr/bin/env bash
# Bash Runtime Extension — methods on objects
#
# Convention: a method named `m` on type `t` is just a Bash function `t_m`.
# Method functions always receive the object id as their first positional
# argument; any further arguments are passed through verbatim.
#
# obj_call dispatches to that function for an existing object:
#
#   obj_call <type> <id> <method> [args...]
#
# obj_call refuses to dispatch to:
#   * a missing object (use obj_exists / a constructor first)
#   * a method whose function has not been defined
#
# Constructors (`<type>_create`, …) are called directly — they create the
# object, so the existence check would block them.

# Idempotency guard, per the project rule.
[[ -n "${METHODS_LOADED:-}" ]] && return 0
METHODS_LOADED=1

# obj_call <type> <id> <method> [args...]
obj_call() {
  if (( $# < 3 )); then
    echo "obj_call: usage: obj_call <type> <id> <method> [args...]" >&2
    return 2
  fi

  local type=$1 id=$2 method=$3
  shift 3

  local fn="${type}_${method}"

  if ! declare -F "$fn" >/dev/null; then
    echo "obj_call: no method '$method' on type '$type' (looked up function '$fn')" >&2
    return 1
  fi

  if ! obj_exists "$type" "$id"; then
    echo "obj_call: object $type/$id does not exist" >&2
    return 1
  fi

  "$fn" "$id" "$@"
}

# obj_method_exists <type> <method>
# Returns 0 if the dispatcher would resolve <type>_<method>, else nonzero.
obj_method_exists() {
  local type=$1 method=$2
  declare -F "${type}_${method}" >/dev/null
}

# obj_methods <type>
# Print every defined method on <type>, one per line, sorted.
# Useful for introspection / `--help`-style output.
obj_methods() {
  local type=$1
  local prefix="${type}_"
  declare -F | awk -v p="$prefix" '
    $3 ~ "^"p {
      sub("^"p, "", $3)
      print $3
    }
  ' | sort
}
