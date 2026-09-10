extends GameTest
## DEVELOP AFTER COMBAT (2026-09-10, [member AiProfile.develops_late];
## `docs/forge/casting.md` P1).
##
## [method AiPlayer.act] reaches [method AiPlayer._main_phase_action] in
## EITHER main step and the first one it reaches is Main 1, so every land,
## creature, artifact, enchantment, draw spell, discard and tutor this
## pilot has ever played went down BEFORE its own combat — and with it the
## mana. Reproduced at HEAD, a Wizard on four Forests with an Ironroot
## Treefolk in hand and a Grizzly Bears already on the table:
##
##     MAIN1 act -> 'played a land'          (untapped lands 5)
##     MAIN1 act -> 'cast Ironroot Treefolk' (untapped lands 0)
##     ...their declare-blockers, with all of it shown and no mana up
##     MAIN2: nothing in hand, nothing open
##
## EVERY PRESET SHIPS THE KNOB OFF (`docs/ai-difficulty.md` §4): the row
## is built and measurable and the Lab refused the rung. The OFF arm below
## is therefore the shipped pilot, and the ON arm is what one Deck Lab
## command turns on.
##
## Every behaviour is pinned on BOTH arms.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.develops_late = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.develops_late = false
	return profile


## Everything the pilot does in the main step it is standing in, until it
## passes. The action lines only, so a test reads like the log does.
func _develop(ai: AiPlayer) -> Array:
	var did: Array = []
	for _i in 12:
		var line := ai.act(g)
		if line == "" or line == "pass":
			break
		did.append(line)
		resolve_stack()
	return did


func _lands(pid: int, count: int, name := "Forest") -> void:
	for _i in count:
		put_battlefield(pid, name)


func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


# ------------------------------------------------------- the reproduction --

func test_off_the_creature_is_cast_before_combat() -> void:
	var ai := _ai(_off())
	_lands(0, 5)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Ironroot Treefolk")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_develop(ai), ["cast Ironroot Treefolk"],
		"the first main step is the one the planner reaches")
	assert_eq(_untapped_lands(0), 0, "and it is tapped out for its own combat")


func test_on_the_creature_waits_for_the_second_main_phase() -> void:
	var ai := _ai(_on())
	_lands(0, 5)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Ironroot Treefolk")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_develop(ai), [], "nothing in Main 1")
	assert_eq(_untapped_lands(0), 5, "five lands open through the combat")
	assert_eq(g.players[0].hand.size(), 1, "and the card still in hand")


func test_on_the_second_main_phase_casts_it() -> void:
	# THE HOLD IS A HOLD AND NOT A REFUSAL. The act loop has to reach Main
	# 2 with the cast still legal, which is P1's own stated risk.
	var ai := _ai(_on())
	_lands(0, 5)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Ironroot Treefolk")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_develop(ai), ["cast Ironroot Treefolk"])
	assert_eq(g.players[0].hand.size(), 0)


func test_main2_is_a_step_the_turn_cannot_skip() -> void:
	# The structural fact the whole row rests on, pinned so nobody has to
	# re-derive it: MAIN2 is in the canonical order and in the priority
	# list, and the only steps the engine ever skips are combat ones — a
	# declaration with no attackers and the first-strike step nobody is
	# in (CR 508-510).
	assert_true(Mtg.STEP_ORDER.has(Mtg.Step.MAIN2))
	assert_true(Mtg.PRIORITY_STEPS.has(Mtg.Step.MAIN2))
	assert_gt(Mtg.STEP_ORDER.find(Mtg.Step.MAIN2),
		Mtg.STEP_ORDER.find(Mtg.Step.COMBAT_END),
		"and it comes after the combat it is waiting for")


# --------------------------------------------------- Forge's Main-1 list --

func test_a_haste_creature_is_cast_before_combat_on_both_arms() -> void:
	# `ComputerUtil.java:1217-1220`. A Ball Lightning held for Main 2 is a
	# 6/1 that never attacks and dies at the end of the turn.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 3, "Mountain")
		give_hand(0, "Ball Lightning")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["cast Ball Lightning"],
			"knob on" if on else "knob off")


func test_a_mana_artifact_is_cast_before_combat_on_both_arms() -> void:
	# `:1181` — the Moxen carry `PlayMain1:TRUE` in Forge because holding
	# a mana source is holding the mana.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 1)
		give_hand(0, "Mox Emerald")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["cast Mox Emerald"],
			"knob on" if on else "knob off")


