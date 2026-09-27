#!/bin/sh
# Native SteamOS launcher. Steam Input supplies keyboard and mouse events.
set -eu
cd -- "$(dirname -- "$0")"
exec ./Shandalar.x86_64 --rendering-method gl_compatibility --max-fps 60 --resolution 1280x800 "$@"
