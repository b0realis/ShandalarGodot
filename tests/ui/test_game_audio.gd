extends GutTest
## THE MIXER AND THE SETTINGS BEHIND IT — `docs/duel-todo.md` §3.8
## (2026-09-02 pass).
##
## Until this pass the duel owned two bare [AudioStreamPlayer]s and copied
## `Settings.sfx_volume_db()` onto one of them once, at build time. Two
## defects fell out and both are pinned here:
##
##  1. **A slider that moved nothing.** The number was read once and
##     copied, so dragging Effects volume in the Options screen did not
##     change a duel already on screen. Volume lives on a BUS now, which
##     is a mixing point that exists before any player does.
##  2. **A setting the original had and we did not.** `&Music` and
##     `Sound &Effects` are two separate entries — 8 and 9 of
##     `@DECKSURFACE_STANDALONE` (`s30/assets/text/Menus.txt:169-179`) —
##     and we had one `sound_enabled` for both.
##
## Everything here runs headless, because [AudioServer] exists under the
## dummy driver and creating a bus opens no device.


var _saved := {}

const KEYS := ["sound_enabled", "music_enabled",
	"sfx_volume_db", "music_volume_db"]


func before_each() -> void:
	# Remember-and-restore, never write-the-default-back: putting a value
	# back that was never there MATERIALIZES a default into the player's
	# own settings file. That bug shipped a "fan" hand once
	# (Settings.clear_value exists for it).
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	GameAudio.set_hushed(false)
	GameAudio.apply_settings()


# ------------------------------------------------------------ the buses --

func test_the_two_buses_exist_and_send_to_master() -> void:
	GameAudio.ensure_buses()
	for bus_name in [GameAudio.MUSIC_BUS, GameAudio.SFX_BUS]:
		var index := AudioServer.get_bus_index(bus_name)
		assert_gt(index, 0, "%s is a bus of its own, not Master" % bus_name)
		assert_eq(AudioServer.get_bus_send(index), &"Master",
			"%s feeds Master" % bus_name)


func test_a_freshly_created_bus_already_carries_the_settings() -> void:
	# A SCREENSHOT CAUGHT THIS. The deck builder grew music, called only
	# `ensure_buses`, and its tune played at 0 dB because nothing had put
	# the player's -14 onto the bus yet. Creating a bus now dresses it, so
	# no screen can get this wrong by forgetting a call.
	Settings.set_value("music_volume_db", -19.0)
	Settings.set_value("sfx_volume_db", -8.0)
	for bus_name in [GameAudio.MUSIC_BUS, GameAudio.SFX_BUS]:
		var index := AudioServer.get_bus_index(bus_name)
		if index != -1:
			AudioServer.remove_bus(index)
	GameAudio.ensure_buses()
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.MUSIC_BUS), -19.0, 0.01)
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.SFX_BUS), -8.0, 0.01)


func test_ensure_buses_is_idempotent() -> void:
	GameAudio.ensure_buses()
	var count := AudioServer.bus_count
	GameAudio.ensure_buses()
	GameAudio.ensure_buses()
	assert_eq(AudioServer.bus_count, count,
		"every screen may call it in _ready without stacking buses up")


# ----------------------------------------- the settings reach the buses --

func test_the_volume_settings_land_on_the_buses() -> void:
	Settings.set_value("sfx_volume_db", -11.0)
	Settings.set_value("music_volume_db", -23.0)
	GameAudio.apply_settings()
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.SFX_BUS), -11.0, 0.01)
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.MUSIC_BUS), -23.0, 0.01)


func test_moving_a_slider_again_moves_the_bus_again() -> void:
	# THE DEFECT THIS PASS FIXED. The old code copied the number onto an
	# AudioStreamPlayer inside `_build_ui`, so the second change never
	# reached anything that was already playing.
	Settings.set_value("sfx_volume_db", -30.0)
	GameAudio.apply_settings()
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.SFX_BUS), -30.0, 0.01)
	Settings.set_value("sfx_volume_db", -3.0)
	GameAudio.apply_settings()
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.SFX_BUS), -3.0, 0.01)


func test_the_two_switches_mute_their_own_bus_and_only_their_own() -> void:
	# `&Music` and `Sound &Effects` are two entries in 1997, not one.
	Settings.set_value("sound_enabled", false)
	Settings.set_value("music_enabled", true)
	GameAudio.apply_settings()
	assert_true(GameAudio.bus_muted(GameAudio.SFX_BUS), "effects off")
	assert_false(GameAudio.bus_muted(GameAudio.MUSIC_BUS), "music still on")

	Settings.set_value("sound_enabled", true)
	Settings.set_value("music_enabled", false)
	GameAudio.apply_settings()
	assert_false(GameAudio.bus_muted(GameAudio.SFX_BUS), "effects back on")
	assert_true(GameAudio.bus_muted(GameAudio.MUSIC_BUS), "music off")


func test_a_muted_bus_keeps_its_volume() -> void:
	# Mute is not "turn it down": unmuting must give the player the level
	# they set, not silence or 0 dB.
	Settings.set_value("music_volume_db", -17.0)
	Settings.set_value("music_enabled", false)
	GameAudio.apply_settings()
	assert_almost_eq(GameAudio.bus_volume_db(GameAudio.MUSIC_BUS), -17.0, 0.01)


# ---------------------------------------------------- the duel's M key --

func test_hush_silences_both_buses_without_writing_a_setting() -> void:
	Settings.set_value("sound_enabled", true)
	Settings.set_value("music_enabled", true)
	GameAudio.apply_settings()
	GameAudio.set_hushed(true)
	assert_true(GameAudio.bus_muted(GameAudio.SFX_BUS))
	assert_true(GameAudio.bus_muted(GameAudio.MUSIC_BUS))
	# THE POINT: muting to take a phone call must not still be muted next
	# week. The stored preferences are untouched.
	assert_true(Settings.sound_enabled(), "the SETTING is still on")
	assert_true(Settings.music_enabled(), "the SETTING is still on")
	GameAudio.set_hushed(false)
	assert_false(GameAudio.bus_muted(GameAudio.SFX_BUS), "and it comes back")
	assert_false(GameAudio.bus_muted(GameAudio.MUSIC_BUS))


func test_a_later_apply_does_not_undo_a_hush() -> void:
	# The Options screen calls apply_settings on every change; that must
	# not un-mute a duel the player hushed with `M`.
	GameAudio.set_hushed(true)
	Settings.set_value("sfx_volume_db", -5.0)
	GameAudio.apply_settings()
	assert_true(GameAudio.bus_muted(GameAudio.SFX_BUS))


# ------------------------------------------------ the settings round-trip --

func test_music_enabled_defaults_on_and_round_trips() -> void:
	Settings.clear_value("music_enabled")
	assert_true(Settings.music_enabled(), "music is on out of the box")
	Settings.set_value("music_enabled", false)
	assert_false(Settings.music_enabled(), "and the choice sticks")
	Settings.clear_value("music_enabled")
	assert_true(Settings.music_enabled(), "clearing restores the default")


func test_sound_enabled_is_a_separate_key() -> void:
	Settings.set_value("sound_enabled", false)
	Settings.set_value("music_enabled", true)
	assert_false(Settings.sound_enabled())
	assert_true(Settings.music_enabled())
