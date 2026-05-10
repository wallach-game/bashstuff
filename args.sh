#!/usr/bin/env bash
# Bash Runtime Extension — args helper
#
# Named arguments + defaults + required-checks for plain Bash functions.
# Idea: a function declares its parameters once at the top, and gets local
# variables back, regardless of whether the caller passed positionals or
# `--key value` flags.
#
# Usage (eval pattern — Bash has no way for a function to inject locals into
# its caller, so the helper emits shell code that the caller eval's):
#
#   user_greet() {
#     eval "$(args id greeting=hello -- "$@")"
#     echo "$greeting from $id"
#   }
#
#   user_greet alice                    # id=alice  greeting=hello
#   user_greet alice hi                 # id=alice  greeting=hi
#   user_greet --id alice --greeting hi # same, named form
#   user_greet --greeting hi alice      # mixed (positional fills next slot)
#
# Spec syntax:
#   name           — required
#   name=default   — optional with default value
#
# On error (missing required, unknown --flag, --flag without value, too many
# positionals), the emitted shell prints to stderr and `return 2`s — the
# caller's function aborts cleanly.

[[ -n "${ARGS_LOADED:-}" ]] && return 0
ARGS_LOADED=1

args() {
  local -a names=()
  local -A is_required=()
  local -A defaults=()

  # ---- 1. parse spec list (everything before the literal `--`) ------------
  local saw_sep=0 spec key val
  while (( $# )); do
    spec=$1
    if [[ "$spec" == "--" ]]; then
      saw_sep=1
      shift
      break
    fi
    if [[ "$spec" == *=* ]]; then
      key=${spec%%=*}
      val=${spec#*=}
      names+=("$key")
      is_required[$key]=0
      defaults[$key]=$val
    else
      names+=("$spec")
      is_required[$spec]=1
    fi
    shift
  done

  if (( ! saw_sep )); then
    printf 'printf "args: missing -- separator before caller args\\n" >&2; return 2;\n'
    return
  fi

  # ---- 2. parse caller-supplied "$@" --------------------------------------
  local -A values=()
  local positional_idx=0 cur

  while (( $# )); do
    cur=$1
    if [[ "$cur" == --*=* ]]; then
      # --key=val form
      key=${cur#--}
      key=${key%%=*}
      val=${cur#*=}
      val=${val#*=}
    elif [[ "$cur" == --* ]]; then
      key=${cur#--}
      shift
      if (( ! $# )); then
        printf 'printf "args: --%s expects a value\\n" >&2; return 2;\n' "$key"
        return
      fi
      val=$1
    else
      # positional — fill the next undeclared slot
      if (( positional_idx >= ${#names[@]} )); then
        printf 'printf "args: too many positional arguments (got %s, expected at most %s)\\n" >&2; return 2;\n' \
          "$(( positional_idx + 1 ))" "${#names[@]}"
        return
      fi
      key=${names[$positional_idx]}
      val=$cur
      positional_idx=$(( positional_idx + 1 ))
    fi

    # Validate that --key is in the spec
    if [[ -z "${is_required[$key]+_}" ]]; then
      printf 'printf "args: unknown parameter %q\\n" >&2; return 2;\n' "$key"
      return
    fi
    values[$key]=$val
    shift
  done

  # ---- 3. emit `local <name>=<value>` lines -------------------------------
  for key in "${names[@]}"; do
    if [[ -n "${values[$key]+_}" ]]; then
      val=${values[$key]}
    elif (( is_required[$key] )); then
      printf 'printf "args: missing required parameter %q\\n" >&2; return 2;\n' "$key"
      return
    else
      val=${defaults[$key]}
    fi
    printf 'local %s=%q;\n' "$key" "$val"
  done
}
