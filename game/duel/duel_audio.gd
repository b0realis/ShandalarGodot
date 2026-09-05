class_name DuelAudio
extends Node
## THE DUEL'S SOUND — the 1997 cue vocabulary, a polyphonic voice pool and
## the one tune the original played over a duel. `docs/duel-todo.md` §3.8.
##
## Lived inside `duel_screen.gd` until 2026-09-02. It is a file of its own
## now for three reasons: the cue map is a pure function of a game event
## and deserves to be tested without building a screen; the voice pool is
## a mechanism with its own rules; and a duel is not the only thing in
## this game that will make a noise.
##
## ------------------------------------------------------------------------
## THE ORIGINAL'S OWN SOUND TABLE
## ------------------------------------------------------------------------
## `shandalar-src/src/defs.h:2179` is the 1997 enum, headed *"Constants for
## play_sound_effect(). Named identically to their filenames in
## DuelSounds/"*, and the call sites in `src/functions/` say what each one
## is FOR. Three rules come out of it:
##
##  1. **A SPELL SOUNDS LIKE ITS CARD TYPE**, not like its colour —
##     `engine.c:1784-1802` fires WAV_SUMMON / WAV_ARTIFACT / WAV_ENCHANT /
##     WAV_INSTANT / WAV_INTERUPT / WAV_SORCERY off the type mask, one `if`
##     per bit (so a Serra Angel artifact-creature would sound twice).
##  2. **A LAND SOUNDS LIKE THE COLOURS IT MAKES** —
##     `play_land_sound_effect` (`functions.c:14382-14453`), called from
##     `mana_producer`'s EVENT_RESOLVE_SPELL (`produce_mana.c:57`).
##  3. **DAMAGE TO A PLAYER IS NOT THE DAMAGE SOUND.** `damage_effects.c`
##     branches on the target: `:524` *"// Damaging a player."* plays
##     WAV_LIFELOSS, `:705` plays WAV_DAMAGE for a card. `lose_life`
##     (`functions.c:9871`) plays WAV_LIFELOSS too, for life lost without
##     damage. We played `Damage.wav` for both until 2026-09-02, and
##     `LifeLoss.wav` sat imported and unused.
##
## WHAT RULE 1 REPLACED, so nobody puts it back: we played a per-COLOUR
## sound on every SPELL_CAST, taking White/Blue/Black/Red/Green.wav for it.
## The enum groups those five files under a literal `// Land sounds.`
## comment — they are the land table, and using them for spells meant a
## Mountain and a Lightning Bolt made the same noise.
##
## TWO OF s30's THREE NAMED CUES TURN OUT NOT TO BE 1997 CUES AT ALL:
##  - "counter (the stack shrank by >= 2)" wants Counter.wav, but the enum
##    annotates that entry itself — `WAV_COUNTER = 37, // "a counter has
##    been added to a card", not "a spell has been countered"` — and the
##    only call site is `counters.c:2085`. The original's countering sound
##    is WAV_INTERUPT, because in 1997 Counterspell WAS an Interrupt; rule
##    1 therefore covers it, via [method cast_sound_key].
##  - "mana-ball (either pool grew)" wants ManaBall.wav, which is not in
##    the 1997 duel enum at all. Mana appearing already has a cue there and
##    we already play it: WAV_TAP, on TAPPED_FOR_MANA.
##
## ------------------------------------------------------------------------
## WHEN A CUE FIRES, WHICH IS THE HALF THAT IS EASY TO GET WRONG
## ------------------------------------------------------------------------
## A cue at the wrong instant is worse than no cue. Three timings were
## corrected on 2026-09-02, each against the original's own call site:
##
##  * **The type cue moved from the cast to the ARRIVAL.** `engine.c:1786`
##    sits inside the RESOLUTION path — the block that sets
##    `STATE_IN_PLAY` and then calls `resolve_top_card_on_stack()`. We fired
##    it on SPELL_CAST *and* played `sfx_summon` again on
##    ENTERS_BATTLEFIELD, so every creature announced itself twice: once as
##    it left your hand and once as it landed. Now a PERMANENT is announced
##    where the original announces it and where §2.4's spell flight
##    delivers it — on ENTERS_BATTLEFIELD, which is also what a token or a
##    reanimation gets (the enum: `WAV_SUMMON = 17, // Also
##    WAV_CREATURE_TOKEN`).
##  * **An instant or a sorcery keeps its cue at the CAST**, and that is a
##    labelled divergence rather than an oversight. It never enters the
##    battlefield, so it has no arrival to sound at, and our engine
##    dispatches no "spell resolved" event to hang one on — inventing one
##    would be an `engine/` change for a presentation problem. The cast is
##    the moment the card leaves the hand and flies to the Spell Chain,
##    which is the only moment the player can see.
##  * **One voice per cue per frame.** Combat damage arrives as one
##    DAMAGE_DEALT per creature, the opening deal as fourteen CARD_DRAWN,
##    the untap step as one BECAME_UNTAPPED per permanent. Five copies of
##    one sample started on the same frame are not five hits — they are one
##    hit five times as loud, phase-locked. So a cue is allowed one voice
##    per frame and different cues layer freely, which is the same
##    behaviour the original's slot mixer had (see [GameAudio]).
##
## ------------------------------------------------------------------------
## STILL UNPLAYED, catalogued rather than forgotten
## ------------------------------------------------------------------------
## `Destroy.wav` (which `deck.c:1158` records is *"the rfg sound effect,
## despite its name"*), `Kill.wav`, `Regen.wav`, `Sacrfice.wav`,
## `ManaBurn.wav`, `Control.wav`, `ChangeC/ChangeT.wav`, `EndPhase.wav`,
## `FastFX.wav`, `Counter.wav`. Every one of them needs an engine event we
## do not dispatch. `LifeGain.wav` is **not** a 1997 sound at all —
## `Duelsounds/sounds.txt` credits it as a Manalink addition, and
## `WAV_LIFEGAIN = 79` sits above `WAV_HIGHEST_EXE = 68` in the enum.
##
## ------------------------------------------------------------------------
## NO ASSETS, NO ERRORS
## ------------------------------------------------------------------------
## `GameSkin.sound` returns null for anything the player has not imported,
## and every path here treats null as SILENCE. A player without the 1997
## game gets a duel that plays correctly and simply makes fewer sounds.
## A headless run allocates no player and loads no sample.

