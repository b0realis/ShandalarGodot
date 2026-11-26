extends GameTest
## CAMPAIGN 2026-11-26, the computer opponent's own goals (bugs1 1-7). One
## pin per finding, each beside the gate's null arm
## ([member AiProfile.forecasts_tactics] off: the pilot as it was) or an
## unaffected control:
##  1. a library swap is not cast into an empty graveyard;
##  2. "draw from the graveyard or lose" is not cast with no graveyard;
##  3. the enchantment whose unpaid upkeep exiles the library is not cast,
##     and on the table its upkeep is paid;
##  4. "creatures can't attack" is neither cast nor paid for while our own
##     attack is the bigger one;
##  5. a damage spell with a draw rider is aimed at the opponent;
##  6. a rescue bounce waits for a response;
##  7. a sweep that arrives with its permanent is priced by what each side
##     loses.

const OWN_GOAL := preload("res://engine/ai/own_goal.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


func _drive(ai: AiPlayer, n := 6) -> void:
	for _i in n:
		var line := ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


func _graveyard(pid: int, card_name: String, n: int) -> void:
	for _i in n:
		var inst := _make_instance(pid, card_name)
		inst.zone = Mtg.Zone.GRAVEYARD
		g.players[pid].graveyard.append(inst)


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _our_upkeep_passed() -> void:
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == Mtg.Step.DRAW) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


# ------------------------------------------------------------ 1 the swap --

