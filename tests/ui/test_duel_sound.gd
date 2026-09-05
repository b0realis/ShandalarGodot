extends GutTest
## THE ORIGINAL'S SOUND TABLE — `docs/duel-todo.md` §3.8.
##
## `shandalar-src/src/defs.h:2179` is the 1997 enum, headed *"Constants for
## play_sound_effect(). Named identically to their filenames in
## DuelSounds/"*. The call sites in `src/functions/` say what each entry is
## for, and three of them settle questions this project had previously
## answered by guessing:
##
##  - `engine.c:1784-1802` — a SPELL is announced by its card TYPE
##    (WAV_SUMMON / WAV_ARTIFACT / WAV_ENCHANT / WAV_INSTANT /
##    WAV_INTERUPT / WAV_SORCERY), **inside the resolution path**.
##  - `functions.c:14387-14453` `play_land_sound_effect_force_color` — a
##    LAND is announced by the COLOURS IT PRODUCES, from a table of six
##    single-colour files and ten dual-colour ones. The enum groups those
##    files under a literal `// Land sounds.` comment.
##  - `damage_effects.c:524` *"// Damaging a player."* — damage to a PLAYER
##    is WAV_LIFELOSS; only damage to a CARD (`:705`) is WAV_DAMAGE.
##
## The map moved out of `duel_screen.gd` into [DuelAudio] on 2026-09-02,
## which is why these tests need no screen: every cue in the duel is a pure
## function of one [GameEvent], and a test that needs a display or an audio
## device is a test that will one day be skipped.


