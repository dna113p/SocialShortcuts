#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
shortcut_lua=${SOCIAL_SHORTCUTS_LUA:-lua}

for source in Core/*.lua UI/*.lua; do
  "$shortcut_lua" -e "assert(loadfile('$source'))"
done

for test in Tests/*.lua; do
  "$shortcut_lua" "$test"
done
