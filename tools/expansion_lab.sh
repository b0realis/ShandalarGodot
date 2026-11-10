#!/usr/bin/env bash
# Development scenarios and battle baselines; never the player's profile.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/banner.sh
. tools/runtime.sh
case "${1:-}" in
  -V|--version) shandalar_version_line expansion_lab.sh .; exit 0;;
  -h|--help) cat <<'HELP'
Expansion Lab — reusable adventure-region development checks
  ./tools/expansion_lab.sh --out NEW_DIRECTORY [--region refuge|beacon_test]
    [--plugin ZIP_OR_FOLDER] [--seeds 5,37,48271] [--trips 3] [--games 0]
    [--lives 10,20,30]

Each seed checks travel, terrain, objectives, saves, mana links and dormant
providers. A separate beacon region exercises another progression schema.
--plugin runs the checks on one adventure plugin, a .zip or a folder, read
from a copy beside the results (the only plugin the run sees; its own id is
the region): it must pass the game's plugin checks first, and its card packs
must be found. A plugin that needs no pack is taken away mid-trip instead of
its pack, as when a player removes it, and the hero must still sail home.
A plugin land (--plugin, or the Refuge) is also played to its end per seed
on the model's own results, no duel fought: every quest stage by stage,
its rewards claimed, the finale won, then saved and read back on the island
and at home; the land must be neither held nor damaged.
--games N adds N games per hero deck x life total x regional opponent,
using fair Wizard pilots and alternating first seats. N=0 skips duels.
Writes results.json, report.txt and engine.log. Never writes ratings.
Use SHANDALAR_PACK_2 for your local pack; EXPANSION_LAB_FIXTURES=1 selects
metadata-only test packs created by run_tests.sh. LAB_TIMEOUT defaults to 600s.
Exit: 0 passed, 1 failed (a plugin refused too), 2 invalid options,
3 missing runtime, 124 timeout.
HELP
  exit 0;;
esac
out=""
plugin=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [ "${args[i]}" = --out ] && ((i+1<${#args[@]})); then out="${args[i+1]}"; fi
  if [ "${args[i]}" = --plugin ] && ((i+1<${#args[@]})); then plugin="${args[i+1]}"; fi
done
if [ -z "$out" ] || [ -e "$out" ]; then echo 'Supply --out with a new directory.' >&2; exit 2; fi
plugin="${plugin%/}"
if [ -n "$plugin" ]; then
  case "$plugin" in
    *.zip | *.ZIP) [ -f "$plugin" ] || { echo "--plugin $plugin: no such zip." >&2; exit 2; } ;;
    *) [ -d "$plugin" ] || { echo "--plugin $plugin: neither a .zip nor a folder." >&2; exit 2; } ;;
  esac
fi
mkdir -p "$out"
out=$(cd "$out" && pwd)
for ((i=0; i<${#args[@]}; i++)); do
  if [ "${args[i]}" = --out ]; then args[i+1]="$out"; fi
done
# The plugin is read from a copy in a folder of its own: the run's only
# plugins folder (a symbolic link inside a folder is copied as a link, and
# refused as the game refuses it). The copy goes when the run ends.
if [ -n "$plugin" ]; then
  mkdir -p "$out/plugin"
  cp -R -P -- "$plugin" "$out/plugin/"
  for ((i=0; i<${#args[@]}; i++)); do
    if [ "${args[i]}" = --plugin ]; then args[i+1]="$out/plugin"; fi
  done
fi
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
if [ "${EXPANSION_LAB_FIXTURES:-0}" = 1 ]; then
  for pack_file in "$SHANDALAR_TEST_DATA_HOME"/Pack-*.zip; do
    [ -f "$pack_file" ] || { echo 'Run targeted tests first to prepare fixtures.' >&2; exit 2; }
    pack_name=${pack_file##*/}; pack_id=${pack_name#Pack-}; pack_id=${pack_id%%-*}
    export "SHANDALAR_PACK_${pack_id}=$pack_file"
  done
fi
shandalar_banner .
status=0
"$SHANDALAR_TIMEOUT" -k 5 "${LAB_TIMEOUT:-600}" "$GODOT" --headless --path . \
  --log-file "$out/engine.log" res://tools/expansion_testing/expansion_lab.tscn -- "${args[@]}" \
  > "$out/engine-output.log" 2>&1 < /dev/null || status=$?
[ -n "$plugin" ] && rm -rf -- "$out/plugin"
if grep -Eq 'ERROR:|SCRIPT ERROR:|WARNING:|Parse Error|ObjectDB instances were leaked' "$out/engine-output.log"; then
  echo "Engine diagnostic; inspect $out/engine-output.log" >&2
  [ "$status" = 0 ] && status=1
fi
[ -f "$out/report.txt" ] && cat "$out/report.txt"
if [ "$status" = 0 ] && [ ! -f "$out/results.json" ]; then status=1; fi
exit "$status"