## How many effects may sound at once. The original addressed its mixer by
## slot and the deck builder held five at a time
## (`deckdll.cpp:2048-2056`); a duel has more kinds of moment than a deck
## surface, and eight covers the busiest one we can construct — a combat
## step in which damage lands, a creature dies, a life total drops and the
## turn ends.
const VOICES := 8

## How many cue names [member recent] keeps. Tests read it; nothing else
## does. Bounded so a long duel cannot grow it without limit.
const RECENT_MAX := 32

## The cue names this object has decided to play, newest last — the seam
## the cue tests act through, so they never need an audio device.
var recent: Array[String] = []

## When false, [method play] really loads and plays. Set true in
## [method _ready] for a headless run: no [AudioStreamPlayer] is created,
## no sample is read off disk, and no audio device is ever asked for.
## Tests flip it back to exercise the pool under the dummy driver.
var silent := false

var _voices: Array[AudioStreamPlayer] = []
## cue key -> the process frame it last started on (the per-frame coalesce).
var _last_frame: Dictionary = {}
var _music: MusicPlayer = null


func _ready() -> void:
	GameAudio.apply_settings()
	silent = DisplayServer.get_name() == "headless"


# ------------------------------------------------------------- the pool --

## Play one cue. A key of `""` is "no sound for this" and is the normal
## answer for several events; a key with no imported sample behind it is
## silence, not an error.
func play(key: String) -> void:
	if key == "":
		return
	# ONE VOICE PER CUE PER FRAME (see the class doc). `Engine`'s frame
	# counter, not a wall clock: it advances in a headless run too, so the
	# rule under test is the rule that ships.
	var frame := Engine.get_process_frames()
	if int(_last_frame.get(key, -1)) == frame:
		return
	_last_frame[key] = frame
	recent.append(key)
	if recent.size() > RECENT_MAX:
		recent = recent.slice(recent.size() - RECENT_MAX)
	if silent:
		return
	var stream := GameSkin.sound(key)
	if stream == null:
		return          # the player has no 1997 sounds; that is fine
	var voice := _free_voice()
	voice.stream = stream
	voice.play()


## Where the round-robin steal will take its next victim from.
var _next_steal := 0


## A voice that is not sounding, or the LEAST RECENTLY STOLEN one if all
## are busy. Grown lazily, so a screen that never makes a noise never
## allocates an [AudioStreamPlayer] at all.
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
	# All eight busy. Something has to give, and round-robin gives up the
	# one that has been sounding longest rather than always the same slot.
	_next_steal = (_next_steal + 1) % _voices.size()
	return _voices[_next_steal]


# ------------------------------------------------------------ the music --

