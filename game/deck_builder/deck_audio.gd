class_name DeckAudio
extends Node
## THE DECK BUILDER'S OWN SOUND — the 1997 deck surface's five slots, our
## one new sample, and the two switches that silence them.
##
## **THE ORIGINAL LOADED FIVE SOUNDS FOR THIS SCREEN AND NOTHING ELSE.**
## `init_sounds_and_music` (`shandalar-src/src/deck/deckdll.cpp:2040-2056`)
## opens the deck builder by filling five `MAGSND.DLL` slots — music on 1,
## `Draw.wav` on 2, `Discard.wav` on 3, `Button.wav` on 4 and a cancel cue
## on 5 — so the deck surface's whole vocabulary is *a card in*, *a card
## out*, *a button*, and the bed behind them. Three of those four are
## imported (`sfx_draw`, `sfx_discard`, `sfx_button`); the cancel cue has
## no file of its own in either `DuelSounds/` or `Sound/` and is therefore
## not played rather than guessed at.
##
## **AND ONE SOUND THAT IS OURS**, from the owner's own sample
## (2026-09-04): *"A quick stone grinding sound when pressing the stone
## filter buttons, based on my sample."* [constant GRIND] is that sample,
## trimmed to a quarter of a second (see the file's row in
## `Provenance.md`). It is the only sound in this game that did not come
## out of the 1997 install, which is why it ships INSIDE the pack — under
## `game/`, like `game/boot_splash.png` — instead of being read off the
## player's own copy of the original the way [GameSkin] reads everything
## else.
##
## ------------------------------------------------------------------------
## THE TWO SWITCHES, AND WHICH ONE WINS
## ------------------------------------------------------------------------
## The owner's playtest, 2026-09-04: *"The menu should contain also deck
## builder SFX and music checkboxes, as a user may be annoyed by SFX or
## music while deck building."* So these are SCREEN-SCOPED settings, and
## the precedence is stated once, here, and pinned by
## `tests/ui/test_deck_menu.gd`:
##
##     the global switch off  ->  silent, whatever this screen's box says
##     the global switch on   ->  this screen's own box decides
##
## In other words the two are ANDed and the global one can only ever take
## sound away. A player who turned all sound off under Options must not get
## grinding stone back because the builder's own box happens to be ticked;
## a player who silenced only the builder must still hear a duel.
##
## **THE DEFAULT IS ON AND IS NOT IN THE FILE.** [method sfx_on] and
## [method music_on] read through [method Settings.get_value]'s default, so
## a player who never touches either box has no key for either — which is
## the contract this project broke once and now tests for (`Settings.
## clear_value`, and `tests/ui/test_duel_options.gd`'s `_unset`). Writing
## the defaults in would MATERIALIZE them, and a later change of default
## would then not reach the players who had already opened this screen.
##
## ------------------------------------------------------------------------
## NO DEVICE, NO ERRORS
## ------------------------------------------------------------------------
## A headless run allocates no [AudioStreamPlayer], loads no sample and
## asks for no device — but it still records the cue in [member recent],
## which is the seam every test in this file acts through. `GameSkin.sound`
## answers null for a player who has not imported the original's sounds,
## and every path here treats null as silence rather than as an error.

## OUR OWN SAMPLE, shipped inside the `.pck`. A normal resource path, so
## the import pipeline carries it into the export — `assets/` is excluded
## from the build and `AudioStreamWAV.load_from_file` cannot read a file
## the pack does not hold.
const GRIND := "res://game/deck_builder/stone_grind.wav"

## The stored keys. Named for the screen they belong to, so nothing can
## mistake them for the two GLOBAL switches ([method Settings.sound_enabled],
## [method Settings.music_enabled]) that the Options screen and the deck
## surface's own `@DECKSURFACE_STANDALONE` mini-menu write.
const SFX_SETTING := "deck_builder_sfx"
const MUSIC_SETTING := "deck_builder_music"

