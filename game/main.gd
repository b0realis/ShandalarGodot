class_name MainScreen
extends Control
## Title screen — three stone buttons aligned center-right over the
## original title art (the 1997 shell's composition): Magic Battle opens
## the battle-setup screen, Options the options screen, Exit quits.
## The adventure mode (M5) will grow this menu; the flow stays:
## menu -> setup -> duel.


## The shell column's button size. Eight entries have to sit clear of the
## title art's own lettering; see the column in [method _ready].
const MENU_BUTTON := Vector2(228, 36)
## The gap between them.
const MENU_GAP := 6
## Letters to match: the default 22 is cut by a 36px-high frame.
const MENU_FONT := 21
## Faked weight — MagicMedieval ships no bold ([method UiChrome.menu_button]).
const MENU_BOLD := 0.05

## THE SHELL'S BED — the one tune the title screen loops, and the beds it
## falls back to when the player has not imported that one. The owner's
## playtest of 2026-09-04: *"Play a suitable soothing music at the main
## menu."*
##
## **WHAT THE 1997 SHELL PLAYED: NOTHING.** This was asked as a provenance
## question first, and the answer is that the original's shell screen has
## no music bed at all. The shell is `Magic.exe`'s own window class
## (`wndproc_MagicShellClass`, `Magic-trace.c:4124`, entry `4CC770`); it
## loads its art from `\ShellArt` (`%s\WINBK_ShellScreen16.bmp`, the five
## `%s\WINBK_ShellSphereAnimation16-%d.bmp` frames) and its pages from
## `@SHELLSCREEN_DUEL` / `_TOOLS` / `_METAGAME` / `_HELP` / `_RECORDS`.
## Its ENTIRE audio vocabulary is the 68-entry one-shot table at
## `shandalar-src/src/functions/windows.c:1181-1266`, and the only shell
## entries in it are seven cues — `WAV_SHELL_SHANDALAR`, `_TOOLTIME`,
## `_HELPME`, `_HALLOFRECORDS`, `_DUELMENOW` (ids 60-64) and
## `_WINDUEL`/`_LOSEDUEL` (44-45), `defs.h:2232-2252`. Those five map
## one-to-one onto the five shell pages and measure 2.8-6.1 s each
## (`Duelsounds/Shell_*.wav`, 22 050 Hz stereo): they are page stingers,
## not a bed. Every LOOPING bed literal in the original —
## `x:sound\dueltune.wav`, `x:sound\locmus0..19.wav`,
## `x:sound\tmplmus1.wav`, `x:sound\[bgruw]castle.wav` — lives in
## `Shandalar.exe`, the ADVENTURE, and none of them in the shell's exe,
## which carries no `music` string and no `sound\` path at all. A full
## audio inventory of the owner's install confirms it: there is no title
## or menu file to source. So the title screen's music is `[QoL]`, and
## the choice below is OURS.
##
## **HOW THE BED WAS CHOSEN, WITHOUT ANYBODY HEARING IT.** Nobody on this
## side of the work can listen to audio, so the pick is made on what the
## bytes can be measured for. All 27 beds were read for duration, peak,
## RMS, crest, the spread between the 10th and 90th percentile of a 20 ms
## loudness envelope, the rate of frames whose energy jumps 6 dB
## (transients per second), zero-crossing rate and a high-frequency
## energy ratio. `music_location_15` (LocMus15) came out as the calmest
## bed the Deck Builder does not already own:
##
##   * **0.06 transients/s** over 36 s — joint lowest of the twenty
##     location beds, i.e. essentially no percussion or stabs.
##   * **816 zero-crossings/s and -19.2 dB of high-frequency energy** —
##     the second-darkest bed in the library; a sustained thing, not a
##     bright or busy one.
##   * **8.3 dB of loudness spread**, no frame below -50 dBFS: it never
##     swells and it never drops out.
##   * **36.0 s**, the second-longest bed there is, so the loop wraps
##     less often than anything else would.
##
## The two the prompt guessed at do NOT measure calmest, which is why
## this list is not headed by either. `music_temple` (Tmplmus1) is the
## SHORTEST bed at 24.9 s, spends only 43% of its length within 3 dB of
## its own median and has an 18.2 dB crest — a struck, bell-like shape.
## `music_castle_blue` is 30.6% SILENCE, an ambience file with holes in
## it, which would loop as a tune that keeps stopping.
##
## **THIS IS A JUDGEMENT MADE WITHOUT HEARING THE MUSIC.** If the owner
## disagrees, the fix is ONE LINE: put another id first in this list.
## The runners-up are here in measured order behind it —
## `music_location_8` (equally transient-free and steadier still, but
## brighter and shorter) and `music_location_2` (a little quieter),
## with `music_temple` last as the calmest of the non-location beds.
##
## **NOT THE DECK BUILDER'S BED, deliberately.** That screen loops
## [method MusicLibrary.single_for] over `deck_builder_beds()` =
## LocMus1..19, so it takes `music_location_1` — measurably the steadiest
## bed of all, and already spoken for. Sharing it would mean the same
## track restarting from zero every time the player crossed between the
## two screens, which reads as a stutter rather than as continuity.
const MENU_BEDS: Array[String] = [
	"music_location_15",
	"music_location_8",
	"music_location_2",
	"music_temple",
]

