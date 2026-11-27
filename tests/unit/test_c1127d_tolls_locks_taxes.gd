extends GameTest
## THE LEFTOVERS OF 0.70.14, 2026-11-27 — the computer and the locks and
## taxes of other shapes (own_goal.gd, "the other locks and taxes"):
##  1. a lock a creature carries, the untap of one chosen kind, the flip,
##     the land a cast sets back and the drain are cast only when they hold
##     the other side at least as hard as ours; under each the pilot plays
##     by it (the kind untapped, the idle lands under the flip, the cheap
##     spell that is not worth a land);
##  2. the rungs that do not price a hand toll keep developing over a
##     squeeze's limit and do not empty a stretched hand for nothing;
##  3. under a land cap the stock is kept for the better card in the main
##     phase's activations and in an X as well.

const OWN_GOAL := preload("res://engine/ai/own_goal.gd")
const KIND_PROMPT := "Untap only artifacts, creatures, or lands this step?"


func before_each() -> void:
	# One rebuild of the registry for the file, not ten for each board
	# (a no-op once the packs are on); switched off again in after_all.
	CardPacks.set_enabled_many(CardPacks.available_ids(), true)
	super()


func after_each() -> void:
	g = null


func after_all() -> void:
	CardPacks.set_enabled_many(CardPacks.available_ids(), false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null(base: AiProfile = null) -> AiProfile:
	var p := base if base != null else AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _steady(p: AiProfile) -> AiProfile:
	p.mistake_chance = 0.0
	return p


func _rungs() -> Array:
	return [_steady(AiProfile.apprentice()), _steady(AiProfile.magician()),
		AiProfile.sorcerer(), AiProfile.wizard()]


func _drive(ai: AiPlayer, n := 8) -> void:
	for _i in n:
		var line := ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break


func _many(pid: int, card_name: String, n: int, tapped := false) -> Array:
	var out := []
	for _i in n:
		var inst := put_battlefield(pid, card_name)
		inst.tapped = tapped
		out.append(inst)
	return out


func _hand(pid: int, card_name: String, n: int) -> void:
	for _i in n: give_hand(pid, card_name)


func _open_lands() -> int:
	var open := 0
	for inst in g.players[0].battlefield:
		if inst.is_land() and not inst.tapped: open += 1
	return open


# ------------------------------------------------------------ the readers --

func test_the_shape_reader() -> void:
	var shapes := {"Marble Titan": "carried", "Storage Matrix": "choice",
		"Sands of Time": "flip", "Mana Vortex": "drain", "Mana Breach": "breach",
		"Winter Orb": "land", "Smoke": "creature"}
	for card_name in shapes:
		var shape := OWN_GOAL.lock_shape_of(give_hand(0, card_name).data)
		assert_eq(String(shape[0]) if not shape.is_empty() else "", shapes[card_name], card_name)
	for card_name in ["Grizzly Bears", "Meekstone", "Stasis", "Spellshock", "Howling Mine",
			"Black Vise", "Verduran Enchantress"]:
		assert_eq(OWN_GOAL.lock_shape_of(give_hand(0, card_name).data), [], card_name)
	assert_eq(OWN_GOAL.cast_toll_of_line(
		"Whenever a player casts a spell, that player returns a land they control to its owner's hand."), [1, 0])
	assert_eq(OWN_GOAL.cast_toll_of_line(
		"Whenever a player casts a spell, this enchantment deals 2 damage to that player."), [0, 2])
	assert_eq(OWN_GOAL.cast_toll_of_line("Whenever you cast a spell, you gain 1 life."), [0, 0])


# ------------------------------------------ 1a the lock a creature carries --

func _titan(ours: String, theirs: String, profile: AiProfile = null) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Plains", 4)
	_many(0, ours, 2)
	_many(1, theirs, 2)
	return [ai, give_hand(0, "Marble Titan")]


func test_no_marble_titan_over_our_own_big_creatures() -> void:
	for profile in _rungs():
		before_each()
		var made := _titan("Craw Wurm", "Grizzly Bears", profile)
		var ai: AiPlayer = made[0]
		var titan: CardInstance = made[1]
		assert_ne(ai._cast_gate(g, titan), "", profile.profile_name)
		_drive(ai)
		assert_eq(titan.zone, Mtg.Zone.HAND, profile.profile_name)


func test_null_arm_casts_the_titan_as_before() -> void:
	var made := _titan("Craw Wurm", "Grizzly Bears", _null())
	_drive(made[0])
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_the_titan_is_for_their_big_creatures() -> void:
	var made := _titan("Grizzly Bears", "Craw Wurm")
	var ai: AiPlayer = made[0]
	assert_eq(ai._cast_gate(g, made[1]), "")
	_drive(ai)
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_the_titan_over_small_creatures_is_a_body() -> void:
	var made := _titan("Grizzly Bears", "Grizzly Bears")
	assert_eq((made[0] as AiPlayer)._cast_gate(g, made[1]), "")


# ------------------------------------------------- 1b the kind that untaps --

func test_the_matrix_is_not_cast_over_our_own_two_kinds() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 5)
	_many(0, "Craw Wurm", 2)
	_hand(0, "Craw Wurm", 2)
	_many(1, "Island", 5)
	_hand(1, "Island", 4)
	var matrix := give_hand(0, "Storage Matrix")
	assert_ne(ai._cast_gate(g, matrix), "", "our lands or our Wurms; they have lands alone")
	_drive(ai)
	assert_eq(matrix.zone, Mtg.Zone.HAND)
	assert_eq(_ai(_null())._cast_gate(g, matrix), "", "the gate off is the pilot as it was")


