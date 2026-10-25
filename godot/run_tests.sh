#!/usr/bin/env bash
# Runs every headless test suite; exits non-zero if any fails.
cd "$(dirname "$0")"
failed=0
for suite in tests/test_*.gd; do
  if ! "${GODOT_BIN:-godot}" --headless --path . -s "$suite" >/dev/null 2>&1; then
    echo "FAIL: $suite"; failed=1
  else
    echo "ok:   $suite"
  fi
done
exit $failed
