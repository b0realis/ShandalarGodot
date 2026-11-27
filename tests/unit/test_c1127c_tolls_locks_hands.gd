extends GameTest
## PLAYER REPORT 2's LEFTOVERS, 2026-11-27 — the computer, the untap locks
## and the hand counters (own_goal.gd: "the lock", "the hand"):
##  1. a static that caps the untap step (one land, one creature, one
##     artifact, two permanents) is cast only when it holds the other side
##     at least as hard as ours; the gate's null arm is the pilot as it was;
##  2. under a land cap the lands are a stock: no end-step activation
##     spends them while a card in hand wants the mana, and a permanent
##     waits for the better card the stock is about to reach;
##  3. an upkeep line that counts a hand: the symmetric one is cast by the
##     hands as they are; a reward of ours is read as the toll is, with
##     the sign turned; a land nothing will use stays in a hand that is
##     paid for its size.

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


func _drive(ai: AiPlayer, n := 8) -> void:
	for _i in n:
		var line := ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break


func _many(pid: int, card_name: String, n: int, tapped := false) -> void:
	for _i in n:
		var inst := put_battlefield(pid, card_name)
		inst.tapped = tapped


func _hand(pid: int, card_name: String, n: int) -> void:
	for _i in n: give_hand(pid, card_name)


func _open_lands() -> int:
	var open := 0
	for inst in g.players[0].battlefield:
		if inst.is_land() and not inst.tapped: open += 1
	return open


# ------------------------------------------------------ 1 casting the lock --

func _orb_into_our_own_hand(profile: AiProfile) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 5)
	_many(1, "Forest", 5)
	_hand(1, "Forest", 2)
	var orb := give_hand(0, "Winter Orb")
	_hand(0, "Craw Wurm", 2)
	return [ai, orb]


func test_no_winter_orb_over_our_own_dear_hand() -> void:
	for profile in _rungs():
		before_each()
		var made := _orb_into_our_own_hand(profile)
		var ai: AiPlayer = made[0]
		var orb: CardInstance = made[1]
		assert_ne(ai._cast_gate(g, orb), "", profile.profile_name)
		_drive(ai)
		assert_eq(orb.zone, Mtg.Zone.HAND, profile.profile_name)


func test_null_arm_casts_the_orb_as_before() -> void:
	var made := _orb_into_our_own_hand(_null())
	var ai: AiPlayer = made[0]
	var orb: CardInstance = made[1]
	assert_eq(ai._cast_gate(g, orb), "")
	_drive(ai)
	assert_eq(orb.zone, Mtg.Zone.BATTLEFIELD, "the gate off is the pilot as it was")


func test_the_orb_catches_a_tapped_out_opponent() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 3)
	_many(0, "Grizzly Bears", 2)
	_many(1, "Forest", 6, true)
	_hand(1, "Forest", 5)
	var orb := give_hand(0, "Winter Orb")
	assert_eq(OWN_GOAL.lock_refusal(g, ai, orb), "")
	assert_eq(ai._cast_gate(g, orb), "")
	_drive(ai)
	assert_eq(orb.zone, Mtg.Zone.BATTLEFIELD)


func test_the_orb_estimate() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 5)
	_many(1, "Forest", 5)
	_hand(1, "Forest", 4)
	var orb := give_hand(0, "Winter Orb")
	# A hand that asks nothing: the lock holds nothing of ours.
	assert_eq(OWN_GOAL.lock_refusal(g, ai, orb), "")
	# A dear hand of ours against their open lands.
	_hand(0, "Craw Wurm", 2)
	assert_ne(OWN_GOAL.lock_refusal(g, ai, orb), "")
	# Their lands tapped and a full hand across: both are held, they harder.
	for land in g.players[1].battlefield: land.tapped = true
	_hand(1, "Forest", 3)
	assert_eq(OWN_GOAL.lock_refusal(g, ai, orb), "")


