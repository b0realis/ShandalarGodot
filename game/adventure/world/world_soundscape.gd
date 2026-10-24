class_name WorldSoundscape
extends Node
## THE WORLD'S SOUNDS (the owner, 2026-10-23: *"Soundscape + title
## music"*) — what 1.3 played on the world screen (`adventure_input.c`
## 600–850, `adventure_sound.c`), in the player's own 1997 sounds (the skin;
## `tools/import_original.py`), with the title's tune kept softly beneath:
##
##  - A PLACE'S TUNE. Every other step of the walk the nearest place is
##    found (1997's distance, from its tile's middle, in world units) and
##    its tune plays at `clamp(128 − d, 0, 100)` — 0.4 dB a step, 0 dB at
##    100 — when that is above 10: a village LocMus0; a town, a city or a
##    beaten castle the tune of its slot (`slot % 20`: LocMus1–19, the
##    twentieth Tmplmus1); a wizard's castle its colour's. A new place
##    starts its tune from the top; out of hearing it stops. Entering a
##    town brings it to full voice.
##  - FOOTSTEPS. Each step of the walk, the colour of the land ahead (one of
##    its colours, at random) — black, blue, green, red or white feet, left
##    and right in turn — at 75–99 and 80–119% pitch. The sea and the
##    colourless are silent.
##  - CALLS. One step in forty, walking or standing, a bird's or the land's
##    call of that colour, anywhere from left to right at 70–119% pitch;
##    one call in three the colour's next call is taken for the next time.
##  - CLICKS AND STINGS. The panel's buttons click; a World Magic's icon
##    clicked plays its colour's sting; a town's choice clicks; a mana link
##    made, a reward, a treasure have theirs ([method play]).
##  - THE TITLE'S TUNE stays under the world, [constant BED_DB] lower, and
##    gives way [constant DUCK_DB] more as a place's tune rises.
##  - A CREATURE'S CRY (`PlayCreatureEncounterSound`, world_lair_monster_
##    slots.c 281–325, 960–967): a creature that stepped this tick, within
##    80 of the hero, cries one time in `d0 / 4` ([method cry]) — its kind's
##    sound (male and female wizards, knight, lord, djinn, troll, wyrm,
##    dragon, flyer, archmage; the henchmen are silent), at `104 − d0 / 2`
##    (of 100) and `100 − d0 / 3` percent of its pitch, on one voice: a new
##    cry cuts the last, as 1997's one channel did. [Ours: 1997 slips — the
##    flyer's cry plays `Flying.wav` (1997 asked for `flyer.wav`, which no
##    install has: flyers were silent, [method CreatureBook.cry_key]); a cry
##    sounds from where the creature stands on the screen (1997 panned it by
##    its heading); and the chance is drawn on the soundscape's own dice.]
## [Ours: the sounds draw their own dice, so a sound never changes what the
## world's dice give; a call is let ring (1997 cut one in three as it
## changed the sample, and on colourless land played the white right
## footstep as a call).] Silent with no sound device (the tests).

## How far the title's tune sits under the world, and how much more it
## gives way to a place's tune at full voice (ours, to the ear).
const BED_DB := -12.0
const DUCK_DB := 12.0
## A place's tune is heard above this (of 100).
const HEARD := 10
## The calls each colour has, black … white, the first its bird.
const CALLS: Array[Array] = [["bird", "land_1", "land_2"], ["bird", "land_1", "land_2"],
	["bird", "land_1"], ["bird", "land_1"], ["bird", "land_1"]]
const COLOR_WORDS: Array[String] = ["black", "blue", "green", "red", "white"]

var player: AdventurePlayer
## The place whose tune plays, −1 for none, and how loud (of 100).
var site := -1
var level := 0
var rng := RandomNumberGenerator.new()
var _quiet := false
var _tune: MusicPlayer
var _steps: AudioStreamPlayer
var _one_shot: AudioStreamPlayer
var _calls: Array[AudioStreamPlayer2D] = []
## The creatures' one voice ([method cry]).
var _cry: AudioStreamPlayer2D
## Each colour's call for next time (an index into [constant CALLS]).
var _next_call: Array[int] = [0, 0, 0, 0, 0]


func _ready() -> void:
	name = "Soundscape"
	add_to_group("world_soundscape")
	rng.randomize()
	_quiet = DisplayServer.get_name() == "headless"
	GameAudio.ensure_buses()
	_tune = MusicPlayer.new()
	_tune.name = "PlaceTune"
	add_child(_tune)
	_steps = AudioStreamPlayer.new()
	_steps.name = "Steps"
	_steps.bus = GameAudio.SFX_BUS
	var many := AudioStreamPolyphonic.new()
	many.polyphony = 16
	_steps.stream = many
	add_child(_steps)
	_one_shot = AudioStreamPlayer.new()
	_one_shot.name = "OneShot"
	_one_shot.bus = GameAudio.SFX_BUS
	add_child(_one_shot)
	for i in 4:
		var call := AudioStreamPlayer2D.new()
		call.bus = GameAudio.SFX_BUS
		call.attenuation = 0.0
		call.max_distance = 100000.0
		add_child(call)
		_calls.append(call)
	_cry = AudioStreamPlayer2D.new()
	_cry.name = "Cry"
	_cry.bus = GameAudio.SFX_BUS
	_cry.attenuation = 0.0
	_cry.max_distance = 100000.0
	add_child(_cry)
	_bed(BED_DB)


