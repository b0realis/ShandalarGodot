class_name DungeonSound
extends Node
## THE SOUNDS OF A CASTLE'S OR A DUNGEON'S BOARD (part C, stage C2) —
## 1997's (`RunCastleDungeonBoard`, dungeonEncounter.c 266–268, 411–447,
## 720–721, 862–871, 908–912; the c4 research, §7), heard while the board's
## pane ([DungeonPane]) is up:
##  - THE BED: `sfx_dungeon_loop` (Dambloop.wav) looped at 1997's volume 80
##    (−8 dB, [method WorldSoundscape.db]), centred, from the first view on;
##    stopped for every duel and back after one that returns to the board
##    ([method pause_for_duel], [method resume]), stopped as the board is
##    left ([method stop]). A seamless loop: the sample's own loop points
##    over the whole of it.
##  - THE AMBIENCE (dE:416–447): over the bed, one of
##    `sfx_dungeon_ambience_1`…`_5` (Damb1–5) now and then, timed in 1997's
##    UI ticks of 33 ms counted since the last sound: the first after 90–179
##    ticks (3.0–5.9 s); then another, never the one just played (the first
##    never Damb1), after 120–209 ticks — but Damb5, the drip, begins a
##    burst of 2–4 more of itself, the first after 60–89 ticks and the rest
##    30–89 apart ([method next]). Each at 80–99 of 100 and panned anywhere
##    from half left to half right (1997's −50…+49, `PlaySoundWithPitchAndPan`
##    — its random number the volume, not the pitch, adventure_sound.c 41).
##    The count goes on through events and duels, so a sound may come at
##    once after one, as 1997's did (the board's loop asked only when it ran).
##  - THE EVENTS' ONE-SHOTS at full voice, centred, on the world's one
##    effect voice ([method play] → [method WorldSoundscape.play_from]: a
##    new one cuts the last, as 1997's one effect channel): the dice, the
##    scroll, a card found, gold found, the creature's summons, the duel's
##    call, the booted words.
## [ours, as the world's soundscape: the ambience draws on this node's own
## dice ([member rng]), never on the board's or the adventure's — 1997 drew
## it on the game's `internal_rand`, so listening changed what the dungeon
## gave; here the board's dice and the adventure's are the same whether the
## sounds play or not.] Silent with no sound device (the tests), the
## scheduler running all the same ([member played] says what it chose).

## The bed and the five ambient sounds' skin keys.
const BED := "sfx_dungeon_loop"
const AMBIENCE := "sfx_dungeon_ambience_%d"
const SOUNDS := 5
## The drip: the one sound that comes in bursts.
const BURSTING := 5
## 1997's volumes (of 100): the bed's; an ambient sound's least and most.
const BED_VOLUME := 80
const VOLUME := Vector2i(80, 99)
## 1997's pan, of the stereo field.
const PAN := Vector2i(-50, 49)
## A UI tick (`timeSetEvent(0x21)`, shandalar.c 77): the waits' unit.
const TICK := 0.033
## The waits, in ticks: the first; the next after an ordinary sound; the
## first of a burst; each repeat of it. The repeats a burst brings.
const FIRST_WAIT := Vector2i(90, 179)
const NEXT_WAIT := Vector2i(120, 209)
const BURST_WAIT := Vector2i(60, 89)
const REPEAT_WAIT := Vector2i(30, 89)
const REPEATS := Vector2i(2, 4)

## The ambience's own dice ([ours], see the class's notes); seeded from the
## clock unless a test sets it.
var rng := RandomNumberGenerator.new()
## The scheduler's state: `{last, repeats, wait}` — the sound last played
## (1–5; 1 as the board begins, so the first pick is never Damb1), the
## burst's repeats left, the ticks to wait from the last sound.
var state := {"last": 1, "repeats": 0, "wait": 0}
## What the ambience chose, in order: `{sound, volume, pan}` (tests).
var played: Array[Dictionary] = []
## Whether the bed and the ambience run, and whether a duel holds them.
var running := false
var paused := false
## The ticks counted since the last ambient sound.
var ticks := 0.0
var _bed: AudioStreamPlayer
var _voice: AudioStreamPlayer2D
var _quiet := false


func _ready() -> void:
	name = "DungeonSound"
	_quiet = DisplayServer.get_name() == "headless"
	GameAudio.ensure_buses()
	_bed = AudioStreamPlayer.new()
	_bed.name = "Bed"
	_bed.bus = GameAudio.SFX_BUS
	_bed.volume_db = WorldSoundscape.db(BED_VOLUME)
	add_child(_bed)
	_voice = AudioStreamPlayer2D.new()
	_voice.name = "Ambience"
	_voice.bus = GameAudio.SFX_BUS
	_voice.attenuation = 0.0
	_voice.max_distance = 100000.0
	add_child(_voice)


