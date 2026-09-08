extends GutTest
## THE SHELL'S BED IS ONE BED FOR EVERY ROOM — `game/shell_music.gd`, the
## `ShellMusic` autoload, from the owner's 2026-09-07 playtest:
##
##   *"Help and options in main menu should have same music as main menu."*
##
## Three playtest notes in a row were the same note — the title screen
## (2026-09-04), Magic Battle (2026-09-05), now Help and Options — and
## the answer that makes all three hold is that the shell has ONE tune
## and one player that outlives its rooms. What is pinned here is the
## contract of that player and nothing about the bed itself (which is
## `tests/ui/test_title_screen.gd`'s: which track, why, the fallbacks):
##
##   1. Every room of the shell — the title screen, Magic Battle, Options,
##      Help — finds the bed playing when it opens and does not restart
##      it: the SAME stream object, uninterrupted, across all four.
##   2. Every door that leads OUT of the shell stops it: the Deck Builder,
##      the Gauntlet and the table each start a bed of their own against
##      silence. (Magic Battle's `Go!` is the fourth door; it is pinned
##      in `test_setup_screen.gd`, on the source, because no test can
##      start a duel through it.)
##   3. The Options screen's music controls act on the bed AT ONCE — the
##      switch stops and restarts it, the picker changes it — rather than
##      at the next room.
##   4. Headless, it never starts a voice.
##
## THE MUSIC SEAMS are [MusicLibrary]'s own `dirs` / `skin_dirs`, pointed
## at scratch folders exactly as `test_title_screen.gd` points them, so
## the file tests one thing whether or not this machine has the 1997
## `Sound/` folder imported.

const PLAYER_DIR := "user://test_shell_music_player"
const SKIN_DIR := "user://test_shell_music_skin"

const ROOMS: Array[String] = [
	"res://game/main.tscn",
	"res://game/setup_screen.tscn",
	"res://game/options_screen.tscn",
	"res://game/help/help_screen.tscn",
]

var _made: Array[String] = []
var _saved: Dictionary = {}


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved = {}
	_made = []
	MusicLibrary.dirs = [PLAYER_DIR]
	MusicLibrary.skin_dirs = [SKIN_DIR]
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	_unset(MusicLibrary.SETTING)
	_unset("music_enabled")
	_write_every_original_track()
	# The autoload's player outlives every test: start each one from a
	# stopped bed, and from one that is allowed to make a (headless)
	# voice — as `test_title_screen.gd` does for the same reason.
	ShellMusic.stop()


func after_each() -> void:
	ShellMusic.stop()
	if ShellMusic.player() != null:
		ShellMusic.player().silent = DisplayServer.get_name() == "headless"
	for path in _made:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_made = []
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		PLAYER_DIR.path_join(MusicLibrary.README_NAME)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_DIR))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SKIN_DIR))
	MusicLibrary.dirs = [GamePaths.music_folder()]
	MusicLibrary.skin_dirs = null
	MusicLibrary.refresh()
	MusicPlayer.reset_order()
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	SetupScreen.forget_choices()


# ------------------------------------------------------------ fixtures --

func _unset(key: String) -> void:
	if not _saved.has(key):
		_saved[key] = Settings.get_value(key, null) \
			if Settings.has_value(key) else null
	Settings.clear_value(key)


## A real, minimal PCM wav — 22 050 Hz, mono, 16-bit, like every file the
## original ships. Written rather than copied: no original bytes travel
## with this suite.
func _wav(frames: int) -> PackedByteArray:
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	pcm.fill(0)
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_u32(36 + pcm.size())
	buf.put_data("WAVEfmt ".to_ascii_buffer())
	buf.put_u32(16)
	buf.put_16(1)
	buf.put_16(1)
	buf.put_u32(22050)
	buf.put_u32(44100)
	buf.put_16(2)
	buf.put_16(16)
	buf.put_data("data".to_ascii_buffer())
	buf.put_u32(pcm.size())
	buf.put_data(pcm)
	return buf.data_array


func _write(dir_path: String, name: String) -> String:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(dir_path))
	var path := dir_path.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_wav(64))
	file.close()
	_made.append(path)
	MusicLibrary.refresh()
	return path


func _write_every_original_track() -> void:
	for row in MusicLibrary.ORIGINAL_TRACKS:
		_write(SKIN_DIR, String(row[0]) + ".wav")


## A room, built and given its frame. The screen's `_ready` is what asks
## the autoload for the bed, so the assertions come after this.
func _open(scene_path: String) -> Control:
	var room: Control = load(scene_path).instantiate()
	add_child_autofree(room)
	await get_tree().process_frame
	return room