## Start the duel's tune, looping — see [MusicPlayer], which owns the
## loop-patching every screen with music needs. Allocated on first use, so
## a headless duel never creates one.
func play_music(key: String) -> void:
	if key == "" or silent:
		return
	if _music == null:
		_music = MusicPlayer.new()
		add_child(_music)
	_music.play_key(key)


func stop_music() -> void:
	if _music != null:
		_music.stop_music()


# ------------------------------------------------------- the event map --

## The two card types that never reach the battlefield, and so the only
## spells whose cue stays on the CAST (see the class doc).
const NON_PERMANENT_TYPES := Mtg.CardType.INSTANT | Mtg.CardType.SORCERY


## Engine event -> the original's sound vocabulary. Pure: it reads the
## event and nothing else, so every cue in this game can be pinned without
## a board, a display or an audio device.
##
## Returns `""` for an event the 1997 game had no sound for, which is most
## of them.
static func cue_for(event: GameEvent) -> String:
	match event.type:
		Mtg.EventType.SPELL_CAST:
			# ONLY the spells that never arrive anywhere — see the class
			# doc. A permanent is announced on ENTERS_BATTLEFIELD instead,
			# which is where `engine.c:1786` announces it.
			var inst: CardInstance = event.data["instance"]
			if not (inst.data.types & NON_PERMANENT_TYPES):
				return ""
			return cast_sound_key(inst)
		Mtg.EventType.ENTERS_BATTLEFIELD:
			# The original's resolution cue (`engine.c:1786-1801`), and the
			# moment §2.4's flight puts the card down. A land has its own
			# table and answers on LAND_PLAYED.
			var inst: CardInstance = event.data["instance"]
			if inst.is_land():
				return ""
			return cast_sound_key(inst)
		Mtg.EventType.LAND_PLAYED:
			# The original plays it when the land RESOLVES; a land never
			# uses the stack in our engine (CR 305.1), so this is the same
			# moment.
			return land_sound_key(event.data["instance"])
		Mtg.EventType.CARD_DRAWN:
			return "sfx_draw"              # WAV_DRAW, deck.c:728
		Mtg.EventType.TAPPED_FOR_MANA:
			return "sfx_tap"               # WAV_TAP, engine.c:1204
		Mtg.EventType.ABILITY_ACTIVATED:
			# THE OTHER HALF OF WAV_TAP. The original plays it from all
			# three of its tap-to-pay paths — charging mana
			# (`engine.c:1204`, `:1403`) and playing an ability
			# (`engine.c:1917`, which dispatches EVENT_TAPPED_TO_PLAY_ABILITY
			# beside it). We had only the mana half, so a Prodigal Sorcerer
			# pinging was silent until its damage landed.
			return "sfx_tap" if bool(event.data.get("taps", false)) else ""
		Mtg.EventType.BECAME_UNTAPPED:
			# A PHASE MAKES NO NOISE BY ITSELF (the owner, 2026-09-03).
			# This fired once per permanent during the UNTAP STEP: nobody
			# did anything, so it was the clock sounding. WAV_UNTAP = 19
			# has no call site in any source we hold, so nothing sourced
			# is lost. The cost is the rare effect-driven untap (Candelabra,
			# Tawnos's Coffin), which IS an action — the event carries no
			# cause, so the two cannot be told apart here.
			return ""
		Mtg.EventType.DECLARED_ATTACKERS:
			return "sfx_attack"            # WAV_ATTACK2
		Mtg.EventType.BLOCKERS_DECLARED:
			# WAV_BLOCK2 (engine.c:1539, ai.c:398). BLOCKERS_DECLARED, not
			# BLOCKED: the latter fires once per attacker/blocker PAIR.
			return "sfx_block"
		Mtg.EventType.DAMAGE_DEALT:
			# Rule 3 — the target decides the file. `damage_effects.c:524`
			# *"// Damaging a player."* -> WAV_LIFELOSS; `:705` -> WAV_DAMAGE.
			if event.data.has("to_player"):
				return "sfx_life_loss"
			return "sfx_damage"
		Mtg.EventType.DIES:
			return "sfx_buried"            # WAV_BURIED
	return ""


## Play whatever [method cue_for] decides this event is worth.
func on_event(event: GameEvent) -> void:
	play(cue_for(event))