func test_smoke_is_for_the_seat_with_fewer_attackers() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 2)
	_many(0, "Craw Wurm", 3)
	_many(1, "Grizzly Bears", 1)
	var smoke := give_hand(0, "Smoke")
	assert_ne(OWN_GOAL.lock_refusal(g, ai, smoke), "")
	assert_ne(ai._cast_gate(g, smoke), "")
	_drive(ai)
	assert_eq(smoke.zone, Mtg.Zone.HAND)
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 2)
	_many(0, "Grizzly Bears", 1)
	_many(1, "Craw Wurm", 3)
	smoke = give_hand(0, "Smoke")
	assert_eq(OWN_GOAL.lock_refusal(g, ai, smoke), "")
	_drive(ai)
	assert_eq(smoke.zone, Mtg.Zone.BATTLEFIELD)


func test_a_vigilant_attack_is_not_held() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Serra Angel", 3)
	_many(1, "Craw Wurm", 2)
	var smoke := give_hand(0, "Smoke")
	assert_eq(OWN_GOAL.lock_refusal(g, ai, smoke), "")


func test_the_other_caps() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	# Two permanents: our three attackers and our dear hand, their nothing.
	_many(0, "Forest", 5)
	_many(0, "Craw Wurm", 3)
	_many(1, "Forest", 2)
	var orb := give_hand(0, "Static Orb")
	_hand(0, "Craw Wurm", 2)
	assert_ne(OWN_GOAL.lock_refusal(g, ai, orb), "")
	# One artifact: ours are the ones that tap.
	_many(0, "Sol Ring", 3)
	var field := give_hand(0, "Damping Field")
	assert_ne(OWN_GOAL.lock_refusal(g, ai, field), "")
	_many(1, "Sol Ring", 4)
	assert_eq(OWN_GOAL.lock_refusal(g, ai, field), "")


func test_the_cap_reader() -> void:
	var caps := {"Winter Orb": ["land", 1], "Smoke": ["creature", 1],
		"Damping Field": ["artifact", 1], "Static Orb": ["permanent", 2]}
	for card_name in caps:
		assert_eq(OWN_GOAL.untap_cap_of(CardRegistry.get_card(card_name)), caps[card_name], card_name)
	for card_name in ["Meekstone", "Stasis", "Howling Mine", "Choke", "Grizzly Bears",
			"Storage Matrix", "Sands of Time"]:
		assert_eq(OWN_GOAL.untap_cap_of(CardRegistry.get_card(card_name)), [], card_name)


# ------------------------------------------------- 2 living under the lock --

func _stock(orb: bool, profile: AiProfile = null) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	if orb:
		put_battlefield(1, "Winter Orb")
	_many(0, "Forest", 5)
	_many(0, "Forest", 1, true)
	var bears := give_hand(0, "Grizzly Bears")
	var wurm := give_hand(0, "Craw Wurm")
	return [ai, bears, wurm]


func test_the_stock_is_kept_for_the_better_card() -> void:
	for profile in _rungs():
		before_each()
		var made := _stock(true, profile)
		var ai: AiPlayer = made[0]
		var bears: CardInstance = made[1]
		assert_eq(OWN_GOAL.land_refill(g, 0), 1)
		assert_ne(OWN_GOAL.stock_refusal(g, ai, bears), "", profile.profile_name)
		assert_eq(OWN_GOAL.stock_refusal(g, ai, made[2]), "")
		_drive(ai)
		assert_eq(bears.zone, Mtg.Zone.HAND, profile.profile_name)
		assert_eq(_open_lands(), 5, "one land more next turn is the Wurm")


