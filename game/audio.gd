class_name GameAudio
extends RefCounted
## THE MIXER — two audio buses, one stored value per setting, every screen
## reading the same ones.
##
## **WHY BUSES AND NOT PER-PLAYER VOLUME.** Until 2026-09-02 the duel
## screen owned exactly two [AudioStreamPlayer]s and copied
## `Settings.sfx_volume_db()` onto one of them at build time. Two
## consequences, both audible: every effect in the duel shared ONE voice,
## so a tap during a damage sound cut it off; and moving the Options
## slider changed nothing that was already on screen, because the number
## had been read once and copied. A bus fixes both — it is a mixing point
## that exists before any player does, so volume is set in one place and
## every voice routed there follows it, live.
##
## **WHAT THE ORIGINAL DID, from both directions.** The 1997 game did not
## mix by hand either. Its sound layer is `MAGSND.DLL`, addressed by SLOT
## NUMBER. Read from the CALLER: `play_sound_effect`
## (`shandalar-src/src/functions/windows.c:1268-1317`) asks
## `IsSndLoaded(soundnum, &adj_soundnum)` for the slot a WAV is loaded
## into, loads it into one if it is not, and then calls
## `PlaySnd(adj_soundnum)`; the deck builder drives the same interface with
## five slots at once — music on 1, draw on 2, discard on 3, button on 4,
## cancel on 5 (`src/deck/deckdll.cpp:2040-2056`). Read from INSIDE, in the
## Tier-2 decompilation of `MAGSND.DLL`: a 272-entry table holds one
## descriptor per loaded sound id, `IsSndLoaded` returns that descriptor's
## slot through its out-parameter, `GetLRUSnd` evicts within a
## caller-chosen sub-range, and `PlaySnd` re-triggers the buffer an id
## already owns rather than allocating a second one.
##
## So the original was **POLYPHONIC ACROSS DIFFERENT SOUNDS and MONOPHONIC
## PER SOUND**: two distinct WAVs sound together, and re-triggering one
## restarts it in the slot it already occupies. [DuelAudio] reproduces
## exactly that — a pool of voices, and one voice per cue per frame.
##
## **ONE VALUE, ONE STORAGE, MANY VIEWS.** The 1997 game had no global
## options screen: `&Music` and `Sound &Effects` are entries 8 and 9 of
## `@DECKSURFACE_STANDALONE` (`s30/assets/text/Menus.txt:169-179`) and of
## `@MAINMENU_STANDALONE` (`:218-228`) — the deck builder's own menu — and
## `global_cfg_music` is persisted by name (`deckdll.cpp:1267`,
## `cfg_write_int(global_cfg_music ? 1 : 0, "Music")`). Our `[QoL]` Options
## screen is an AGGREGATOR over the same two [Settings] keys the deck
## builder's menu writes, never a second copy of them.
##
## **HEADLESS.** Creating a bus touches [AudioServer], which exists under
## the dummy driver a `--headless` run gets and opens no device. Nothing
## here loads a sample, starts a player or waits.

## The bus every tune plays on — `Settings.music_volume_db()`.
const MUSIC_BUS := "Music"
## The bus every effect plays on — `Settings.sfx_volume_db()`.
const SFX_BUS := "SFX"

## A session-long silence that is NOT a stored preference: the duel's `M`
## key (`DuelScreen._unhandled_key_input`). It survives until the player
## presses `M` again or the process ends, and it never writes to
## `user://settings.cfg` — muting to take a phone call must not become the
## setting you find next week.
static var _hushed := false


## Create the two buses if they are not there yet. Idempotent, cheap, and
## safe to call from any screen's `_ready`.
##
## A bus that has just been CREATED is dressed at once, because a bus born
## at 0 dB is a bug that only shows up on a screen that forgot to call
## [method apply_settings] — which is exactly what the deck builder did
## when it first grew music, and what a screenshot caught. Making the
## buses arrive already carrying the player's settings means no screen can
## get this wrong.
static func ensure_buses() -> void:
	var created := false
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()               # appends at the end
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		created = true
	if created:
		_dress_all()


## Push the stored settings onto the buses. Called by every screen that
## makes a sound, and by the Options screen on every change — which is
## what makes a slider audible while you drag it.
static func apply_settings() -> void:
	ensure_buses()
	_dress_all()


static func _dress_all() -> void:
	_dress(MUSIC_BUS, Settings.music_volume_db(), Settings.music_enabled())
	_dress(SFX_BUS, Settings.sfx_volume_db(), Settings.sound_enabled())


static func _dress(bus_name: String, volume_db: float, enabled: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, volume_db)
	AudioServer.set_bus_mute(index, _hushed or not enabled)


## The volume a bus is actually carrying — the readout the tests assert
## against, and -inf-safe because a muted bus keeps its volume.
static func bus_volume_db(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	return 0.0 if index == -1 else AudioServer.get_bus_volume_db(index)


## Is this bus silent right now — muted by its own setting, or hushed?
static func bus_muted(bus_name: String) -> bool:
	var index := AudioServer.get_bus_index(bus_name)
	return false if index == -1 else AudioServer.is_bus_mute(index)


## The duel's `M` key: silence everything for this session without
## touching the player's stored preferences.
static func set_hushed(on: bool) -> void:
	_hushed = on
	apply_settings()


static func is_hushed() -> bool:
	return _hushed



# ====================================================== NOT A PHASE CUE ==
#
# **A PHASE CHANGE IS SILENT, and that is a ruling, not an oversight.**
# There was a `GameAudio.play_phase()` here for part of 2026-09-03, over
# the original's own `EndPhase.wav` (`WAV_ENDPHASE = 4`,
# `shandalar-src/src/defs.h:2186`). The owner settled it:
#
#   *"The changing phases or combat phases have no sound by themselves.
#    Card action and other actions that happen in phases have sound
#    effects."*
#
# So the rule for this whole layer is: **every sound is traceable to an
# ACTION** — a card cast, a land tapped, a creature attacking or dying,
# damage landing, the coin, a button — and never to the clock. A cue that
# fires because a step began is a defect however well sourced the file
# behind it is, and `EndPhase.wav` is deliberately NOT imported
# (`tools/import_original.py`, the `sfx_phase` note) so that nothing can
# quietly grow one back.
#
# The open cases this rule catches are listed in `docs/ROADMAP.md`,
# "The audio pass" — the untap step's sweep and the turn counter's
# `EndTurn.wav` are both call sites in `game/duel/`, not here.