## The bed the shell should be playing with the whole library present.
func _bed() -> String:
	return MusicLibrary.single_for(ShellMusic.MENU_BEDS)


## Let the autoload's (headless) player make a voice, and ask for the bed.
func _sound_on() -> MusicPlayer:
	ShellMusic.play()
	var player := ShellMusic.player()
	player.silent = false
	ShellMusic.play()
	return player


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


# ============================================ 0. THE AUTOLOAD ITSELF ==

func test_the_shell_has_one_player_and_it_is_the_autoloads() -> void:
	var hook := get_tree().root.get_node_or_null("ShellMusic")
	assert_not_null(hook, "`ShellMusic` is registered in project.godot")
	assert_true(hook.get_script() != null
		and (hook.get_script() as GDScript).resource_path
			== "res://game/shell_music.gd")
	var player := _sound_on()
	assert_not_null(player, "asking for the bed makes the player")
	assert_true(player is MusicPlayer)
	assert_eq(player.get_parent(), hook,
		"…and it lives under the autoload, not under any screen")
	assert_eq(ShellMusic.bed(), _bed())
	assert_eq(player.key, _bed(), "`bed()` is the player's own key")


func test_asking_again_for_the_bed_that_is_up_leaves_it_alone() -> void:
	var player := _sound_on()
	var stream := player.stream
	for _i in 5:
		ShellMusic.play()
	assert_eq(player.stream, stream, "not restarted, not rebuilt")
	assert_true(player.playing)


func test_stop_lets_go_of_the_tune_and_the_audio_behind_it() -> void:
	var player := _sound_on()
	assert_eq(player.tracks.size(), 1, "up")
	ShellMusic.stop()
	assert_eq(ShellMusic.bed(), "", "no bed")
	assert_eq(player.tracks, [] as Array[String])
	assert_false(player.playing)
	assert_null(player.stream, "and the PCM is dropped, not carried")


# ======================================== 1. THE ROOMS KEEP THE BED ==

func test_every_room_of_the_shell_finds_the_bed_playing_and_keeps_it() -> void:
	# THE WHOLE ITEM. The title screen starts the bed; Magic Battle,
	# Options and Help each open into it and none of them restarts it —
	# the very same stream object is playing after all four, which is the
	# difference between one soundtrack and four jingles.
	var player := _sound_on()
	var stream := player.stream
	assert_not_null(stream)
	var previous: Control = null
	for scene_path in ROOMS:
		if previous != null:
			remove_child(previous)
			previous.free()
			await get_tree().process_frame
		var room: Control = await _open(scene_path)
		previous = room
		assert_true(player.playing, "%s: the bed is playing" % scene_path)
		assert_eq(player.key, _bed(), "%s: the shell's bed" % scene_path)
		assert_eq(player.stream, stream,
			"%s: the SAME stream — not restarted at the door" % scene_path)
		for node in _walk(room):
			assert_false(node is MusicPlayer,
				"%s holds no player of its own" % scene_path)


func test_a_room_opened_cold_starts_the_bed_itself() -> void:
	# Whatever room a scripted route (or a tool) opens first, the bed
	# comes up: none of the four assumes the title screen ran before it.
	for scene_path in ROOMS:
		ShellMusic.stop()
		ShellMusic.player().silent = false
		var room: Control = await _open(scene_path)
		assert_eq(ShellMusic.bed(), _bed(), "%s starts it" % scene_path)
		remove_child(room)
		room.free()
		await get_tree().process_frame


func test_a_room_going_does_not_take_the_bed_with_it() -> void:
	var player := _sound_on()
	var room: Control = await _open("res://game/help/help_screen.tscn")
	remove_child(room)
	room.free()
	await get_tree().process_frame
	assert_true(is_instance_valid(player))
	assert_true(player.playing, "Help closed; the shell's tune plays on")
	assert_eq(player.key, _bed())


# ========================================= 2. THE DOORS STOP THE BED ==

func test_the_deck_builder_stops_it_at_the_door() -> void:
	# The Deck Builder has a bed of its own (LocMus1, `deck_builder_beds`)
	# and starts it against silence.
	var player := _sound_on()
	assert_true(player.playing)
	var builder: Control = await _open(
		"res://game/deck_builder/deck_builder_screen.tscn")
	assert_false(player.playing, "the shell's bed stopped")
	assert_eq(ShellMusic.bed(), "")
	assert_null(player.stream)
	assert_not_null(builder)


func test_the_table_stops_it_at_the_door() -> void:
	# Whatever route led to the table, its `_ready` stops the shell's bed
	# before the duel's own tune (`Dueltune`) would start.
	var player := _sound_on()
	assert_true(player.playing)
	var duel: Control = await _open("res://game/duel/duel_screen.tscn")
	assert_false(player.playing, "the shell's bed stopped")
	assert_eq(ShellMusic.bed(), "")
	assert_not_null(duel)