func _inst(card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card in test: %s" % card_name)
	var inst := CardInstance.new(data, 1, 0)
	# cur_mana_abilities is what the land table reads; ContinuousEffects
	# fills it from the printed list on every recalculate, and a bare
	# instance starts from the same place.
	inst.cur_mana_abilities = data.mana_abilities.duplicate()
	return inst


func _cue(type: int, data: Dictionary = {}) -> String:
	return DuelAudio.cue_for(GameEvent.new(type, data))


# ------------------------------------------- a spell sounds like its TYPE --

func test_a_creature_spell_is_the_summon_sound() -> void:
	assert_eq(DuelAudio.cast_sound_key(_inst("Grizzly Bears")), "sfx_summon")


func test_an_artifact_is_the_artifact_sound() -> void:
	assert_eq(DuelAudio.cast_sound_key(_inst("Black Lotus")), "sfx_cast_artifact")


func test_an_enchantment_is_the_enchant_sound() -> void:
	assert_eq(DuelAudio.cast_sound_key(_inst("Holy Strength")),
		"sfx_cast_enchantment")


func test_a_sorcery_is_the_sorcery_sound() -> void:
	assert_eq(DuelAudio.cast_sound_key(_inst("Wrath of God")), "sfx_cast_sorcery")


func test_an_instant_is_the_instant_sound() -> void:
	assert_eq(DuelAudio.cast_sound_key(_inst("Lightning Bolt")),
		"sfx_cast_instant")


func test_a_counterspell_is_the_INTERRUPT_sound() -> void:
	# INTERRUPT was a real 1997 card type and Counterspell wore it; the
	# modern oracle folded it into Instant, so no CardData carries it and
	# the sound is keyed off the counter EFFECT instead. Same file, same
	# moment, no invented type.
	assert_eq(DuelAudio.cast_sound_key(_inst("Counterspell")),
		"sfx_cast_interrupt")


func test_the_colour_files_are_not_cast_sounds_any_more() -> void:
	# THE CORRECTION §3.8 MADE. White/Blue/Black/Red/Green.wav were
	# imported as `sfx_cast_<colour>` and played on every SPELL_CAST, so a
	# Mountain and a Lightning Bolt made the same noise. They are the
	# LAND table. Nothing may map a spell onto them again.
	for card_name in ["Lightning Bolt", "Grizzly Bears", "Wrath of God",
			"Holy Strength", "Black Lotus", "Counterspell"]:
		var key := DuelAudio.cast_sound_key(_inst(card_name))
		assert_false(key.begins_with("sfx_land_"),
			"%s must not borrow a land sound (%s)" % [card_name, key])


# ---------------------------- a land sounds like the colours it PRODUCES --

func test_a_basic_land_is_its_own_colour() -> void:
	for pair in [["Forest", "sfx_land_green"], ["Mountain", "sfx_land_red"],
			["Island", "sfx_land_blue"], ["Swamp", "sfx_land_black"],
			["Plains", "sfx_land_white"]]:
		assert_eq(DuelAudio.land_sound_key(_inst(pair[0])), pair[1], pair[0])


func test_a_colourless_land_is_Grey() -> void:
	# `case 0: wav1 = WAV_GREY;` — the entry we had never imported.
	assert_eq(DuelAudio.land_sound_key(_inst("Strip Mine")), "sfx_land_grey")


func test_a_dual_land_gets_the_pairs_own_file() -> void:
	# The original names five allied pairs and five enemy ones and aliases
	# the reversals onto them (defs.h:2255-2265), so the pool's ten duals
	# use ten distinct files.
	var expected := {
		"Tundra": "sfx_land_white_blue",
		"Underground Sea": "sfx_land_blue_black",
		"Badlands": "sfx_land_black_red",
		"Taiga": "sfx_land_red_green",
		"Savannah": "sfx_land_green_white",
		"Scrubland": "sfx_land_white_black",
		"Bayou": "sfx_land_black_green",
		"Tropical Island": "sfx_land_green_blue",
		"Volcanic Island": "sfx_land_blue_red",
		"Plateau": "sfx_land_red_white",
	}
	var used := {}
	for name in expected:
		var key := DuelAudio.land_sound_key(_inst(name))
		assert_eq(key, expected[name], name)
		used[key] = true
	assert_eq(used.size(), 10, "ten duals, ten distinct files")


func test_a_five_colour_land_is_silent() -> void:
	# The Manalink comment picks GemBazar for itself while recording that
	# the 1997 game did not: *"five colors - going with gembazar, even
	# though City of Brass is silent."* The 1997 answer wins.
	assert_eq(DuelAudio.land_sound_key(_inst("City of Brass")), "")


# ------------------------------------------------- WHEN each cue fires --

func test_a_creature_is_announced_ONCE_and_when_it_ARRIVES() -> void:
	# THE DOUBLE-FIRE THIS PASS KILLED. We played the type sound on
	# SPELL_CAST *and* `sfx_summon` again on ENTERS_BATTLEFIELD, so every
	# creature announced itself twice — once as it left your hand and once
	# as it landed. `engine.c:1786` fires inside the RESOLUTION path, and
	# resolution is also where §2.4's spell flight puts the card down.
	var bear := _inst("Grizzly Bears")
	assert_eq(_cue(Mtg.EventType.SPELL_CAST, {"instance": bear}), "",
		"nothing as it leaves the hand")
	assert_eq(_cue(Mtg.EventType.ENTERS_BATTLEFIELD, {"instance": bear}),
		"sfx_summon", "and Summon.wav as it lands")


func test_a_permanent_lands_with_its_OWN_type_sound() -> void:
	# ENTERS_BATTLEFIELD used to play `sfx_summon` for every non-land, so
	# an artifact and an enchantment both arrived sounding like creatures.
	# `engine.c:1788` and `:1794` give each its own file.
	assert_eq(_cue(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": _inst("Black Lotus")}), "sfx_cast_artifact")
	assert_eq(_cue(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": _inst("Holy Strength")}), "sfx_cast_enchantment")


func test_a_land_arriving_is_left_to_the_land_table() -> void:
	# Two events fire when a land is played; only LAND_PLAYED may sound,
	# or every Forest would make two noises.
	assert_eq(_cue(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": _inst("Forest")}), "")
	assert_eq(_cue(Mtg.EventType.LAND_PLAYED,
		{"instance": _inst("Forest")}), "sfx_land_green")


func test_an_instant_or_sorcery_keeps_its_cue_on_the_cast() -> void:
	# A LABELLED DIVERGENCE, not an oversight: neither ever enters the
	# battlefield, so there is no arrival to sound at, and the engine
	# dispatches no "spell resolved" event to hang one on. The cast is the
	# moment the player can see — the card leaves the hand for the Chain.
	assert_eq(_cue(Mtg.EventType.SPELL_CAST,
		{"instance": _inst("Lightning Bolt")}), "sfx_cast_instant")
	assert_eq(_cue(Mtg.EventType.SPELL_CAST,
		{"instance": _inst("Wrath of God")}), "sfx_cast_sorcery")
	assert_eq(_cue(Mtg.EventType.SPELL_CAST,
		{"instance": _inst("Counterspell")}), "sfx_cast_interrupt")


func test_damage_to_a_PLAYER_is_LifeLoss_not_Damage() -> void:
	# `damage_effects.c:524` — *"// Damaging a player."* -> WAV_LIFELOSS;
	# `:705` -> WAV_DAMAGE for a card. `lose_life` (`functions.c:9871`)
	# plays WAV_LIFELOSS too. We played Damage.wav for both until
	# 2026-09-02, and LifeLoss.wav sat imported and unused.
	assert_eq(_cue(Mtg.EventType.DAMAGE_DEALT,
		{"amount": 3, "to_player": 0}), "sfx_life_loss")
	assert_eq(_cue(Mtg.EventType.DAMAGE_DEALT,
		{"amount": 3, "to_instance": _inst("Grizzly Bears")}), "sfx_damage")


func test_the_untap_step_makes_no_sound_at_all() -> void:
	# THE OWNER, 2026-09-03: *"The changing phases or combat phases have
	# no sound by themselves. Card action and other actions that happen in
	# phases have sound effects."* BECAME_UNTAPPED fires once per permanent
	# during the untap step — nobody did anything, so it was the clock
	# sounding. WAV_UNTAP = 19 has no call site in any 1997 source we
	# hold, so nothing sourced is lost.
	assert_eq(_cue(Mtg.EventType.BECAME_UNTAPPED,
		{"instance": _inst("Forest")}), "")


func test_tapping_for_an_ABILITY_taps_audibly_too() -> void:
	# The original plays WAV_TAP from all three of its tap-to-pay paths:
	# charging mana (`engine.c:1204`, `:1403`) and playing an ability
	# (`:1917`). We had only the mana half, so a Prodigal Sorcerer pinging
	# was silent until its damage landed.
	assert_eq(_cue(Mtg.EventType.TAPPED_FOR_MANA,
		{"instance": _inst("Forest")}), "sfx_tap")
	assert_eq(_cue(Mtg.EventType.ABILITY_ACTIVATED, {"taps": true}), "sfx_tap")
	assert_eq(_cue(Mtg.EventType.ABILITY_ACTIVATED, {"taps": false}), "",
		"an ability paid for with mana alone does not tap anything")


func test_the_rest_of_the_1997_vocabulary_is_where_it_was() -> void:
	assert_eq(_cue(Mtg.EventType.CARD_DRAWN, {"player": 0}), "sfx_draw")
	assert_eq(_cue(Mtg.EventType.DECLARED_ATTACKERS, {}), "sfx_attack")
	assert_eq(_cue(Mtg.EventType.BLOCKERS_DECLARED, {}), "sfx_block")
	assert_eq(_cue(Mtg.EventType.DIES,
		{"instance": _inst("Grizzly Bears")}), "sfx_buried")


func test_an_event_the_1997_game_had_no_sound_for_is_silent() -> void:
	# BLOCKED fires once per attacker/blocker PAIR; the original's
	# WAV_BLOCK2 is on the declaration (`engine.c:1539`), so a double
	# block must not stack the sample on itself.
	assert_eq(_cue(Mtg.EventType.BLOCKED, {}), "")
	assert_eq(_cue(Mtg.EventType.UPKEEP_START, {"player": 0}), "")
	assert_eq(_cue(Mtg.EventType.LEAVES_BATTLEFIELD,
		{"instance": _inst("Grizzly Bears")}), "")


# ------------------------------------------------------- the voice pool --

var _audio: DuelAudio


func before_each() -> void:
	_audio = DuelAudio.new()
	add_child_autofree(_audio)


func test_one_cue_may_take_only_one_voice_per_frame() -> void:
	# Combat damage arrives as one DAMAGE_DEALT per creature, the opening
	# deal as fourteen CARD_DRAWN. Five copies of one sample started on the
	# same frame are not five hits — they are one hit five times as loud.
	_audio.recent.clear()
	for _i in 5:
		_audio.play("sfx_damage")
	assert_eq(_audio.recent, ["sfx_damage"] as Array[String],
		"a five-way combat is one Damage.wav, not five")


func test_different_cues_in_one_frame_LAYER() -> void:
	# The whole point of the pool. On the single player this replaced, the
	# second of these cut the first off mid-sample.
	_audio.recent.clear()
	_audio.play("sfx_damage")
	_audio.play("sfx_buried")
	_audio.play("sfx_life_loss")
	assert_eq(_audio.recent.size(), 3, "three cues, three voices")


func test_the_same_cue_may_sound_again_on_a_later_frame() -> void:
	_audio.recent.clear()
	_audio.play("sfx_tap")
	await get_tree().process_frame
	_audio.play("sfx_tap")
	assert_eq(_audio.recent.size(), 2, "tap, tap — two lands, two frames")


func test_an_empty_key_is_not_a_cue() -> void:
	# `cue_for` returns "" for most events and for a five-colour land;
	# that must cost nothing at all.
	_audio.recent.clear()
	_audio.play("")
	assert_eq(_audio.recent.size(), 0)


func test_a_missing_sample_is_silence_and_not_an_error() -> void:
	# THE PROVENANCE RULE, as code: no 1997 audio is in this repository,
	# and a player who has not imported any must get a duel that plays
	# correctly and simply makes fewer sounds. `silent` is forced off so
	# this really walks the load path under the dummy driver.
	_audio.silent = false
	_audio.recent.clear()
	_audio.play("sfx_this_key_has_no_file_behind_it")
	assert_eq(_audio.recent, ["sfx_this_key_has_no_file_behind_it"] as Array[String],
		"the cue was still decided")
	var voices := 0
	for child in _audio.get_children():
		if child is AudioStreamPlayer:
			voices += 1
	assert_eq(voices, 0, "and no voice was allocated for a sound that is not there")


func test_a_headless_run_allocates_no_audio_player_at_all() -> void:
	# The test suite and the Deck Lab both run headless and must not open
	# an audio device or pay for one.
	assert_true(_audio.silent, "headless: the layer knows it cannot be heard")
	for _i in 20:
		_audio.play("sfx_damage")
		await get_tree().process_frame
	_audio.play_music("music_duel")
	for child in _audio.get_children():
		assert_false(child is AudioStreamPlayer,
			"nothing that could open a device was created")


func test_the_cue_log_is_bounded() -> void:
	for i in DuelAudio.RECENT_MAX * 2:
		_audio.play("sfx_%d" % i)
		await get_tree().process_frame
	assert_eq(_audio.recent.size(), DuelAudio.RECENT_MAX,
		"a long duel cannot grow it without limit")


# ------------------------------------------------------- the manifest --

func test_every_sound_key_the_duel_names_actually_resolves() -> void:
	# A typo in a key is silence, which no other test would notice. Only
	# meaningful when the player HAS imported the 1997 sounds; on a clean
	# checkout there are none, and that is the supported state.
	var keys: Array = ["sfx_land_grey", "sfx_cast_enchantment",
		"sfx_cast_instant", "sfx_cast_sorcery", "sfx_cast_interrupt",
		"sfx_cast_artifact", "sfx_summon", "sfx_draw", "sfx_block",
		"sfx_attack", "sfx_damage", "sfx_life_loss", "sfx_buried",
		"sfx_tap", "sfx_untap", "sfx_shuffle", "sfx_discard",
		"sfx_end_turn", "sfx_toss", "sfx_button", "sfx_win", "sfx_lose"]
	keys.append_array(DuelAudio.LAND_SOLO_SOUNDS.values())
	keys.append_array(DuelAudio.LAND_PAIR_SOUNDS.values())
	if GameSkin.sound("sfx_summon") == null:
		assert_true(true, "no original sounds imported — nothing to check")
		return
	for key in keys:
		assert_not_null(GameSkin.sound(key), "%s.wav is missing" % key)
