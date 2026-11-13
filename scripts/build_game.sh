#!/usr/bin/env bash
# Builds a game as a hot-reload library for the player.
# Usage: bash scripts/build_game.sh <example name or path> [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
game="${1:?usage: build_game.sh <examples/name or path>}"
mode="${2:-debug}"
[ -d "$game" ] || game="examples/$game"
ls "$game"/*.odin >/dev/null 2>&1 || { echo "no .odin files in $game"; exit 1; }
name=$(basename "$game")
out="build/$mode/games"
mkdir -p "$out"
ext=".so"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ext=".dll";; Darwin) ext=".dylib";; esac
flags="-debug -vet"; [ "$mode" = release ] && flags="-o:speed -vet"
odin build "$game" -build-mode:dll -out:"$out/$name.tmp$ext" $flags -collection:skald=source
mv -f "$out/$name.tmp$ext" "$out/$name$ext"
echo "built $out/$name$ext"
