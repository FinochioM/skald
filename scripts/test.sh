#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ran=0
for p in skald scene reload platform; do
  if ls "source/$p"/*.odin >/dev/null 2>&1; then
    echo "== test source/$p"
    odin test "source/$p" -vet -collection:skald=source
    ran=1
  fi
done
[ $ran -eq 1 ] || echo "no testable code yet, skipping"