func test_no_lock_no_saving() -> void:
	var made := _stock(false)
	var ai: AiPlayer = made[0]
	var bears: CardInstance = made[1]
	assert_eq(OWN_GOAL.land_refill(g, 0), -1)
	_drive(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_null_arm_spends_the_stock() -> void:
	var made := _stock(true, _null())
	var ai: AiPlayer = made[0]
	var bears: CardInstance = made[1]
	_drive(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the gate off is the pilot as it was")


func test_a_blocker_is_cast_all_the_same() -> void:
	var made := _stock(true)
	var ai: AiPlayer = made[0]
	var bears: CardInstance = made[1]
	put_battlefield(1, "Hill Giant")
	assert_eq(OWN_GOAL.stock_refusal(g, ai, bears), "")


func test_a_card_too_far_off_is_not_saved_for() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Winter Orb")
	_many(0, "Forest", 3)
	_many(0, "Forest", 3, true)
	var bears := give_hand(0, "Grizzly Bears")
	give_hand(0, "Craw Wurm")
	assert_eq(OWN_GOAL.stock_refusal(g, ai, bears), "", "three turns off")
	_drive(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func _their_end_step_with_a_rod(orb: bool, card_in_hand: bool, profile: AiProfile = null) -> AiPlayer:
	var ai := _ai(profile)
	advance_to_next_turn()   # seat 1's turn
	if orb:
		put_battlefield(1, "Winter Orb")
	_many(0, "Forest", 3)
	put_battlefield(0, "Rod of Ruin")
	if card_in_hand:
		give_hand(0, "Craw Wurm")
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(1))
	return ai


func test_the_sink_is_no_sink_under_a_land_cap() -> void:
	var ai := _their_end_step_with_a_rod(true, true)
	_drive(ai)
	assert_eq(_open_lands(), 3, "three lands that would come back one a turn")
	assert_eq(g.players[1].life, 20)


func test_the_sink_without_a_lock_is_as_it_was() -> void:
	var ai := _their_end_step_with_a_rod(false, true)
	_drive(ai)
	assert_eq(_open_lands(), 0)
	assert_eq(g.players[1].life, 19)


func test_the_sink_with_nothing_to_save_for() -> void:
	var ai := _their_end_step_with_a_rod(true, false)
	_drive(ai)
	assert_eq(g.players[1].life, 19, "no card in hand wants the mana")


func test_null_arm_sinks_under_the_orb() -> void:
	var ai := _their_end_step_with_a_rod(true, true, _null())
	_drive(ai)
	assert_eq(g.players[1].life, 19, "the gate off is the pilot as it was")


# ------------------------------------------------------------ 3 the hand --

func test_the_hand_line_readers() -> void:
	var world := OWN_GOAL.punisher_lines(CardRegistry.get_card("Storm World"))
	assert_eq(world.size(), 1)
	assert_eq(String(world[0][0]), "hand")
	for card_name in ["Black Vise", "The Rack", "Iron Maiden", "Wheel of Torture",
			"Ivory Tower", "Howling Mine"]:
		assert_eq(OWN_GOAL.punisher_lines(CardRegistry.get_card(card_name)), [], card_name)
	assert_eq(OWN_GOAL.hand_reward_of_line(
		CardRegistry.get_card("Ivory Tower").triggered_abilities[0].text),
		{"slope": 1, "threshold": 4})
	assert_eq(OWN_GOAL.hand_reward_of_line(
		CardRegistry.get_card("Black Vise").triggered_abilities[0].text), {})


func test_the_beat_of_each_hand_line() -> void:
	_ai()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(OWN_GOAL.hand_beat(g, 0, 7), 0)
	var maiden := put_battlefield(1, "Iron Maiden")
	assert_eq(OWN_GOAL.hand_beat(g, 0, 7), 3)
	assert_eq(OWN_GOAL.hand_beat(g, 1, 7), 0, "its controller is not squeezed")
	g.players[1].battlefield.erase(maiden)
	before_each()
	_ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Wheel of Torture")
	assert_eq(OWN_GOAL.hand_beat(g, 0, 1), 2)
	put_battlefield(1, "Storm World")
	assert_eq(OWN_GOAL.hand_beat(g, 0, 1), 5)
	assert_eq(OWN_GOAL.hand_beat(g, 1, 1), 3)
	put_battlefield(0, "Ivory Tower")
	assert_eq(OWN_GOAL.hand_beat(g, 0, 6), -2, "our reward")
	assert_eq(OWN_GOAL.hand_beat(g, 1, 6), 0, "and not theirs")


func test_iron_maiden_is_minded_as_the_vise_is() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_hand(0, "Craw Wurm", 5)
	var bears := give_hand(0, "Grizzly Bears")
	assert_eq(float(ai._vise_relief(g, bears)), 0.0)
	put_battlefield(1, "Iron Maiden")
	assert_gt(float(ai._vise_relief(g, bears)), 0.0, "a card out is a point saved")
	assert_false(OWN_GOAL.hand_is_held(g, ai))


func test_storm_world_is_cast_by_the_hands_as_they_are() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 2)
	var world := give_hand(0, "Storm World")
	_hand(0, "Craw Wurm", 4)
	_hand(1, "Forest", 6)
	# Their hand is full: it would charge them nothing.
	assert_ne(ai._cast_gate(g, world), "")
	_drive(ai)
	assert_eq(world.zone, Mtg.Zone.HAND)
	# Their hand is empty and ours is not: theirs alone.
	g.players[1].hand.clear()
	assert_eq(ai._cast_gate(g, world), "")
	# Ours is the emptier one.
	_hand(1, "Forest", 3)
	for card in g.players[0].hand.duplicate():
		if card != world: g.players[0].hand.erase(card)
	assert_ne(ai._cast_gate(g, world), "")
	# The gate off reads none of it.
	assert_eq(_ai(_null())._cast_gate(g, world), "")


func test_storm_world_is_cast_at_an_empty_hand_across() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 2)
	var world := give_hand(0, "Storm World")
	_hand(0, "Craw Wurm", 4)
	_drive(ai)
	assert_eq(world.zone, Mtg.Zone.BATTLEFIELD)