## The shell's own voice on the Music bus. Freed with the screen.
var _music: MusicPlayer


## The flag that turns the shipped game into the Deck Lab.
##
## THE EXPORTED BINARY WILL NOT RUN `--script`. That flag is honoured by
## the editor and by a debug template; a release template ignores it and
## launches the game instead (measured 2026-09-05: the process simply ran
## the title screen until the timeout killed it). So the lab cannot be
## reached from outside — it has to be let in from the inside, and the
## title screen is the first of our code that runs.
##
## The cost is one string comparison before anything is built, and the
## gain is that a player who downloaded a 296 MB zip has the same
## thousand-game deck tester the developers use, against the same engine
## that just played their duel. `DeckLab/README.md` is its manual and
## ships beside the binary.
const DECK_LAB_FLAG := "--deck-lab"


func _ready() -> void:
	# BEFORE THE SCREEN IS BUILT, and before the card pool is loaded: the
	# lab loads its own and the shell has nothing to contribute to a
	# headless run.
	if OS.get_cmdline_user_args().has(DECK_LAB_FLAG):
		_run_deck_lab()
		return
	CardRegistry.ensure_loaded()
	var title_bg := GameSkin.texture("title_background")
	if title_bg != null:
		var bg := TextureRect.new()
		bg.texture = title_bg
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Lower-right, clear of the big Magic logo and "The Gathering" text.
	#
	# THE COLUMN IS SIZED BY WHAT IT MUST CLEAR. Eight entries at the old
	# 260x46 would reach up into "The Gathering" — the 2026-09-03 playtest
	# asked for the menu "juuust a little bit" left and lower with smaller
	# buttons, which is the same instruction stated as a measurement: the
	# painting's title text ends around y=400 of 800, so eight buttons,
	# their gaps and the bottom inset have to fit in what is below it.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", MENU_GAP)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# With grow BEGIN, position marks the BOTTOM-RIGHT corner the column
	# grows up-left from.
	#
	# X IS MEASURED OFF THE PAINTING, not guessed. The 2026-09-04 playtest
	# asked for the column centred under "The Gathering". `Shellscreen`
	# is 640x480 shown COVERED in a 1280x800 window, so it scales x2 and
	# the horizontal mapping is exactly 2x: the subtitle's lettering runs
	# x=612..1178 on screen (the (R) sits outside it, at 1205), so its
	# centre is 895. A 228-wide column centred there has its right edge at
	# 1009, which is 271 in from the right anchor.
	#
	# Y IS MEASURED THE SAME WAY, and the strip is TIGHT. The subtitle's
	# lowest ink is not its baseline but the descender of "Gathering"'s
	# g, which reaches y=432; the screen ends at 800. That leaves 368px
	# for a column that stood 358 tall, i.e. TEN pixels of slack, spent
	# 6 above and 4 below — which is why Exit sat on the screen edge
	# (2026-09-04 playtest). Air at the bottom therefore had to be bought,
	# not moved: [constant MENU_GAP] went 10 -> 6, freeing 28px, and the
	# inset went 4 -> 26. The column is now 330 tall at y=444..774 — 12px
	# clear of the g and 26 clear of the edge, and its mass sits 8px
	# higher than before.
	box.position += Vector2(-271, -26)
	add_child(box)

	var battle := _menu_button("Magic Battle")
	battle.pressed.connect(_open.bind("res://game/setup_screen.tscn"))
	box.add_child(battle)

	# THE GAUNTLET — the fourth 1997 duel mode, and until now the only one
	# this project had never had. `@SHELLSCREEN_DUEL`
	# (`Program/UIStrings.txt:5-11`) lists the shell's four duel modes with
	# their own one-line descriptions and NUMBERS them; the gauntlet is
	# entry 2, directly under `1Solo &Duel` — which is our Magic Battle —
	# so it sits directly under it here. The tooltip is the entry's own
	# description, after the colon, exactly as Deck Builder's is:
	#     `2&Gauntlet:Defeat as many opponents in a row as possible.`
	var gauntlet := _menu_button("Gauntlet")
	gauntlet.tooltip_text = "Defeat as many opponents in a row as possible."
	gauntlet.pressed.connect(
		_open.bind("res://game/duel/gauntlet_screen.tscn"))
	box.add_child(gauntlet)

	# THE TWO THAT ARE NOT BUILT YET, in the order the 1997 shell would
	# have them: the adventure this project is named after (M5,
	# `docs/ROADMAP.md`) and the save/load the shell keeps beside it.
	# Placeholders on the owner's instruction (2026-09-03) — they are
	# ENABLED rather than greyed, because a disabled button in Godot
	# swallows its own tooltip and a player deserves to be told WHY a
	# front door is shut. Each opens one sentence.
	var shandalar := _menu_button("Shandalar")
	shandalar.pressed.connect(func() -> void:
		UiChrome.explain_popup(self, "Shandalar",
			"The adventure — the world map, its cities and dungeons, the "
			+ "wizards who hold the five castles, and the ante you play "
			+ "them for. Not built yet: this is milestone M5, and the "
			+ "duel it will be played through is what exists today."))
	box.add_child(shandalar)

	var save_load := _menu_button("Save / Load")
	save_load.pressed.connect(func() -> void:
		UiChrome.explain_popup(self, "Save / Load",
			"Nothing to save yet. A duel is one sitting, and the "
			+ "adventure that would need a saved game is not built. "
			+ "Decks you build ARE kept — the Deck Builder writes them "
			+ "into your own folder and they are there next time."))
	box.add_child(save_load)

	# `@SHELLSCREEN_TOOLS` (shandalar-src/Program/UIStrings.txt) lists the
	# original shell's Tools page as "&Deck Builder:Build or Modify decks."
	# — the button's label and, after the colon, its own description, which
	# the 1997 shell showed as a status line and we show as a cue card.
	var deck_builder := _menu_button("Deck Builder")
	deck_builder.tooltip_text = "Build or Modify decks."
	deck_builder.pressed.connect(
		_open.bind("res://game/deck_builder/deck_builder_screen.tscn"))
	box.add_child(deck_builder)

	var options := _menu_button("Options")
	options.pressed.connect(_open.bind("res://game/options_screen.tscn"))
	box.add_child(options)

	# HELP — directly above Exit, per the owner. The 1997 game reached its
	# help by right-clicking the dueling table (manual p.14: "One of the
	# options is Help"); we have no such context menu, so the reference gets
	# a front door on the shell instead. `game/help/help_screen.gd`.
	var help := _menu_button("Help")
	help.tooltip_text = "The mana, the rules, and every icon — explained."
	help.pressed.connect(_open.bind("res://game/help/help_screen.tscn"))
	box.add_child(help)

	var exit_button := _menu_button("Exit")
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(exit_button)


	# Version tag in the bottom-right corner, under the buttons.
	var version := Label.new()
	version.text = "v%s · %d cards" % [
		ProjectSettings.get_setting("application/config/version", "dev"),
		CardRegistry.size()]
	_corner_label(version, 12)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position += Vector2(-10, -8)
	add_child(version)

	# THE WORDMARK OVER THE CARD POOL, bottom-left. Both were here before
	# in some form — the name in this corner at 16px, the badges up in the
	# TOP-left — and the 2026-09-03 playtest asked for them stacked: the
	# badges down here, the name above them, and the name bigger. They say
	# two halves of one thing (what this is called, what it is made of), so
	# they now read as one mark instead of two unrelated corners.
	#
	# The column grows UP and RIGHT from the bottom-left corner, the mirror
	# of the button column's up-and-left.
	var corner := VBoxContainer.new()
	corner.add_theme_constant_override("separation", 8)
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.grow_horizontal = Control.GROW_DIRECTION_END
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.position += Vector2(10, -8)
	add_child(corner)

	# Still the corner voice, not UiChrome's: this label sits on the title
	# PAINTING, whose bottom-left third measures 69/255 (PIL, 2026-09-03),
	# and pale ink on a hard shadow is what carries there. UiChrome's dark
	# INK is for text on the sandstone panels, which this is not.
	var wordmark := Label.new()
	wordmark.text = "ShandalarGodot"
	_corner_label(wordmark, 34)
	wordmark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	corner.add_child(wordmark)

	# THE CARD POOL: a row of badges saying which expansions this game is
	# made of. One per CardRegistry.SET_ORDER, a 1997 expansion symbol
	# where the original drew one and letters where it did not
	# (`game/set_badges.gd` carries the evidence for which is which). It
	# sits on a stone plaque rather than bare on the art like the wordmark:
	# that is TEXT, which the corner ink and its one-pixel shadow can carry
	# on any ground, while a 22px symbol on the title painting's own busy
	# stonework cannot.
	# Each badge answers a click with its set's own window: the date, how
	# much of it is in this game, and what the set was (the owner's ask,
	# 2026-09-03 — "each icon should be clickable with a mini popup ...
	# and mini lore info"). SetBadges knows the facts; the shell decides
	# where the window opens, which is what the signal is for.
	var row := SetBadges.new()
	row.set_clicked.connect(func(code: String) -> void:
		var facts := SetBadges.facts_for(code)
		UiChrome.explain_popup(self, String(facts.get("name", code)),
			SetBadges.describe(code), 520.0))
	var badges := UiChrome.panel_around(row, 8.0)
	badges.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	corner.add_child(badges)

	_start_music()


