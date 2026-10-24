#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
for suite in rules models world save app; do
  test_output="$(mktemp "${TMPDIR:-/tmp}/razes-${suite}.XXXXXX")"
  if ! "$project_dir/run.sh" --headless --log-file "$test_output.engine" --script "res://tests/test_${suite}.gd" >"$test_output" 2>&1; then
    cat "$test_output"
    exit 1
  fi
  cat "$test_output"
  if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$test_output"; then
    exit 1
  fi
done