## Which sound a spell makes, by CARD TYPE (`engine.c:1784-1802`).
##
## The original tests one type bit at a time and plays every match, in the
## order creature, artifact, enchantment, instant, interrupt, sorcery. We
## play the FIRST match instead: an artifact creature is a Summon there and
## then an Artifact, two samples inside one frame, which is a click rather
## than a chord.
##
## INTERRUPT is a 1997 card type that the modern oracle folded into
## Instant, so no CardData carries it. The original's own interrupts are
## the counter-spells (Counterspell, Power Sink, Spell Blast, the Elemental
## Blasts), so a spell that COUNTERS gets Interupt.wav and every other
## instant gets Instant.wav — the same two files landing in the same two
## places, keyed off what the card DOES rather than off a type we do not
## model.
static func cast_sound_key(inst: CardInstance) -> String:
	var types: int = inst.data.types
	if types & Mtg.CardType.CREATURE:
		return "sfx_summon"
	if types & Mtg.CardType.ARTIFACT:
		return "sfx_cast_artifact"
	if types & Mtg.CardType.ENCHANTMENT:
		return "sfx_cast_enchantment"
	if types & Mtg.CardType.SORCERY:
		return "sfx_cast_sorcery"
	if types & Mtg.CardType.INSTANT:
		for e in inst.data.spell_effects:
			if e is CounterEffect:
				return "sfx_cast_interrupt"
		return "sfx_cast_instant"
	return "sfx_cast_artifact"


## The dual-land files, keyed by the pair of colours the land makes. The
## original names five ALLIED pairs and five ENEMY ones and aliases the
## reversals onto them (`defs.h:2255-2265`: WAV_REDBLACK = WAV_BLACKRED
## and so on), so one entry per unordered pair is the whole table.
const LAND_PAIR_SOUNDS := {
	Mtg.ManaColor.W | Mtg.ManaColor.U: "sfx_land_white_blue",
	Mtg.ManaColor.U | Mtg.ManaColor.B: "sfx_land_blue_black",
	Mtg.ManaColor.B | Mtg.ManaColor.R: "sfx_land_black_red",
	Mtg.ManaColor.R | Mtg.ManaColor.G: "sfx_land_red_green",
	Mtg.ManaColor.G | Mtg.ManaColor.W: "sfx_land_green_white",
	Mtg.ManaColor.W | Mtg.ManaColor.B: "sfx_land_white_black",
	Mtg.ManaColor.B | Mtg.ManaColor.G: "sfx_land_black_green",
	Mtg.ManaColor.G | Mtg.ManaColor.U: "sfx_land_green_blue",
	Mtg.ManaColor.U | Mtg.ManaColor.R: "sfx_land_blue_red",
	Mtg.ManaColor.R | Mtg.ManaColor.W: "sfx_land_red_white",
}

## The five single-colour land files.
const LAND_SOLO_SOUNDS := {
	Mtg.ManaColor.W: "sfx_land_white", Mtg.ManaColor.U: "sfx_land_blue",
	Mtg.ManaColor.B: "sfx_land_black", Mtg.ManaColor.R: "sfx_land_red",
	Mtg.ManaColor.G: "sfx_land_green",
}


## Which sound a LAND makes: the original picks it from the colours the
## land PRODUCES, not from the card's own colour (a land is colourless).
## `play_land_sound_effect_force_color` (`functions.c:14387-14453`):
##
##     colors &= COLOR_TEST_ANY_COLORED;   // colourless/artifact fold in
##     case 0:                     wav1 = WAV_GREY;
##     case COLOR_TEST_BLACK:      wav1 = WAV_BLACK;   ... etc
##     case WHITE|BLUE:            wav1 = WAV_WHITEBLUE; ... the ten pairs
##     case COLOR_TEST_ANY_COLORED: wav1 = WAV_GEMBAZAR;
##
## Returning `""` means SILENCE, which is the 1997 answer for a five-colour
## land: the Manalink comment at :14446 picks GemBazar for itself while
## noting *"even though City of Brass is silent"*, and the 1997 game is the
## authority here. Three- and four-colour lands do not exist in this pool
## (that half of the original's table is Manalink's, for Reflecting Pool
## and friends), so they fall through to silence as well.
static func land_sound_key(inst: CardInstance) -> String:
	var mask := 0
	for ability in inst.cur_mana_abilities:
		for pair in ability.produces:
			var color: int = pair[0]
			if color != Mtg.ManaColor.C:
				mask |= color
	if mask == 0:
		return "sfx_land_grey"
	if LAND_SOLO_SOUNDS.has(mask):
		return LAND_SOLO_SOUNDS[mask]
	if LAND_PAIR_SOUNDS.has(mask):
		return LAND_PAIR_SOUNDS[mask]
	return ""