func _exit_tree() -> void:
	_bed(0.0)


# ------------------------------------------------------------ the rules --

## 1997's volume (0–100) in decibels: `0.4 · v − 40`.
static func db(volume: float) -> float:
	return 0.4 * clampf(volume, 0.0, 100.0) - 40.0


## The footstep's key: colour [param color] (1 black … 5 white), the left
## foot on even steps.
static func step_key(color: int, step: int) -> String:
	return "sfx_step_%s_%s" % [COLOR_WORDS[clampi(color, 1, 5) - 1], "left" if step % 2 == 0 else "right"]


## A call's key: colour [param color], its call [param index].
static func call_key(color: int, index: int) -> String:
	var calls: Array = CALLS[clampi(color, 1, 5) - 1]
	return "sfx_call_%s_%s" % [COLOR_WORDS[clampi(color, 1, 5) - 1], calls[clampi(index, 0, calls.size() - 1)]]


## THE TUNE OF SITE [param slot]: a village's, a town's or city's by its
## slot, a castle's by its colour; "" for none.
static func tune_key(world: ShandalarWorld, slot: int) -> String:
	if world == null or slot < 0 or slot >= world.sites.size():
		return ""
	var kind := int(world.sites[slot]["type"])
	if kind == ShandalarWorld.VILLAGE:
		return "music_location_0"
	if kind == ShandalarWorld.CASTLE:
		var castle := WorldNames.castle_of_site(world, slot)
		return "music_castle_" + COLOR_WORDS[castle] if castle >= 0 else ""
	if kind < ShandalarWorld.VILLAGE:
		return ""
	var k := slot % 20
	return "music_temple" if k == 19 else "music_location_%d" % (k + 1)


## THE NEAREST PLACE TO [param point] (world units) and how loud its tune
## is there: `{slot, key, percent}` — percent `clamp(128 − d, 0, 100)`.
static func nearest(world: ShandalarWorld, point: Vector2i) -> Dictionary:
	var best := -1
	var best_distance := 0x7FFF
	for slot in world.sites.size():
		var site_entry: Dictionary = world.sites[slot]
		if int(site_entry["type"]) <= 0:
			continue
		var d := WorldGenerator.distance(int(site_entry["x"]) * 32 + 16 - point.x,
			int(site_entry["y"]) * 32 + 16 - point.y)
		if d < best_distance:
			best_distance = d
			best = slot
	if best < 0:
		return {"slot": -1, "key": "", "percent": 0}
	return {"slot": best, "key": tune_key(world, best), "percent": clampi(128 - best_distance, 0, 100)}


# ------------------------------------------------------------- the walk --

## A TICK OF THE WORLD'S CLOCK ([param walk] just stepped it, the clock not
## yet moved on): a footstep, a call, the place's tune, as 1997 played them
## on a step of its walk.
func tick(walk: HeroWalk) -> void:
	if player == null or walk == null or not walk.stepped:
		return
	var world := player.world
	var d := walk.heading
	var ahead := player.position + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
	var color := _color_at(world, ahead / 32)
	if d != 0 and color > 0:
		_play_voice(_steps, step_key(color, player.step), db(75 + rng.randi_range(0, 24)),
			(80 + rng.randi_range(0, 39)) / 100.0)
	if rng.randi_range(0, 39) == 0 and color > 0:
		_call(color)
	if player.monster_timer % 2 == 0:
		hear_places()


## One of the colours of the land at [param tile], at random (1 black …
## 5 white), 0 for the sea or the colourless.
func _color_at(world: ShandalarWorld, tile: Vector2i) -> int:
	var mask := ShandalarWorld.magic_mask(world.terrain(tile.x, tile.y)) & 0x3E
	if mask == 0:
		return 0
	while true:
		var color := rng.randi_range(1, 5)
		if mask & (1 << color) != 0:
			return color
	return 0


## A colour's call, somewhere from left to right; the next call drawn one
## time in three.
func _call(color: int) -> void:
	var pan := rng.randi_range(-100, 99)
	var pitch := (70 + rng.randi_range(0, 49)) / 100.0
	var key := call_key(color, _next_call[color - 1])
	if rng.randi_range(0, 2) == 0:
		_next_call[color - 1] = rng.randi_range(0, (CALLS[color - 1] as Array).size() - 1)
	if _quiet:
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
	var voice: AudioStreamPlayer2D = null
	for one in _calls:
		if not one.playing:
			voice = one
			break
	if voice == null:
		voice = _calls[0]
	var screen := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 800)
	voice.position = Vector2(screen.x / 2.0 + pan / 100.0 * screen.x / 2.0, screen.y / 2.0)
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = 0.0
	voice.play()