## THE TITLE SCREEN HAS MUSIC, AND IT IS ONE BED, LOOPING — see
## [constant MENU_BEDS] for what the 1997 shell played (nothing) and how
## this one was picked.
##
## Built exactly the way the Deck Builder builds its own
## (`DeckBuilderScreen._start_music`): a [MusicPlayer] child, so the tune
## dies with the screen, and [method MusicPlayer.play_one] rather than
## [method MusicPlayer.play_key], so it is ONE bed on repeat and not the
## front of a shuffle. `play_one` lists the single track twice inside the
## [AudioStreamPlaylist], which is what gives the wrap a seam to
## crossfade instead of the click a patched loop marker makes.
##
## The buses are dressed before the first note: [method
## GameAudio.apply_settings] pushes the stored volume and the two
## enable switches onto them, so a player who turned the music down last
## session does not get one loud second of it first.
##
## Silent for a player who has not imported the original's `Sound/`
## folder — [MusicPlayer] treats a missing id as silence — and silent
## headless.
func _start_music() -> void:
	GameAudio.apply_settings()
	_music = MusicPlayer.new()
	add_child(_music)
	_apply_music_switch()


## Start or stop the bed to match the GLOBAL music switch — the same
## `music_enabled` key the Options screen shows and the Deck Builder's own
## `&Music` menu entry writes. The shell has no screen-scoped switch of
## its own (the Deck Builder's `deck_builder_music` is that screen's, and
## must not silence this one), so the global switch is the whole rule.
##
## Re-callable: [method MusicPlayer.play_one] keys on the track id, so
## asking again for the bed that is already up does nothing rather than
## restarting it.
func _apply_music_switch() -> void:
	if _music == null:
		return
	if not Settings.music_enabled():
		_music.stop_music()
		return
	_music.play_one(MusicLibrary.single_for(MENU_BEDS))