func test_the_gauntlet_stops_it_at_the_door() -> void:
	# The Gauntlet has a bed of its own too (`GAUNTLET_BEDS`, deliberately
	# not the shell's) and starts it against silence.
	var player := _sound_on()
	assert_true(player.playing)
	var gauntlet: GauntletScreen = \
		load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 90210
	gauntlet.config = config
	gauntlet.opponent_paths = ["res://decks/blue_skies.deck"] as Array[String]
	gauntlet.options.best_of = 1
	gauntlet.options.ante = false
	gauntlet.options.your_deck = "res://decks/big_green.deck"
	add_child_autofree(gauntlet)
	await get_tree().process_frame
	assert_false(player.playing, "the shell's bed stopped")
	assert_eq(ShellMusic.bed(), "")


func test_the_global_switch_is_the_whole_rule() -> void:
	# `music_enabled` off: stopped and the PCM dropped. On: back. The
	# Deck Builder's screen-scoped switch says nothing about the shell.
	var player := _sound_on()
	assert_eq(player.tracks.size(), 1, "up by default")
	Settings.set_value("music_enabled", false)
	ShellMusic.play()
	assert_false(player.playing, "off stops it")
	assert_null(player.stream, "and lets go of the PCM")
	Settings.set_value("music_enabled", true)
	ShellMusic.play()
	assert_true(player.playing, "on brings it back")
	assert_eq(player.key, _bed())


# ================================= 3. OPTIONS ACTS ON IT AT ONCE ==

func _music_switch(options: Control) -> CheckButton:
	for node in _walk(options):
		if node is CheckButton and node.text == "Music":
			return node
	return null


func _track_picker(options: Control, track_name: String) -> OptionButton:
	for node in _walk(options):
		if node is OptionButton:
			for i in node.item_count:
				if node.get_item_text(i) == track_name:
					return node
	return null


func test_the_options_music_switch_stops_and_restarts_the_bed_at_once() -> void:
	# The one room where a player is LISTENING for the music: the switch
	# answers here and now, not at the next room.
	var player := _sound_on()
	var options: Control = await _open("res://game/options_screen.tscn")
	var switch := _music_switch(options)
	assert_not_null(switch, "the Music switch is on the screen")
	assert_true(switch.button_pressed, "and reads the default: on")
	switch.button_pressed = false
	assert_false(Settings.music_enabled(), "the key")
	assert_false(player.playing, "the bed stopped the moment it was unticked")
	assert_null(player.stream, "and the PCM went with it")
	switch.button_pressed = true
	assert_true(player.playing, "…and came back the moment it was ticked")
	assert_eq(player.key, _bed())


func test_the_options_track_picker_changes_the_bed_at_once() -> void:
	# A track chosen under Options -> Music is the bed everywhere, the
	# shell included (`test_title_screen.gd`) — and the shell, playing
	# behind the picker, changes to it as it is chosen.
	_write(PLAYER_DIR, "windswept_march.wav")
	var player := _sound_on()
	assert_eq(player.key, _bed(), "the shell's own pick first")
	var options: Control = await _open("res://game/options_screen.tscn")
	var picker := _track_picker(options, MusicLibrary.name_of("windswept_march"))
	assert_not_null(picker, "the picker lists the player's own track")
	var row := -1
	for i in picker.item_count:
		if picker.get_item_text(i) == MusicLibrary.name_of("windswept_march"):
			row = i
	picker.select(row)
	picker.item_selected.emit(row)
	assert_eq(MusicLibrary.choice(), "windswept_march", "the key")
	assert_eq(player.tracks, ["windswept_march"] as Array[String],
		"the bed changed as the choice was made")
	assert_true(player.playing)
	# And back to "you choose": the shell's own pick, at once.
	picker.select(0)
	picker.item_selected.emit(0)
	assert_eq(MusicLibrary.choice(), MusicLibrary.CHOICE_SHUFFLE)
	assert_eq(player.key, _bed(), "the shell's own bed again")


# ================================================ 4. HEADLESS: SILENT ==

func test_headless_it_starts_no_voice() -> void:
	# The rule for the whole suite and the soak: no audio device, no
	# sample read, no voice — and the shell's is the player every headless
	# run makes first.
	ShellMusic.play()
	var player := ShellMusic.player()
	assert_true(player.silent, "a headless run says so for itself")
	assert_eq(player.tracks, [] as Array[String])
	assert_null(player.stream)
	assert_false(player.playing)
	assert_eq(ShellMusic.bed(), "")