func test_a_mana_creature_waits_because_it_is_summoning_sick() -> void:
	# The other half of the same sentence: a Llanowar Elves cast in Main 1
	# taps for nothing this turn, so it has no claim on the early moment.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 1)
		give_hand(0, "Llanowar Elves")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), [] if on else ["cast Llanowar Elves"],
			"knob on" if on else "knob off")


func test_an_answer_to_a_blocker_is_cast_before_combat() -> void:
	# Forge's first interrupt (`:1246-1259`): removing a blocker lets more
	# attackers through in one's own Main 1.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 2, "Swamp")
		put_battlefield(0, "Grizzly Bears")
		put_battlefield(1, "Wall of Stone")
		give_hand(0, "Paralyze")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["cast Paralyze"],
			"knob on" if on else "knob off")


func test_the_same_answer_waits_when_no_attack_is_coming() -> void:
	# Forge's `PlayMain1:TRUE` is literally "when the AI has creatures".
	# With nothing to send, the blocker can be answered after combat and
	# the opponent learns of it one step later.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 2, "Swamp")
		put_battlefield(1, "Wall of Stone")
		give_hand(0, "Paralyze")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), [] if on else ["cast Paralyze"],
			"held: there is no combat to change" if on else "and cast at HEAD")


func test_an_aura_on_our_own_attacker_is_cast_before_combat() -> void:
	# `castSpellInMain1`'s pump clause (`:1299-1361`): a Holy Strength on
	# the body that is about to swing is worth nothing in Main 2.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 1, "Plains")
		put_battlefield(0, "Savannah Lions")
		give_hand(0, "Holy Strength")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["cast Holy Strength"],
			"knob on" if on else "knob off")


func test_a_win_is_never_postponed() -> void:
	# The bar the note asks for is not a number, it is a game: a cast
	# [method AiPlayer._cast_value] prices at LETHAL_WORTH is made in the
	# step it is found in, on either arm.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 5, "Mountain")
		g.players[1].life = 4
		give_hand(0, "Fireball")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["cast Fireball"],
			"knob on" if on else "knob off")
		assert_true(g.game_over or g.players[1].life <= 0,
			"and it was the game")


func test_floating_mana_is_spent_before_the_step_ends() -> void:
	# CR 500.4: the pool empties at the step boundary, so mana already in
	# it has no second main phase to wait for (`:1191-1205`).
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Ironroot Treefolk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 5)
	assert_eq(_develop(ai), ["cast Ironroot Treefolk"],
		"the mana would be lost")


# --------------------------------------------------------- the mana sink --

func test_a_mana_sink_waits_for_the_second_main_phase() -> void:
	# Without this gate the knob defeats itself: with the hand held,
	# [method AiPlayer._try_cast_best] answers "" in Main 1 and the Tome
	# spends on a card the mana the hold exists to keep open.
	var ai := _ai(_on())
	_lands(0, 4)
	put_battlefield(0, "Jayemdae Tome")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_develop(ai), [], "held")
	assert_eq(_untapped_lands(0), 4)


func test_off_the_mana_sink_fires_before_combat() -> void:
	var ai := _ai(_off())
	_lands(0, 4)
	put_battlefield(0, "Jayemdae Tome")
	advance_to_step(Mtg.Step.MAIN1)
	# The card it draws is one of the library's Forests, and the land drop
	# follows it: both are Main 1 actions at HEAD.
	assert_eq(_develop(ai), ["activated Jayemdae Tome", "played a land"])


func test_on_the_mana_sink_fires_in_the_second_main_phase() -> void:
	var ai := _ai(_on())
	_lands(0, 4)
	put_battlefield(0, "Jayemdae Tome")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_develop(ai), ["activated Jayemdae Tome", "played a land"])


func test_the_factory_still_animates_before_combat_on_both_arms() -> void:
	# [method AiPlayer._animation_value] answers 0.0 outside our own first
	# main step, so the animation has exactly one moment and the hold must
	# not take it away.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 3)
		put_battlefield(0, "Mishra's Factory")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(_develop(ai), ["activated Mishra's Factory"],
			"knob on" if on else "knob off")


# ---------------------------------------------------------- the land drop --