func test_the_matrix_is_cast_at_their_two_kinds() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Island", 4)
	_many(1, "Forest", 5)
	_many(1, "Craw Wurm", 2)
	_hand(1, "Forest", 4)
	var matrix := give_hand(0, "Storage Matrix")
	assert_eq(ai._cast_gate(g, matrix), "")
	_drive(ai)
	assert_eq(matrix.zone, Mtg.Zone.BATTLEFIELD)


func _labels() -> Array[String]:
	return g.UNTAP_KIND_LABELS.duplicate()


func test_the_kind_untapped_is_the_one_that_buys_most() -> void:
	var ai := _ai()
	put_battlefield(1, "Storage Matrix")
	_many(0, "Forest", 3, true)
	_many(0, "Craw Wurm", 2, true)
	# Three lands and two creatures tapped: the engine's default is the
	# lands; with nothing in hand the Wurms are what the turn wants.
	assert_eq(ai.answer_option(g, 0, KIND_PROMPT, _labels(), 2), 1)
	# A Wurm in hand asks for the lands... and three do not pay for it.
	give_hand(0, "Grizzly Bears")
	assert_eq(ai.answer_option(g, 0, KIND_PROMPT, _labels(), 2), 1, "two mana against twelve power")
	assert_eq(_ai(_null()).answer_option(g, 0, KIND_PROMPT, _labels(), 2), 2, "the gate off: the default")


func test_lands_are_untapped_for_the_hand() -> void:
	var ai := _ai()
	put_battlefield(1, "Storage Matrix")
	_many(0, "Forest", 2, true)
	_many(0, "Wall of Wood", 3, true)
	give_hand(0, "Grizzly Bears")
	# Three walls against two lands: the default is the creatures.
	assert_eq(ai.answer_option(g, 0, KIND_PROMPT, _labels(), 1), 2)
	# With an attack across the walls are wanted back.
	_many(1, "Craw Wurm", 1)
	assert_eq(ai.answer_option(g, 0, KIND_PROMPT, _labels(), 1), 1)


func test_another_question_is_not_answered_here() -> void:
	var ai := _ai()
	put_battlefield(1, "Storage Matrix")
	_many(0, "Craw Wurm", 2, true)
	var other: Array[String] = ["One", "Two", "Three"]
	assert_eq(ai.answer_option(g, 0, "Which?", other, 2), 2)
	assert_eq(OWN_GOAL.untap_kind(g, ai, other, 2), -1)


func test_the_untap_step_asks_the_pilot() -> void:
	var ai := _ai()
	put_battlefield(1, "Storage Matrix")
	var lands := _many(0, "Forest", 3, true)
	var wurms := _many(0, "Craw Wurm", 2, true)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_false((wurms[0] as CardInstance).tapped, "the creatures were chosen")
	assert_true((lands[0] as CardInstance).tapped)
	assert_not_null(ai)


# -------------------------------------------------------------- 1c the flip --

