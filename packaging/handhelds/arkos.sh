#!/bin/bash
# Experimental ArkOS launcher; uses the installed PortMaster and WestonPack.
# Integration contract: https://github.com/binarycounter/Westonpack/wiki/Godot-4-Example
# No firmware changes, bundled runtime, Godot downgrade or system-wide settings.

sg_ports=$(cd -- "$(dirname -- "$0")" && pwd) || exit 1
GAMEDIR="$sg_ports/shandalar"
if [[ ! -f "$GAMEDIR/Shandalar.arm64" || ! -f "$GAMEDIR/Shandalar.pck" ]]; then
    printf '%s\n' 'Keep Shandalar.sh beside the complete shandalar folder.' >&2
    exit 1
fi
cd "$GAMEDIR" || exit 1
[[ ! -f portmaster.log ]] || mv -f portmaster.log portmaster.previous.log
exec >portmaster.log 2>&1

# Bash writes every here-document and here-string to a file under TMPDIR, and
# PortMaster's own scripts read device_info.txt and the dialog through them.
# A tester's R36 Ultra had its 11 GB system partition completely full: the
# shell could not create those files, control.txt came up half-read and the
# launcher blamed a missing controller mapper. The ports drive is where this
# game lives, so it is the drive with room: every temporary file goes beside
# the game, and the system drive is only ever read.
sg_tmp="$GAMEDIR/tmp"
mkdir -p "$sg_tmp" || { printf '%s\n' 'Shandalar: the game folder must be writable.'; exit 1; }
rmdir "$sg_tmp"/weston.* 2>/dev/null || true
export TMPDIR="$sg_tmp"
sg_free=$(df -Pk /tmp 2>/dev/null | awk 'NR == 2 { print $4 }')
if [[ "$sg_free" =~ ^[0-9]+$ && "$sg_free" -lt 1024 ]]; then
    printf 'Shandalar: /tmp has %s KB free; the system drive is full. PortMaster itself may fail until space is freed.\n' "$sg_free"
fi

sg_pm_candidates=("${SHANDALAR_PORTMASTER:-}" /opt/system/Tools/PortMaster
    /opt/tools/PortMaster "${XDG_DATA_HOME:-$HOME/.local/share}/PortMaster"
    "$sg_ports/PortMaster" /roms/ports/PortMaster /roms2/ports/PortMaster)
controlfolder=
for sg_candidate in "${sg_pm_candidates[@]}"; do
    if [[ -n "$sg_candidate" && -f "$sg_candidate/control.txt" ]]; then
        controlfolder=$sg_candidate
        break
    fi
done
if [[ -z "$controlfolder" ]]; then
    printf '%s\n' 'Install/update PortMaster first: https://portmaster.games/installation.html'
    exit 1
fi
# PortMaster may redirect controlfolder to another installation. Search both
# locations for its runtime later, rather than downloading a redundant copy.
source "$controlfolder/control.txt" || exit 1
if [[ -f "$controlfolder/mod_${CFW_NAME}.txt" ]]; then
    source "$controlfolder/mod_${CFW_NAME}.txt" || exit 1