func test_library_swap_is_not_cast_into_an_empty_graveyard() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Island", 4)
		var shift := give_hand(0, "Paradigm Shift")
		assert_ne(ai._cast_gate(g, shift), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(shift.zone, Mtg.Zone.HAND, profile.profile_name)
		assert_eq(g.players[0].library.size(), 30, profile.profile_name)


func test_library_swap_null_arm_and_the_big_graveyard() -> void:
	var off := _ai(_null())
	var shift := give_hand(0, "Paradigm Shift")
	assert_eq(off._cast_gate(g, shift), "", "the gate off is the pilot as it was")
	var ai := _ai()
	_graveyard(0, "Forest", 29)
	assert_ne(ai._cast_gate(g, shift), "", "29 cards against a library of 30")
	_graveyard(0, "Forest", 2)
	assert_eq(ai._cast_gate(g, shift), "", "31 cards against 30: the bigger library")


# ----------------------------------------------------------- 2 the crypt --

func test_forbidden_crypt_needs_a_graveyard() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Swamp", 5)
		var crypt := give_hand(0, "Forbidden Crypt")
		assert_ne(ai._cast_gate(g, crypt), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(crypt.zone, Mtg.Zone.HAND, profile.profile_name)
	_graveyard(0, "Swamp", OWN_GOAL.CRYPT_FLOOR)
	var late := _ai()
	var held := give_hand(0, "Forbidden Crypt")
	assert_eq(late._cast_gate(g, held), "", "ten draws in the graveyard")
	assert_eq(_ai(_null())._cast_gate(g, give_hand(0, "Forbidden Crypt")), "")


# ------------------------------------------------------------ 3 the lash --

func test_thought_lash_is_never_cast() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Island", 6)
		for _i in 3: put_battlefield(0, "Hill Giant")
		var lash := give_hand(0, "Thought Lash")
		assert_ne(ai._cast_gate(g, lash), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(lash.zone, Mtg.Zone.HAND, profile.profile_name)


func test_thought_lash_upkeep_is_paid_while_the_library_can() -> void:
	# 26 counters become 27 at the upkeep; the library holds 30. The card's
	# own hint says no (30 <= 27 + 5), and no is the whole library.
	_ai()
	var lash := put_battlefield(0, "Thought Lash")
	lash.counters["age"] = 26
	advance_to_next_turn()   # seat 1's turn
	_our_upkeep_passed()
	assert_eq(lash.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].library.size(), 2, "30 less the 27 paid and the draw")
	assert_false(g.game_over)


func test_thought_lash_upkeep_null_arm_exiles_the_library() -> void:
	_ai(_null())
	var lash := put_battlefield(0, "Thought Lash")
	lash.counters["age"] = 26
	advance_to_next_turn()
	_our_upkeep_passed()
	assert_ne(lash.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------------------------------- 4 the peace --

func test_peacekeeper_is_not_cast_over_our_own_attack() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Plains", 6)
		for _i in 3: put_battlefield(0, "Hill Giant")
		g.players[1].life = 5
		var keeper := give_hand(0, "Peacekeeper")
		assert_ne(ai._cast_gate(g, keeper), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(keeper.zone, Mtg.Zone.HAND, profile.profile_name)


func test_peacekeeper_is_cast_against_the_bigger_attack() -> void:
	var ai := _ai()
	put_battlefield(0, "Hill Giant")
	for _i in 3: put_battlefield(1, "Hill Giant")
	var keeper := give_hand(0, "Peacekeeper")
	assert_eq(ai._cast_gate(g, keeper), "")
	assert_eq(_ai(_null())._cast_gate(g, keeper), "")


func test_peacekeeper_rent_is_dropped_when_we_are_the_attacker() -> void:
	for profile in _rungs():
		before_each()
		_ai(profile)
		_lands(0, "Plains", 6)
		for _i in 3: put_battlefield(0, "Hill Giant")
		var keeper := put_battlefield(0, "Peacekeeper")
		advance_to_next_turn()
		_our_upkeep_passed()
		assert_eq(keeper.zone, Mtg.Zone.GRAVEYARD, profile.profile_name)


func test_peacekeeper_rent_is_paid_against_the_bigger_attack() -> void:
	_ai()
	_lands(0, "Plains", 6)
	put_battlefield(0, "Hill Giant")
	for _i in 3: put_battlefield(1, "Hill Giant")
	var keeper := put_battlefield(0, "Peacekeeper")
	advance_to_next_turn()
	_our_upkeep_passed()
	assert_eq(keeper.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------------------------------- 5 the flare --

func test_flare_at_their_end_step_is_aimed_at_them() -> void:
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		profile.mistake_chance = 0.0
		var ai := _ai(profile)
		_lands(0, "Mountain", 4)
		var flare := give_hand(0, "Flare")
		_their_turn_at(Mtg.Step.END)
		ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		assert_ne(flare.zone, Mtg.Zone.HAND, profile.profile_name)
		assert_eq(g.players[0].life, 20, profile.profile_name)
		assert_eq(g.players[1].life, 19, profile.profile_name)


func test_flare_null_arm_hit_its_own_caster() -> void:
	var ai := _ai(_null())
	_lands(0, "Mountain", 4)
	give_hand(0, "Flare")
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	if not g.stack.is_empty(): resolve_stack()
	assert_eq(g.players[0].life, 19, "the finding, reproduced with the gate off")


func test_ray_of_erasure_mills_them() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var ray := give_hand(0, "Ray of Erasure")
	_their_turn_at(Mtg.Step.END)
	var ours := g.players[0].library.size()
	var theirs := g.players[1].library.size()
	ai.act(g)
	if not g.stack.is_empty(): resolve_stack()
	assert_ne(ray.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].library.size(), ours)
	assert_eq(g.players[1].library.size(), theirs - 1)


func test_a_plain_draw_instant_still_draws_for_us() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var recall := give_hand(0, "Ancestral Recall")
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	if not g.stack.is_empty(): resolve_stack()
	assert_ne(recall.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 3)


# ---------------------------------------------------------- 6 the rescue --

func test_rescue_is_not_spent_on_our_own_land() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Island", 3)
		var rescue := give_hand(0, "Rescue")
		give_hand(0, "Island")
		for _i in 4: _drive(ai)
		assert_eq(rescue.zone, Mtg.Zone.HAND, profile.profile_name)


func test_rescue_answers_removal_aimed_at_our_best_creature() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	_lands(1, "Swamp", 3)
	var djinn := put_battlefield(0, "Mahamoti Djinn")
	var rescue := give_hand(0, "Rescue")
	var terror := give_hand(1, "Terror")
	_their_turn_at(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	for _i in 3: add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(djinn)]))
	assert_ok(g.pass_priority(1))
	ai.act(g)
	resolve_stack()
	assert_eq(rescue.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(djinn.zone, Mtg.Zone.HAND)


# ----------------------------------------------------------- 7 the sweep --

func test_planar_collapse_is_not_cast_over_our_own_board() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Plains", 4)
		for _i in 3: put_battlefield(0, "Hill Giant")
		put_battlefield(0, "Grizzly Bears")
		var collapse := give_hand(0, "Planar Collapse")
		assert_ne(ai._cast_gate(g, collapse), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(collapse.zone, Mtg.Zone.HAND, profile.profile_name)


func test_planar_collapse_is_cast_over_their_board() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(1, "Hill Giant")
	var collapse := give_hand(0, "Planar Collapse")
	assert_eq(ai._cast_gate(g, collapse), "")
	for _i in 4: put_battlefield(0, "Hill Giant")
	assert_ne(ai._cast_gate(g, collapse), "", "an even trade is no sweep")
	assert_eq(_ai(_null())._cast_gate(g, collapse), "")


func test_crater_hellion_is_not_cast_over_our_own_board() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_lands(0, "Mountain", 6)
		var giants: Array = []
		for _i in 3: giants.append(put_battlefield(0, "Hill Giant"))
		var hellion := give_hand(0, "Crater Hellion")
		assert_ne(ai._cast_gate(g, hellion), "", profile.profile_name)
		for _i in 4: _drive(ai)
		assert_eq(hellion.zone, Mtg.Zone.HAND, profile.profile_name)
		for giant in giants: assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)


func test_crater_hellion_is_cast_where_it_wins_the_board() -> void:
	var ai := _ai()
	var hellion := give_hand(0, "Crater Hellion")
	assert_eq(ai._cast_gate(g, hellion), "", "an empty table: a 6/6")
	put_battlefield(0, "Scryb Sprites")
	assert_eq(ai._cast_gate(g, hellion), "", "one Sprite for a 6/6")
	for _i in 3: put_battlefield(1, "Hill Giant")
	for _i in 3: put_battlefield(0, "Hill Giant")
	assert_eq(ai._cast_gate(g, hellion), "", "three for three, and the body")
