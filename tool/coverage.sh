#!/usr/bin/env bash
# BrainFrame coverage pipeline — the single source of truth run identically by
# the pre-push hook (fast local feedback) and the GitHub Actions job (the
# authoritative gate). See docs/plans/engram-storage-impl.md, Step 0.
#
# Steps:
#   1. Regenerate the import-all helper so untested lib/ files count as 0%
#      instead of vanishing from the report (honest coverage).
#   2. Measure with `flutter test --coverage` -> coverage/lcov.info.
#   3. Filter the documented exclusions below into coverage/filtered.info.
#   4. Gate: fail if the filtered trace is under 90% (the --fail-under Dart
#      lacks). Skipped when COVERAGE_SKIP_GATE=1, so CI can post its coverage
#      comment from filtered.info before enforcing the floor.
#
# Coverage exclusions live in exactly one place — the array below. Keep it in
# sync with the mirrored comment in .github/workflows/coverage.yml.
#   main.dart            : untestable app bootstrap/entrypoint.
#   .g.dart              : generated code.
#   window_state_io.dart : desktop-only; drives a real OS window through the
#                          window_manager plugin, not exercisable in a headless
#                          `flutter test` run.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# `coverde transform` skip steps, one per excluded pattern. `-m w` overrides the
# output each run (its default appends, which would double-count on reruns).
EXCLUSIONS=(
  -t 'skip-by-regex=/main\.dart$'
  -t 'skip-by-regex=\.g\.dart$'
  -t 'skip-by-regex=/window_state_io\.dart$'
)
COVERAGE_MINIMUM=90

dart run tool/gen_coverage_helper.dart
flutter test --coverage
coverde transform \
  -i coverage/lcov.info \
  -o coverage/filtered.info \
  -m w \
  "${EXCLUSIONS[@]}"

if [[ "${COVERAGE_SKIP_GATE:-0}" == "1" ]]; then
  echo 'coverage: gate skipped (COVERAGE_SKIP_GATE=1)'
  exit 0
fi

coverde check -i coverage/filtered.info "$COVERAGE_MINIMUM"