fi
get_controls || exit 1
sg_fail() {
    printf 'Shandalar: %s\n' "$*"
    if declare -F pm_message >/dev/null; then pm_message "$*"; fi
    exit 1
}
[[ $(uname -m) == aarch64 ]] || sg_fail 'This package needs 64-bit ARM Linux.'
# Word-split PortMaster's two commands in the shell itself: no here-string,
# so no temporary file, and no glob expansion of their words.
set -f
sg_privilege=(${ESUDO:-})
sg_mapper=(${GPTOKEYB:-})
if [[ ${#sg_mapper[@]} -eq 0 && -x "$controlfolder/gptokeyb" ]]; then
    # control.txt did not export GPTOKEYB but the mapper is installed: run it
    # the way control.txt does.
    sg_mapper=("${sg_privilege[@]}" "$controlfolder/gptokeyb" ${ESUDOKILL:-})
    printf 'Shandalar: GPTOKEYB was not set by control.txt; using %s\n' "$controlfolder/gptokeyb"
fi
set +f
[[ ${#sg_mapper[@]} -gt 0 ]] ||
    sg_fail 'Update PortMaster: controller mapper (gptokeyb) unavailable; see portmaster.log in the game folder.'

sg_runtime_name=weston_pkg_0.2.squashfs
sg_runtime=
for sg_candidate in "$controlfolder" "${sg_pm_candidates[@]}"; do
    if [[ -n "$sg_candidate" && -f "$sg_candidate/libs/$sg_runtime_name" ]]; then
        sg_runtime="$sg_candidate/libs/$sg_runtime_name"
        break
    fi
done
if [[ -z "$sg_runtime" ]]; then
    [[ -f "$controlfolder/harbourmaster" ]] || sg_fail 'Install WestonPack using an updated PortMaster.'
    "${sg_privilege[@]}" "$controlfolder/harbourmaster" --quiet --no-check runtime_check "$sg_runtime_name" ||
        sg_fail 'WestonPack download failed. Install it in PortMaster, then retry.'
    sg_runtime="$controlfolder/libs/$sg_runtime_name"
    [[ -f "$sg_runtime" ]] || sg_fail 'WestonPack is still missing after the runtime check.'
fi

# Only unmount our own successful mount. Never unmount another port's runtime.
sg_weston=$(mktemp -d "$sg_tmp/weston.XXXXXX") || sg_fail 'Cannot create a mount point in the game folder.'
sg_mounted=0
sg_started=0
sg_mapper_pid=
sg_cleanup() {
    sg_status=$?
    trap - EXIT
    if [[ $sg_started == 1 ]]; then
        "${sg_privilege[@]}" "$sg_weston/westonwrap.sh" cleanup
    fi
    if [[ -n "$sg_mapper_pid" ]]; then
        "${sg_privilege[@]}" kill "$sg_mapper_pid" 2>/dev/null || true
        wait "$sg_mapper_pid" 2>/dev/null || true
    fi
    if [[ $sg_mounted == 1 ]]; then
        "${sg_privilege[@]}" umount "$sg_weston" || true
    fi
    rmdir "$sg_weston" 2>/dev/null || true
    rmdir "$sg_tmp" 2>/dev/null || true
    if declare -F pm_finish >/dev/null; then pm_finish; fi
    exit "$sg_status"
}
trap sg_cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"${sg_privilege[@]}" mount -o ro "$sg_runtime" "$sg_weston" || sg_fail 'Cannot mount WestonPack.'
sg_mounted=1
[[ -f "$sg_weston/westonwrap.sh" ]] || sg_fail 'WestonPack launcher is missing.'
[[ ! -f "$sg_weston/version.txt" ]] || source "$sg_weston/version.txt"
[[ ${wp_support26:-false} == true ]] || sg_fail 'Update WestonPack to 0.2.6 or newer in PortMaster.'

CONFDIR="$GAMEDIR/conf"
mkdir -p "$CONFDIR" "$CONFDIR/cache" || sg_fail 'The game folder must be writable for saves.'
chmod +x "$GAMEDIR/Shandalar.arm64" || sg_fail 'Cannot make the game executable.'
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-}"
# The device's name: settings never written open on a handheld's defaults
# (full screen, the card reader, the power saver); see game/settings.gd.
export SHANDALAR_HANDHELD=arkos
sg_width=${DISPLAY_WIDTH:-720}
sg_height=${DISPLAY_HEIGHT:-720}
[[ "$sg_width" =~ ^[1-9][0-9]{2,3}$ && "$sg_height" =~ ^[1-9][0-9]{2,3}$ ]] ||
    sg_fail 'PortMaster returned an invalid display size.'
printf 'Shandalar experimental ArkOS: display %sx%s, 30 FPS cap\n' "$sg_width" "$sg_height"
"${sg_mapper[@]}" Shandalar.arm64 -c "$GAMEDIR/shandalar.gptk" &
sg_mapper_pid=$!
if declare -F pm_platform_helper >/dev/null; then
    pm_platform_helper "$GAMEDIR/Shandalar.arm64"
fi
sg_started=1
# The unlikely VID/PID allowlist suppresses physical-pad input in Godot ONLY.
# Otherwise A could both click (gptokeyb) and pass priority (native joypad).
# Leave gptokeyb and Crusty's SDL input untouched; keyboard/mouse still work.
"${sg_privilege[@]}" env CRUSTY_SHOW_CURSOR=1 "$sg_weston/westonwrap.sh" \
    headless noop kiosk crusty_x11egl \
    XDG_DATA_HOME="$CONFDIR" XDG_CACHE_HOME="$CONFDIR/cache" \
    SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0xffff/0xffff \
    "$GAMEDIR/Shandalar.arm64" --display-driver x11 \
    --rendering-method gl_compatibility --rendering-driver opengl3_es \
    --audio-driver ALSA --resolution "${sg_width}x${sg_height}" --fullscreen --max-fps 30 "$@"
exit $?