## THE BOARD BEGINS: the bed, and the ambience's first wait (1997's state
## reset: Damb1 the last, no repeats).
func start() -> void:
	state = {"last": 1, "repeats": 0, "wait": rng.randi_range(FIRST_WAIT.x, FIRST_WAIT.y)}
	ticks = 0.0
	running = true
	paused = false
	_play_bed()


## THE BOARD LEFT: everything quiet, for good.
func stop() -> void:
	running = false
	paused = false
	if _bed != null:
		_bed.stop()
	if _voice != null:
		_voice.stop()


## A DUEL OVER THE WORLD (or a pane with its own tune): the bed and the
## ambience stopped; the ticks go on being counted.
func pause_for_duel() -> void:
	paused = true
	if _bed != null:
		_bed.stop()
	if _voice != null:
		_voice.stop()


## BACK ON THE BOARD after a duel: the bed again; a sound overdue comes at
## once.
func resume() -> void:
	if not running:
		return
	paused = false
	_play_bed()


## A ONE-SHOT for an event, by its skin key, on the world's effect voice.
func play(key: String) -> void:
	WorldSoundscape.play_from(self, key)


## Whether the bed is playing (false headless).
func bed_playing() -> bool:
	return _bed != null and _bed.playing


func _process(delta: float) -> void:
	if not running:
		return
	ticks += delta / TICK
	if paused:
		return
	advance()


## The ambience's clock read: a sound when its wait is over (no more than
## one a call).
func advance() -> void:
	if not running or paused or ticks < float(int(state["wait"])):
		return
	ticks = 0.0
	state = next(rng, state)
	var chosen := {"sound": int(state["play"]), "volume": int(state["volume"]), "pan": int(state["pan"])}
	played.append(chosen)
	_sound(chosen)


## THE NEXT AMBIENT SOUND after [param before] (`{last, repeats}`), on
## [param dice] (dE:416–447; the class's notes): the state after it, with
## `play` the sound (1–5), `volume` (80–99), `pan` (−50…+49) and `wait` the
## ticks to the next. Pure: the tests read it.
static func next(dice: RandomNumberGenerator, before: Dictionary) -> Dictionary:
	var out := before.duplicate()
	var last := int(before.get("last", 1))
	var sound := BURSTING
	if last == BURSTING and int(before.get("repeats", 0)) > 0:
		out["repeats"] = int(before["repeats"]) - 1
		out["wait"] = dice.randi_range(REPEAT_WAIT.x, REPEAT_WAIT.y)
	else:
		# Any of the five but the last one.
		sound = dice.randi_range(1, SOUNDS - 1)
		if sound >= last:
			sound += 1
		if sound == BURSTING:
			out["repeats"] = dice.randi_range(REPEATS.x, REPEATS.y)
			out["wait"] = dice.randi_range(BURST_WAIT.x, BURST_WAIT.y)
		else:
			out["repeats"] = 0
			out["wait"] = dice.randi_range(NEXT_WAIT.x, NEXT_WAIT.y)
	out["last"] = sound
	out["play"] = sound
	out["volume"] = dice.randi_range(VOLUME.x, VOLUME.y)
	out["pan"] = dice.randi_range(PAN.x, PAN.y)
	return out


## THE BED as a seamless loop: the sample's own loop points over all of it
## (a copy: the skin's cached stream is left as it is). Null without it.
static func looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	var loop := wav.duplicate() as AudioStreamWAV
	var per := (2 if wav.stereo else 1) * (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = wav.data.size() / per
	return loop


func _play_bed() -> void:
	if _quiet or _bed == null or not is_inside_tree():
		return
	if _bed.stream == null:
		var stream := GameSkin.sound(BED)
		if stream == null:
			return
		_bed.stream = looped(stream)
	if not _bed.playing:
		_bed.play()


func _sound(chosen: Dictionary) -> void:
	if _quiet or _voice == null or not is_inside_tree():
		return
	var stream := GameSkin.sound(AMBIENCE % int(chosen["sound"]))
	if stream == null:
		return
	var screen := get_viewport().get_visible_rect().size
	_voice.stop()
	_voice.stream = stream
	_voice.position = Vector2(screen.x / 2.0 + int(chosen["pan"]) / 100.0 * screen.x / 2.0, screen.y / 2.0)
	_voice.volume_db = WorldSoundscape.db(int(chosen["volume"]))
	_voice.pitch_scale = 1.0
	_voice.play()