## The cue names. Three are [GameSkin] keys (the 1997 files); the fourth is
## ours and is looked up in [constant GRIND] instead.
const CUE_FILTER := "deck_stone"   ## a filter medallion, on our own sample
const CUE_ADD := "sfx_draw"        ## `Draw.wav`, slot 2 — a card into the deck
const CUE_REMOVE := "sfx_discard"  ## `Discard.wav`, slot 3 — a card out of it
const CUE_BUTTON := "sfx_button"   ## `Button.wav`, slot 4 — a command

## How many effects may sound at once. The original held five slots for
## this screen; four voices covers every gesture it has, since the bed is
## not one of them ([MusicPlayer] owns its own voice).
const VOICES := 4

## How many cue names [member recent] keeps — bounded, so a long session
## cannot grow it without limit. [DuelAudio.RECENT_MAX]'s reasoning.
const RECENT_MAX := 32

## The cues this object decided to play, newest last. Tests read it, and it
## is filled whether or not there is a device to play them on.
var recent: Array[String] = []

## True for a run with no audio device: no player is created and no sample
## is read off disk. Tests flip it back to exercise the pool.
var silent := false

var _voices: Array[AudioStreamPlayer] = []
var _next_steal := 0


func _ready() -> void:
	GameAudio.apply_settings()
	silent = DisplayServer.get_name() == "headless"


# ---------------------------------------------------------- the switches --

## Is this screen allowed to make an effect? See the class doc for why the
## global switch is ANDed rather than consulted instead.
static func sfx_on() -> bool:
	return Settings.sound_enabled() and bool(Settings.get_value(SFX_SETTING, true))


## Is this screen allowed to play its bed? Same precedence.
static func music_on() -> bool:
	return Settings.music_enabled() and bool(Settings.get_value(MUSIC_SETTING, true))


## Tick or untick this screen's own SFX box. Never touches the global one.
static func set_sfx(on: bool) -> void:
	_store(SFX_SETTING, on)


## Tick or untick this screen's own music box. Never touches the global one.
static func set_music(on: bool) -> void:
	_store(MUSIC_SETTING, on)


## Store one switch — and store nothing at all when it goes back to its
## default. **Absence of a key IS the default**, and writing the default
## into `user://settings.cfg` MATERIALIZES it: the value stops tracking
## the shipped default for ever after, on that player's machine only.
## That bug has shipped in this project once (a "fan" hand), which is why
## [method Settings.clear_value] exists and why this is the only place
## these two keys are written.
static func _store(key: String, on: bool) -> void:
	if on:
		Settings.clear_value(key)
	else:
		Settings.set_value(key, false)


# -------------------------------------------------------------- the pool --

## Play one cue. An empty key is "no sound for this"; a key with no sample
## behind it is silence, not an error.
##
## THE GATE IS READ BEFORE THE CUE IS RECORDED, which is what lets a test
## pin the precedence without an audio device: a silenced screen decides
## nothing, rather than deciding and then failing to be heard.
func play(cue: String) -> void:
	if cue == "" or not sfx_on():
		return
	recent.append(cue)
	if recent.size() > RECENT_MAX:
		recent = recent.slice(recent.size() - RECENT_MAX)
	if silent:
		return
	var stream := stream_for(cue)
	if stream == null:
		return
	var voice := _free_voice()
	voice.stream = stream
	voice.play()


## The sample behind a cue: [constant GRIND] for our own one, the player's
## imported 1997 file for the rest. Null is silence everywhere.
##
## `load` rather than `AudioStreamWAV.load_from_file`: our sample goes
## through the import pipeline (it is the only sound this project ships),
## and `ResourceLoader` already caches it, so nothing here needs a cache of
## its own.
static func stream_for(cue: String) -> AudioStream:
	if cue != CUE_FILTER:
		return GameSkin.sound(cue)
	if not ResourceLoader.exists(GRIND):
		return null
	var res := load(GRIND)
	return res if res is AudioStream else null


## A voice that is not sounding, or the least recently stolen one when all
## of them are. Grown lazily, exactly as [DuelAudio] grows its pool, so a
## screen that never makes a noise allocates nothing.
func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	if _voices.size() < VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = GameAudio.SFX_BUS
		add_child(voice)
		_voices.append(voice)
		return voice
	_next_steal = (_next_steal + 1) % _voices.size()
	return _voices[_next_steal]