func test_the_land_drop_waits_when_nothing_wants_it() -> void:
	# `HOLD_LAND_DROP_FOR_MAIN2_IF_UNUSED` — the land is the one card the
	# opponent can be certain of, and a land that changes nothing castable
	# is worth more in hand until after the attack.
	var ai := _ai(_on())
	_lands(0, 4)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()   # `:1415-1418` — not on turn 1 or 2
	assert_eq(g.active_player, 0)
	assert_gt(g.turn_number, 2)
	assert_eq(_develop(ai), [], "the drop waits")
	assert_eq(g.players[0].lands_played_this_turn, 0)


func test_off_the_land_drop_is_made_before_combat() -> void:
	var ai := _ai(_off())
	_lands(0, 4)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_develop(ai), ["played a land"])


func test_the_held_land_drop_is_made_in_the_second_main_phase() -> void:
	var ai := _ai(_on())
	_lands(0, 4)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_develop(ai), [])
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_develop(ai), ["played a land"])
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_the_land_drop_is_made_when_a_card_in_hand_needs_it() -> void:
	# `canCastWithLandDrop` (`:1443`), asked of the mana planner rather
	# than of a cheapest-CMC number: four Forests do not cast an Ironroot
	# Treefolk ({4}{G}) and five do.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 4)
		put_battlefield(0, "Grizzly Bears")
		give_hand(0, "Forest")
		give_hand(0, "Ironroot Treefolk")
		advance_to_next_turn()
		advance_to_next_turn()
		assert_true(_develop(ai).has("played a land"),
			"knob on" if on else "knob off")


func test_the_land_drop_is_made_when_a_body_of_ours_wants_the_mana() -> void:
	# THE HAZARD, AND FORGE'S OWN GUARD (`hasRelevantAbsOTB`,
	# `:1504-1512`). This pilot sizes its attack and its block by the mana
	# it is holding ([member AiProfile.pumps_to_attack]), so a land kept
	# in hand is a Carrion Ants that reads one point smaller at the
	# declaration. With a firebreather on the table the land is played.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 4, "Swamp")
		put_battlefield(0, "Carrion Ants")
		give_hand(0, "Swamp")
		advance_to_next_turn()
		advance_to_next_turn()
		assert_true(_develop(ai).has("played a land"),
			"knob on" if on else "knob off")


func test_the_land_drop_is_made_on_the_first_two_turns() -> void:
	# `:1415-1418`. Nothing is hidden by holding a land while the board is
	# one permanent deep.
	var ai := _ai(_on())
	_lands(0, 4)
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.turn_number, 1)
	assert_eq(_develop(ai), ["played a land"])


func test_the_land_drop_is_made_with_an_empty_board() -> void:
	# `HOLD_LAND_DROP_ONLY_IF_HAVE_OTHER_PERMS` (`:1423`).
	var ai := _ai(_on())
	give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_develop(ai), ["played a land"])


func test_an_x_spell_in_hand_always_wants_the_land() -> void:
	# A plan at X = 0 answers "castable already" for a Fireball on one
	# Mountain, and the X is exactly what the drop is for.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_lands(0, 2, "Mountain")
		put_battlefield(0, "Grizzly Bears")
		give_hand(0, "Mountain")
		give_hand(0, "Fireball")
		advance_to_next_turn()
		advance_to_next_turn()
		assert_true(_develop(ai).has("played a land"),
			"knob on" if on else "knob off")


# ------------------------------------------------------------- the rungs --

func test_every_preset_ships_the_null() -> void:
	# THE NUMBERS REFUSED THE RUNG (`docs/ai-difficulty.md` §4). P1 asked
	# for Sorcerer and Wizard; nine pairs at 1,000 games an arm read −0.5,
	# −0.2, +0.8, −2.0, −0.8, −2.9, −1.1, −3.1 and −1.8, eight of nine
	# against the knob and not one clear of its interval — and the ladder's
	# own rule is that a knob is as good or better one rung up. So the
	# field ships at the null everywhere and the question is one Deck Lab
	# command, the way `crack_back_margin` ships 0.
	assert_false(AiProfile.apprentice().develops_late)
	assert_false(AiProfile.magician().develops_late)
	assert_false(AiProfile.sorcerer().develops_late)
	assert_false(AiProfile.wizard().develops_late)


func test_the_knob_is_reachable_from_the_deck_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("develops_late=off"), "")
	assert_false(profile.develops_late)
	assert_eq(profile.apply_overrides("develops_late=on"), "")
	assert_true(profile.develops_late)
