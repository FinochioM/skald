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

if ls source/player/*.odin >/dev/null 2>&1; then
  echo "== smoke source/player (nil backend)"
  ext=""; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ext=".exe";; esac
  mkdir -p build/test
  bash scripts/build_game.sh boxes test
  odin build source/player -out:"build/test/skald_player_nil$ext" -debug -vet \
      -collection:skald=source -define:SKALD_BACKEND=nil -define:SKALD_GAME=build/test/games/boxes
  "./build/test/skald_player_nil$ext"
  echo "player ran headless ok"
fi
