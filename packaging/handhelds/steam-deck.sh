#!/bin/sh
# Native SteamOS launcher. Steam Input supplies keyboard and mouse events
# in a keyboard-and-mouse layout; in a gamepad layout the game's own pad
# pointer (Options > Pad pointer, on by itself when a pad is present)
# plays the table. SHANDALAR_HANDHELD names the device so the settings
# the player has never written open on a handheld's defaults - full
# screen, the click-to-enlarge card reader and the power saver on; an
# Options choice, once made, is kept over these.
set -eu
cd -- "$(dirname -- "$0")"
export SHANDALAR_HANDHELD=steam-deck
# A bare -h/--help is the engine's own; this hands it to the game's list.
case "${1:-}" in -h | --help) exec ./Shandalar.x86_64 --headless --no-header -- --help ;; esac
exec ./Shandalar.x86_64 --rendering-method gl_compatibility --max-fps 60 --resolution 1280x800 "$@"
