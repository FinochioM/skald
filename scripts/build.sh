#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
target="${1:-all}"
mode="${2:-debug}"
out="build/$mode"
mkdir -p "$out"
ext=""; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ext=".exe";; esac
if [ "$mode" = release ]; then flags="-o:speed -vet -strict-style"
else flags="-debug -vet"; fi
coll="-collection:skald=source"

build_one() {
  local name="$1"
  if ! ls "source/$name"/*.odin >/dev/null 2>&1; then echo "skip $name (no code yet)"; return; fi
  odin build "source/$name" -out:"$out/skald_$name$ext" $flags $coll
  echo "built $out/skald_$name$ext"
}

case "$target" in
  all) for t in editor player assetc; do build_one "$t"; done ;;
  editor|player|assetc) build_one "$target" ;;
  *) echo "unknown target: $target"; exit 1 ;;
esac