func _idle_land_in_hand(lock: String, lock_owner: int, spare: int, profile: AiProfile = null) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	if lock != "":
		put_battlefield(lock_owner, lock)
	_many(0, "Forest", 6)
	var land := give_hand(0, "Forest")
	give_hand(0, "Grizzly Bears")
	_hand(0, "Giant Growth", spare)
	return [ai, land]


func test_a_land_nothing_will_use_stays_in_a_stretched_hand() -> void:
	for profile in _rungs():
		before_each()
		var made := _idle_land_in_hand("Storm World", 1, 1, profile)
		var ai: AiPlayer = made[0]
		var land: CardInstance = made[1]
		assert_true(OWN_GOAL.hand_is_held(g, ai), profile.profile_name)
		_drive(ai)
		assert_eq(land.zone, Mtg.Zone.HAND, profile.profile_name)


func test_null_arm_plays_the_land_into_the_storm() -> void:
	var made := _idle_land_in_hand("Storm World", 1, 1, _null())
	_drive(made[0])
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_a_land_stays_in_a_hand_our_tower_pays_for() -> void:
	var made := _idle_land_in_hand("Ivory Tower", 0, 4)
	var ai: AiPlayer = made[0]
	assert_true(OWN_GOAL.hand_is_held(g, ai))
	_drive(ai)
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.HAND)


func test_their_tower_holds_nothing_of_ours() -> void:
	var made := _idle_land_in_hand("Ivory Tower", 1, 4)
	assert_false(OWN_GOAL.hand_is_held(g, made[0]))
	_drive(made[0])
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_a_squeezed_hand_plays_its_land() -> void:
	var made := _idle_land_in_hand("Black Vise", 1, 4)
	assert_false(OWN_GOAL.hand_is_held(g, made[0]))
	_drive(made[0])
	assert_eq((made[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_a_land_with_a_use_is_played_into_the_storm() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Storm World")
	_many(0, "Forest", 2)
	var land := give_hand(0, "Forest")
	give_hand(0, "Craw Wurm")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


func test_a_cast_out_of_a_paid_hand_is_charged() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 3)
	var bears := give_hand(0, "Grizzly Bears")
	_hand(0, "Craw Wurm", 5)
	var plain: float = ai._cast_value(g, bears, [], 0)
	assert_eq(OWN_GOAL.cast_relief(g, ai, bears), 0.0)
	put_battlefield(0, "Ivory Tower")
	assert_lt(OWN_GOAL.cast_relief(g, ai, bears), 0.0)
	assert_lt(float(ai._cast_value(g, bears, [], 0)), plain)
	assert_eq(OWN_GOAL.cast_relief(g, _ai(_null()), bears), 0.0)
	# At four cards the Tower pays nothing either way.
	for card in g.players[0].hand.duplicate():
		if card != bears and g.players[0].hand.size() > 4: g.players[0].hand.erase(card)
	assert_eq(OWN_GOAL.cast_relief(g, _ai(), bears), 0.0)