## A CREATURE'S CRY, maybe: creature row [param row], [param distance]
## (1997's `d0`) from the hero, standing at [param at] on the screen. It
## cries when this soundscape's dice (never the world's) give under 4 of
## `distance` — always within 4 —; true when it did (silent without a
## sound device, or for a kind with no voice, all the same).
func cry(row: int, distance: int, at: Vector2) -> bool:
	if distance > 1 and rng.randi_range(0, distance - 1) >= 4:
		return false
	var key := CreatureBook.cry_key(row)
	if key == "":
		return false
	if _quiet or _cry == null:
		return true
	var stream := GameSkin.sound(key)
	if stream == null:
		return true
	_cry.stop()
	_cry.stream = stream
	_cry.position = at
	_cry.volume_db = db(104 - distance / 2)
	_cry.pitch_scale = maxf(0.05, (100 - distance / 3) / 100.0)
	_cry.play()
	return true


## THE PLACE'S TUNE as the hero now stands: started, carried on louder or
## softer, or stopped; the title's tune giving way beneath it.
func hear_places() -> void:
	var near := nearest(player.world, player.position)
	var percent := int(near["percent"])
	var key := String(near["key"])
	if percent <= HEARD or key == "":
		_stop_tune()
		return
	if int(near["slot"]) != site:
		site = int(near["slot"])
		if not _quiet:
			_tune.stop_music()
			_tune.play_one(key)
	_set_level(percent)


## A screen with its own music over the world (the deck builder), or a
## lair entered (1997's `StopWorldLocationMusic` before the lair's event):
## the place's tune rests while it is up ([param resting]), and is heard
## again from where the hero stands once it is gone.
func rest(resting: bool) -> void:
	if resting:
		_stop_tune()
	elif player != null:
		hear_places()


## A town entered: its tune at full voice.
func swell() -> void:
	if site >= 0:
		_set_level(100)


func _set_level(percent: int) -> void:
	level = percent
	_tune.volume_db = db(percent)
	_bed(BED_DB - DUCK_DB * clampf((percent - HEARD) / float(100 - HEARD), 0.0, 1.0))


func _stop_tune() -> void:
	if site >= 0 or level > 0:
		_tune.stop_music()
	site = -1
	level = 0
	_bed(BED_DB)


## The title's tune at [param level_db] under the world.
func _bed(level_db: float) -> void:
	var music := get_node_or_null(^"/root/ShellMusic")
	if music == null or not music.has_method("player"):
		return
	var bed: MusicPlayer = music.call("player")
	if bed != null:
		bed.volume_db = level_db


# ------------------------------------------------------------ one-shots --

## A ONE-SHOT by its skin key — a click, a sting, a treasure: a new one
## cuts the last, as 1997's one effect channel did.
func play(key: String) -> void:
	if _quiet or key == "":
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
	_one_shot.stop()
	_one_shot.stream = stream
	_one_shot.pitch_scale = 1.0
	_one_shot.volume_db = 0.0
	_one_shot.play()


## A one-shot from anywhere under the world screen ([param node] any node
## in the tree), when the world has a soundscape.
static func play_from(node: Node, key: String) -> void:
	if node == null or not node.is_inside_tree():
		return
	var soundscape := node.get_tree().get_first_node_in_group("world_soundscape")
	if soundscape != null:
		soundscape.call("play", key)


## The sound of a card found (1997's card-type sounds): a creature summoned,
## an artifact, an enchantment, an instant, an interrupt or a sorcery cast,
## a land of its colours.
static func card_key(card_name: String) -> String:
	if not CardRegistry.has_card(card_name):
		return "sfx_treasure"
	var f := CardValue.facts(CardRegistry.get_card(card_name))
	var kind := int(f.get("type", 0))
	if kind & CardValue.CREATURE != 0:
		return "sfx_summon"
	if kind & CardValue.ARTIFACT != 0:
		return "sfx_cast_artifact"
	if kind & CardValue.ENCHANTMENT != 0:
		return "sfx_cast_enchantment"
	if kind & CardValue.INSTANT != 0:
		return "sfx_cast_instant"
	if kind & CardValue.INTERRUPT != 0:
		return "sfx_cast_interrupt"
	if kind & CardValue.SORCERY != 0:
		return "sfx_cast_sorcery"
	var color := CardValue.first_color(int(f.get("color", 1)))
	var at := CardShop.COLOR_BITS.find(color)
	return "sfx_land_" + (COLOR_WORDS[at] if at >= 0 else "grey")


func _play_voice(player_node: AudioStreamPlayer, key: String, volume_db: float, pitch: float) -> void:
	if _quiet:
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return
	if not player_node.playing:
		player_node.play()
	var playback := player_node.get_stream_playback() as AudioStreamPlaybackPolyphonic
	if playback != null:
		playback.play_stream(stream, 0.0, volume_db, pitch)
