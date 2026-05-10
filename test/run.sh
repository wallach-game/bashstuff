#!/usr/bin/env bash
# Top-level test runner. Executes every test_*.sh under test/ in its own
# subshell, prints per-file output, and exits non-zero if any file failed.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shopt -s nullglob
files=("$HERE"/test_*.sh)
shopt -u nullglob

if (( ${#files[@]} == 0 )); then
  echo "no tests found in $HERE" >&2
  exit 1
fi

failed_files=()
for f in "${files[@]}"; do
  echo "==> $(basename "$f")"
  if bash "$f"; then
    :
  else
    failed_files+=("$(basename "$f")")
  fi
  echo
done

if (( ${#failed_files[@]} > 0 )); then
  echo "FAILED FILES:"
  for f in "${failed_files[@]}"; do echo "  - $f"; done
  exit 1
fi

echo "all test files passed"