func test_sands_of_time_is_not_cast_at_a_tapped_out_opponent() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 7)
	_many(1, "Forest", 5, true)
	var sands := give_hand(0, "Sands of Time")
	assert_ne(ai._cast_gate(g, sands), "", "their lands untap; three of ours would be tapped")
	_drive(ai)
	assert_eq(sands.zone, Mtg.Zone.HAND)
	assert_eq(_ai(_null())._cast_gate(g, sands), "", "the gate off is the pilot as it was")


func test_sands_of_time_catches_an_open_board() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 4)
	_many(1, "Forest", 5)
	_many(1, "Grizzly Bears", 2)
	var sands := give_hand(0, "Sands of Time")
	assert_eq(ai._cast_gate(g, sands), "")
	_drive(ai)
	assert_eq(sands.zone, Mtg.Zone.BATTLEFIELD)


func _their_end_step_under_the_sands(burn: bool, profile: AiProfile = null) -> AiPlayer:
	var ai := _ai(profile)
	g.rules.mana_burn = burn
	advance_to_next_turn()   # seat 1's turn
	put_battlefield(1, "Sands of Time")
	_many(0, "Forest", 3)
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(1))
	return ai


func test_idle_lands_are_tapped_into_the_flip() -> void:
	var ai := _their_end_step_under_the_sands(false)
	assert_true(OWN_GOAL.flips(g, 0))
	assert_string_contains(ai.act(g), "idle land")
	assert_eq(_open_lands(), 0)
	_drive(ai)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	assert_eq(_open_lands(), 3, "what was tapped is open in our turn")


func test_null_arm_loses_the_lands_to_the_flip() -> void:
	var ai := _their_end_step_under_the_sands(false, _null())
	_drive(ai)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_open_lands(), 0, "the gate off is the pilot as it was")


func test_no_tapping_into_mana_burn_under_the_flip() -> void:
	var ai := _their_end_step_under_the_sands(true)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].life, 20)


func test_a_cast_under_the_flip_is_worth_its_lands() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 3)
	var bears := give_hand(0, "Grizzly Bears")
	assert_eq(OWN_GOAL.cast_relief(g, ai, bears), 0.0)
	put_battlefield(1, "Sands of Time")
	assert_almost_eq(OWN_GOAL.cast_relief(g, ai, bears), 1.0, 0.001, "two lands open next turn")
	assert_eq(OWN_GOAL.cast_relief(g, _ai(_null()), bears), 0.0)


# ------------------------------------------------- 1d the land a cast costs --

func _under_the_breach(lands: int, land_in_hand: bool, profile: AiProfile = null) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Mana Breach")
	_many(0, "Plains", lands)
	if land_in_hand:
		give_hand(0, "Plains")
		g.players[0].lands_played_this_turn = 1
	give_hand(0, "Serra Angel")
	return [ai, give_hand(0, "Healing Salve")]


func test_a_cheap_spell_is_not_worth_a_land_set_back() -> void:
	for profile in _rungs():
		before_each()
		var made := _under_the_breach(3, true, profile)
		var ai: AiPlayer = made[0]
		assert_eq(OWN_GOAL.cast_tolls(g), [1, 0])
		assert_ne(ai._cast_gate(g, made[1]), "", profile.profile_name)
		assert_eq(ai._cast_gate(g, g.players[0].hand[1]), "", "the Angel is worth a land")


func test_a_land_the_drop_puts_back_costs_nothing() -> void:
	var made := _under_the_breach(3, false)
	assert_eq((made[0] as AiPlayer)._cast_gate(g, made[1]), "")


func test_lands_in_plenty_pay_the_breach() -> void:
	var made := _under_the_breach(7, true)
	assert_eq((made[0] as AiPlayer)._cast_gate(g, made[1]), "")


func test_null_arm_casts_into_the_breach() -> void:
	var made := _under_the_breach(3, true, _null())
	assert_eq((made[0] as AiPlayer)._cast_gate(g, made[1]), "")


func test_no_breach_no_reading() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Plains", 3)
	give_hand(0, "Plains")
	give_hand(0, "Serra Angel")
	assert_eq(OWN_GOAL.cast_tolls(g), [0, 0])
	assert_eq(OWN_GOAL.cast_toll_refusal(g, ai, give_hand(0, "Healing Salve")), "")


func test_no_cast_into_a_toll_that_is_our_last_life() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Spellshock")
	_many(0, "Forest", 3)
	var bears := give_hand(0, "Grizzly Bears")
	assert_eq(ai._cast_gate(g, bears), "")
	g.players[0].life = 2
	assert_ne(ai._cast_gate(g, bears), "")
	_drive(ai)
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 2)


