#!/usr/bin/env bash
# Shared local runtime discovery. Source from the project root.
# [QoL] The Ubuntu checkout may carry an ELF binary onto a Mac; prefer
# the sibling macOS app there. An explicit GODOT must never be ignored.
shandalar_find_godot() {
	if [ -z "${GODOT:-}" ]; then
		if [ "$(uname -s)" = Darwin ] && [ -x ../tools/Godot.app/Contents/MacOS/Godot ]; then
			GODOT=../tools/Godot.app/Contents/MacOS/Godot
		# On a Mac without the app, ../tools/godot is the Linux binary (exit
		# 126 on every tool): a `godot` on PATH comes first there.
		elif [ -x ../tools/godot ] && { [ "$(uname -s)" != Darwin ] || ! command -v godot >/dev/null 2>&1; }; then
			GODOT=../tools/godot
		else
			GODOT=godot
		fi
	fi
	if ! command -v "$GODOT" >/dev/null 2>&1; then
		echo "No Godot binary to run: $GODOT. Set GODOT=/path/to/Godot (4.7.2)." >&2
		return 3
	fi
}

shandalar_find_timeout() {
	if command -v timeout >/dev/null 2>&1; then
		SHANDALAR_TIMEOUT=timeout
	elif command -v gtimeout >/dev/null 2>&1; then
		SHANDALAR_TIMEOUT=gtimeout
	else
		echo "GNU timeout is required. On macOS: brew install coreutils" >&2
		return 3
	fi
}

shandalar_test_profile() {
	: "${SHANDALAR_TEST_DATA_HOME:=${TMPDIR:-/tmp}/shandalar-test-data}"
	mkdir -p "$SHANDALAR_TEST_DATA_HOME" || return
	export XDG_DATA_HOME="$SHANDALAR_TEST_DATA_HOME"
	# Godot ignores XDG_DATA_HOME on macOS (reproduced 2026-09-12;
	# home-directory username redacted):
	# PROFILE_PROBE user_dir=/Users/<user>/Library/Application Support/Godot/app_userdata/Shandalar Profile Probe
	# PROFILE_PROBE xdg=/private/tmp/shandalar-profile-probe
	# The editor's runtime feature override selects a separate profile
	# before autoloads read settings. It is NOT passed to export commands.
	# Also select this feature on Linux: numbered-pack metadata-only
	# fixtures are accepted solely in this explicit test runtime. XDG
	# isolation alone must not turn an ordinary player ZIP into a fixture.
	export GODOT_EDITOR_CUSTOM_FEATURES="${GODOT_EDITOR_CUSTOM_FEATURES:+$GODOT_EDITOR_CUSTOM_FEATURES,}shandalar_test"
}