## THE SHELL'S TUNE DOES NOT FOLLOW THE PLAYER OUT. Leaving the title
## screen for the duel, the Deck Builder or Options stops it, so the
## screen that arrives starts its own bed against silence rather than
## against ours. Stopping also drops the stream, which is megabytes of
## PCM the next screen would otherwise be holding for nothing.
##
## Belt and braces on purpose: [method _open] stops it the moment the
## button is pressed (`change_scene_to_file` is deferred to the end of the
## frame), and this catches every other way the screen can leave.
func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop_music()


## Hand the rest of the command line to the Deck Lab and quit with its
## exit code.
##
## `simulate.gd` extends [SceneTree] because it is normally the whole
## program; constructed here it is an ordinary Object that happens to
## build a root window, so it is freed explicitly rather than left to a
## queue it never reaches. Nothing of the shell is touched — this
## function does not return.
func _run_deck_lab() -> void:
	var args := OS.get_cmdline_user_args()
	var forwarded := PackedStringArray()
	for arg in args:
		if arg != DECK_LAB_FLAG:
			forwarded.append(arg)
	var lab: Object = load("res://DeckLab/simulate.gd").new()
	var code := 1
	if lab.has_method("_main"):
		code = int(lab.call("_main", forwarded))
	lab.free()
	get_tree().quit(code)


## One shell button, at this screen's size.
static func _menu_button(label: String) -> Button:
	return UiChrome.menu_button(label, MENU_BUTTON, MENU_FONT, MENU_BOLD)


## The shared treatment of the two corner labels (see the wordmark above).
static func _corner_label(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _open(scene_path: String) -> void:
	if is_instance_valid(_music):
		_music.stop_music()
	get_tree().change_scene_to_file(scene_path)