func test_the_breach_is_cast_by_the_spells_still_to_come() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Island", 3)
	_many(1, "Forest", 3)
	var breach := give_hand(0, "Mana Breach")
	_hand(0, "Grizzly Bears", 5)
	give_hand(1, "Forest")
	assert_ne(ai._cast_gate(g, breach), "", "five spells of ours against one card of theirs")
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Island", 3)
	_many(1, "Forest", 3)
	breach = give_hand(0, "Mana Breach")
	_hand(1, "Forest", 7)
	assert_eq(ai._cast_gate(g, breach), "", "nothing more of ours to cast; seven cards across")
	_drive(ai)
	assert_eq(breach.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------ 1e the drain --

func test_no_mana_vortex_under_our_own_dear_hand() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_many(0, "Island", 4)
		_many(1, "Forest", 6)
		give_hand(1, "Forest")
		var vortex := give_hand(0, "Mana Vortex")
		_hand(0, "Craw Wurm", 2)
		assert_ne(ai._cast_gate(g, vortex), "", profile.profile_name)
		_drive(ai)
		assert_eq(vortex.zone, Mtg.Zone.HAND, profile.profile_name)
		assert_eq(_ai(_null())._cast_gate(g, vortex), "", "the gate off is the pilot as it was")


func test_the_vortex_is_for_the_side_that_needs_no_more_mana() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Island", 4)
	_many(0, "Grizzly Bears", 3)
	_many(1, "Forest", 3)
	_hand(1, "Forest", 6)
	var vortex := give_hand(0, "Mana Vortex")
	assert_eq(ai._cast_gate(g, vortex), "")
	_drive(ai)
	assert_eq(vortex.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------- 2 the weaker rungs under a hand toll --

## A seed whose first roll is under the Magician's mistake chance — the
## main phase's roll, with no land to play before it.
func _fumbling_seed() -> int:
	for seed_value in range(1, 200):
		g.rng.seed = seed_value
		if g.rng.randf() < 0.15:
			return seed_value
	return 0


func _fumbled(profile: AiProfile, vise: bool) -> bool:
	profile.develops_late = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.MAIN1)
	if vise:
		put_battlefield(1, "Black Vise")
	_many(0, "Forest", 4)
	var bears := give_hand(0, "Grizzly Bears")
	_hand(0, "Craw Wurm", 6)
	g.rng.seed = _fumbling_seed()
	ai.act(g)
	return bears.zone == Mtg.Zone.HAND


func test_a_weak_rung_keeps_developing_over_the_vise_limit() -> void:
	assert_true(_fumbled(AiProfile.apprentice(), false), "the mistake model, as it was")
	for make in [AiProfile.apprentice, AiProfile.magician]:
		before_each()
		assert_false(_fumbled(make.call(), true))
	before_each()
	assert_true(_fumbled(AiProfile.magician(), false), "no Vise: the roll is taken")


func test_null_arm_fumbles_under_the_vise() -> void:
	assert_true(_fumbled(_null(AiProfile.apprentice()), true))


func test_the_fumble_is_spared_only_over_the_limit() -> void:
	var ai := _ai(AiProfile.apprentice())
	put_battlefield(1, "Black Vise")
	_hand(0, "Forest", 4)
	assert_false(OWN_GOAL.fumble_spared(g, ai), "four cards: the Vise charges nothing")
	give_hand(0, "Forest")
	assert_true(OWN_GOAL.fumble_spared(g, ai))
	assert_false(OWN_GOAL.fumble_spared(g, _ai(AiProfile.sorcerer())), "the Sorcerer prices it itself")
	assert_false(OWN_GOAL.fumble_spared(g, _ai(_null(AiProfile.apprentice()))))


func _salve_under(toll: String, profile: AiProfile) -> CardInstance:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	if toll != "":
		put_battlefield(1, toll)
	_many(0, "Plains", 6)
	var salve := give_hand(0, "Healing Salve")
	_hand(0, "Serra Angel", 1)
	_drive(ai, 1)
	_drive(ai, 3)
	return salve


func test_a_weak_rung_does_not_empty_its_hand_under_the_rack() -> void:
	for make in [AiProfile.apprentice, AiProfile.magician]:
		before_each()
		var salve := _salve_under("The Rack", _steady(make.call()))
		assert_eq(salve.zone, Mtg.Zone.HAND, "a Salve at twenty life for a point at every upkeep")
		assert_eq(g.players[0].hand.size(), 1, "the Angel is cast")
		before_each()
		salve = _salve_under("", _steady(make.call()))
		assert_ne(salve.zone, Mtg.Zone.HAND, "no Rack: as before")
		before_each()
		salve = _salve_under("The Rack", _null(_steady(make.call())))
		assert_ne(salve.zone, Mtg.Zone.HAND, "the gate off is the pilot as it was")


func test_the_stretch_charge() -> void:
	var ai := _ai(AiProfile.apprentice())
	_many(0, "Forest", 4)
	var bears := give_hand(0, "Grizzly Bears")
	assert_eq(OWN_GOAL.stretch_charge(g, ai, bears), 0.0)
	var plain: float = ai._cast_value(g, bears, [], 0)
	put_battlefield(1, "The Rack")
	assert_eq(OWN_GOAL.stretch_charge(g, ai, bears), 3.0, "a point at each of three upkeeps")
	assert_eq(float(ai._cast_value(g, bears, [], 0)), plain, "the card's worth is as printed")
	assert_eq(OWN_GOAL.stretch_charge(g, _ai(AiProfile.wizard()), bears), 0.0, "priced by its own knob")
	_hand(0, "Forest", 4)
	assert_eq(OWN_GOAL.stretch_charge(g, ai, bears), 0.0, "five cards: the Rack charges nothing")


# ------------------------------------- 3 the stock: main phase and the X --

func _scepter(orb: bool, card_in_hand: bool, profile: AiProfile = null) -> AiPlayer:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	if orb:
		put_battlefield(1, "Winter Orb")
	_many(0, "Forest", 4)
	put_battlefield(0, "Disrupting Scepter")
	_hand(1, "Forest", 3)
	if card_in_hand:
		give_hand(0, "Craw Wurm")
	return ai


func test_a_main_phase_activation_keeps_the_stock() -> void:
	var ai := _scepter(true, true)
	_drive(ai)
	assert_eq(_open_lands(), 4, "two turns from the Wurm")
	assert_eq(g.players[1].hand.size(), 3)


func test_the_activation_without_a_lock_is_as_it_was() -> void:
	var ai := _scepter(false, true)
	_drive(ai)
	assert_eq(g.players[1].hand.size(), 2)


func test_the_activation_with_nothing_to_save_for() -> void:
	var ai := _scepter(true, false)
	_drive(ai)
	assert_eq(g.players[1].hand.size(), 2)


func test_null_arm_activates_under_the_orb() -> void:
	var ai := _scepter(true, true, _null())
	_drive(ai)
	assert_eq(g.players[1].hand.size(), 2, "the gate off is the pilot as it was")


func _fireball(orb: bool, card_in_hand: bool, profile: AiProfile = null) -> Array:
	var p := profile if profile != null else AiProfile.wizard()
	p.holds_x_burn = 0   # the X is cast for what it kills now
	var ai := _ai(p)
	advance_to_step(Mtg.Step.MAIN1)
	if orb:
		put_battlefield(1, "Winter Orb")
	_many(0, "Mountain", 4)
	_many(1, "Grizzly Bears", 1)
	if card_in_hand:
		give_hand(0, "Shivan Dragon")
	return [ai, give_hand(0, "Fireball")]


func test_an_x_keeps_the_stock() -> void:
	var made := _fireball(true, true)
	_drive(made[0])
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.HAND)
	assert_eq(_open_lands(), 4, "two turns from the Dragon")


func test_the_x_without_a_lock_is_as_it_was() -> void:
	var made := _fireball(false, true)
	_drive(made[0])
	assert_ne((made[1] as CardInstance).zone, Mtg.Zone.HAND)


func test_the_x_with_nothing_to_save_for() -> void:
	var made := _fireball(true, false)
	_drive(made[0])
	assert_ne((made[1] as CardInstance).zone, Mtg.Zone.HAND)


func test_null_arm_pours_the_x_under_the_orb() -> void:
	var made := _fireball(true, true, _null())
	_drive(made[0])
	assert_ne((made[1] as CardInstance).zone, Mtg.Zone.HAND, "the gate off is the pilot as it was")
