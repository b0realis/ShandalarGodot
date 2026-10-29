extends GutTest
## THE 1997 DEATH AND TURN-END SOUNDS (the polish pass, 2026-10-28). The
## ledger's two open sound questions — *"Death sound Buried.wav vs
## Kill.wav, and EndTurn.wav on the AI's pass"* — answered from the
## Shandalar 1.3 decompilation (cited, not copied):
##
##  - `process_killed_card` (SHANDALAR 0x0046dbed / MAGIC 0x004b0c12), the
##    one door every permanent goes through from play to a graveyard: not
##    for a sacrifice (kill mode 3) or a removal (4), not for a token —
##    then WAV_KILL when the card's ORIGINAL type is a creature, else
##    WAV_BURIED for any other permanent. `kill_creatures_with_lethal_damage`
##    (0x0046cf00) plays WAV_KILL for lethal damage too.
##  - a sacrifice plays WAV_SACRFICE where the body is given up
##    (`choose_creature_to_sacrifice`, 0x0049fb64; Strip Mine and the
##    upkeep sacrifices in the card code).
##  - WAV_ENDTURN is played once per turn, by `run_duel_turn`'s last state
##    (`ai_decision_phase`, SHANDALAR 0x00408dcc — a decompiler's name for
##    the turn loop's tail, run for either seat's turn) after the cleanup,
##    the mana burn and the end-of-duel check: the turn passing from one
##    seat to the other. So it sounds when the computer passes its turn to
##    you, and when you pass yours.
##
## Until this pass every DIES played Buried.wav and EndTurn.wav was
## imported and never played.


func _inst(card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card in test: %s" % card_name)
	return CardInstance.new(data, 1, 0)


func _dies(inst: CardInstance, sacrificed := false) -> String:
	return DuelAudio.cue_for(GameEvent.new(Mtg.EventType.DIES,
		{"instance": inst, "controller": 0, "sacrificed": sacrificed}))


func test_a_creature_that_dies_is_the_kill_sound() -> void:
	assert_eq(_dies(_inst("Grizzly Bears")), "sfx_kill", "WAV_KILL")
	assert_eq(_dies(_inst("Serra Angel")), "sfx_kill")


func test_a_permanent_that_is_not_a_creature_is_buried() -> void:
	for card_name in ["Ivory Tower", "Holy Strength", "Plains", "Black Vise"]:
		assert_eq(_dies(_inst(card_name)), "sfx_buried",
			"%s is WAV_BURIED" % card_name)


func test_the_original_type_decides_not_the_animated_one() -> void:
	# `original_internal_card_id`'s type: a Mishra's Factory that died as
	# a creature is still a land card, so it is buried.
	var factory := _inst("Mishra's Factory")
	factory.last_types = Mtg.CardType.LAND | Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE
	assert_eq(_dies(factory), "sfx_buried")


func test_a_sacrifice_is_the_sacrifice_sound() -> void:
	assert_eq(_dies(_inst("Grizzly Bears"), true), "sfx_sacrifice", "WAV_SACRFICE")
	assert_eq(_dies(_inst("Strip Mine"), true), "sfx_sacrifice")


func test_a_token_dies_silently() -> void:
	var token := _inst("Grizzly Bears")
	token.is_token = true
	assert_eq(_dies(token), "", "process_killed_card skips a token")
	assert_eq(_dies(token, true), "sfx_sacrifice",
		"the sacrifice is sounded where the body is given up, token or not")


func test_the_turn_passing_is_the_end_turn_sound_for_either_seat() -> void:
	for pid in [0, 1]:
		assert_eq(DuelAudio.cue_for(GameEvent.new(Mtg.EventType.CLEANUP_START,
			{"player": pid})), "sfx_end_turn", "seat %d passes the turn" % pid)


func test_a_skin_without_the_new_files_still_sounds() -> void:
	# The released skins carry Buried.wav but not yet Kill.wav or
	# Sacrfice.wav: a creature's death falls back to the old cue rather
	# than going silent until the player re-imports.
	assert_eq(DuelAudio.FALLBACK.get("sfx_kill", ""), "sfx_buried")
	assert_eq(DuelAudio.FALLBACK.get("sfx_sacrifice", ""), "sfx_buried")
	var had: bool = GameSkin._sound_cache.has("sfx_kill")
	var kept: Variant = GameSkin._sound_cache.get("sfx_kill")
	var had_b: bool = GameSkin._sound_cache.has("sfx_buried")
	var kept_b: Variant = GameSkin._sound_cache.get("sfx_buried")
	var buried := AudioStreamWAV.new()
	GameSkin._sound_cache["sfx_kill"] = null
	GameSkin._sound_cache["sfx_buried"] = buried
	assert_eq(DuelAudio.stream_for("sfx_kill"), buried,
		"no Kill.wav in the skin: Buried.wav plays")
	if had: GameSkin._sound_cache["sfx_kill"] = kept
	else: GameSkin._sound_cache.erase("sfx_kill")
	if had_b: GameSkin._sound_cache["sfx_buried"] = kept_b
	else: GameSkin._sound_cache.erase("sfx_buried")


func test_a_lan_table_carries_the_new_cues() -> void:
	# The referee sends DuelAudio.cue_for's keys to every seat, and a seat
	# REFUSES the whole view on a key it does not know
	# (SgViewProtocol's cue check) — so a new cue that is not in the list
	# breaks a LAN duel the first time a creature dies.
	for cue in ["sfx_kill", "sfx_sacrifice", "sfx_end_turn", "sfx_buried"]:
		assert_has(SgDuelPresentation.CUES, cue, "%s reaches a LAN seat" % cue)


func test_the_importer_takes_the_two_1997_files() -> void:
	var source := FileAccess.get_file_as_string("res://tools/import_original.py")
	assert_string_contains(source, "\"sfx_kill.wav\":")
	assert_string_contains(source, "duel_sound(\"Kill.wav\")")
	assert_string_contains(source, "\"sfx_sacrifice.wav\":")
	assert_string_contains(source, "duel_sound(\"Sacrfice.wav\")")
