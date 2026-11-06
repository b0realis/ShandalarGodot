extends GameTest
## THE 0.60.19 BUG PASS OVER THE FAIR AI'S URZA BLOCK READINGS
## (engine/ai/urza_tactics.gd, engine/ai/urza_spells.gd; gate:
## [member AiProfile.forecasts_tactics]).
##
##  * Damping Engine's ignore: the body is chosen first (our own Engine
##    before anything else), sacrificed under the search journal, and only
##    then is the hand read — a card the pilot would really cast with the
##    mana left, or a land drop (h5-1).
##  * The mana on the table: each source once — a dual land is listed once
##    per ability and an any-color source once per color, and a land the
##    plan taps is no mana left in any of its rows (h5-2).
##  * Our own Damping Engine only while their board outnumbers ours with
##    the Engine on it (h5-3).
##  * Their Veiled Sentry: our cast's body over the cheapest wake in our
##    hand is charged in full, and no cast whose wake makes their visible
##    power our life (h5-4).
##  * Masticore's repeat pings claim nothing that does more than damage
##    (Splintering Wind's Splinters) or costs more than mana (h5-5).
## Each policy keeps its null arm; the decisions a hidden zone could sway
## replay with the opponent's hand and both libraries changed
## (docs/fair-play.md).

const US := preload("res://engine/ai/urza_spells.gd")
const UT := preload("res://engine/ai/urza_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


func _count(pid: int, pick: Callable) -> int:
	var n := 0
	for p in g.players[pid].battlefield:
		if bool(pick.call(p)): n += 1
	return n


func _land_count(pid: int) -> int:
	return _count(pid, func(p: CardInstance) -> bool: return p.is_land())


func _act_all(ai: AiPlayer, n := 12) -> Array:
	var lines: Array = []
	for _i in n:
		var line := ai.act(g)
		lines.append(line)
		if line == "pass" or line == "":
			break
		resolve_stack()
	return lines


func _graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Give [param pid] exactly [param names] in hand (the hidden zone).
func _hand(pid: int, names: Array) -> void:
	for card in g.players[pid].hand.duplicate():
		g.players[pid].hand.erase(card)
	for n in names:
		give_hand(pid, n)


## Shuffle the library of [param pid] into a new order (the hidden zone).
func _restack(pid: int, names: Array) -> void:
	g.players[pid].library.clear()
	for n in names:
		var inst := _make_instance(pid, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)


# ================================================ h5-1 Damping Engine --

func test_the_ignore_keeps_the_land_the_dragon_needs() -> void:
	var ai := _ai()
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	_lands(0, "Mountain", 6)
	var dragon := give_hand(0, "Shivan Dragon")
	assert_ne(g.play_banned(0, dragon.data), "", "the Engine stops our dragon")
	var lines := _act_all(ai)
	assert_eq(_land_count(0), 6, "five Mountains never cast a six-drop: %s" % [lines])
	assert_eq(dragon.zone, Mtg.Zone.HAND)


func test_the_ignore_is_never_for_a_card_the_pilot_would_not_cast() -> void:
	var ai := _ai()
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	_lands(0, "Island", 6)
	var drake := give_hand(0, "Gilded Drake")   # nothing of theirs to take
	assert_ne(g.play_banned(0, drake.data), "", "the Engine stops our drake")
	var lines := _act_all(ai)
	assert_eq(g.players[0].battlefield.size(), 6, "nothing sacrificed: %s" % [lines])
	assert_eq(drake.zone, Mtg.Zone.HAND)


func test_the_ignore_reads_four_duals_as_four_mana() -> void:
	var ai := _ai()
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	_lands(0, "Volcanic Island", 4)
	give_hand(0, "Shivan Dragon")
	var lines := _act_all(ai)
	assert_eq(_land_count(0), 4, "four duals never cast a six-drop: %s" % [lines])


func test_our_own_engine_is_the_body_the_ignore_gives_up() -> void:
	var ai := _ai()
	put_battlefield(0, "Damping Engine")
	_lands(0, "Mountain", 9)
	put_battlefield(1, "Forest")
	var dragon := give_hand(0, "Shivan Dragon")
	var lines := _act_all(ai)
	assert_true(String(lines[0]).begins_with("ignores Damping Engine"), str(lines))
	assert_eq(_count(0, func(p: CardInstance) -> bool: return p.data.card_name == "Damping Engine"), 0,
		"the lock itself was the body to give up")
	assert_eq(_land_count(0), 9, "no land given up while our own Engine stood")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)


func test_their_engine_is_ignored_when_the_mana_after_the_sacrifice_pays() -> void:
	var ai := _ai()
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	_lands(0, "Mountain", 7)
	var dragon := give_hand(0, "Shivan Dragon")
	var lines := _act_all(ai)
	assert_true(String(lines[0]).begins_with("ignores Damping Engine"), str(lines))
	assert_eq(_land_count(0), 6)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "the dragon the ignore was for")


func test_the_ignore_never_trades_a_permanent_for_its_own_twin() -> void:
	var ai := _ai()
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	var song := put_battlefield(0, "Torch Song")
	_lands(0, "Mountain", 3)   # one Mountain fewer pays for no Torch Song
	var twin := give_hand(0, "Torch Song")
	assert_ne(g.play_banned(0, twin.data), "", "the Engine stops our second Song")
	var lines := _act_all(ai)
	assert_eq(song.zone, Mtg.Zone.BATTLEFIELD, "a Song given up for the same Song: %s" % [lines])
	assert_eq(twin.zone, Mtg.Zone.HAND)


func test_the_ignore_reads_no_hidden_zone() -> void:
	var first := ""
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(1, "Damping Engine")
		put_battlefield(1, "Forest")
		_lands(0, "Mountain", 7)
		give_hand(0, "Shivan Dragon")
		_hand(1, ["Lightning Bolt", "Counterspell"] if variant == 0 else ["Forest", "Swamp"])
		_restack(1, ["Island", "Island", "Shivan Dragon"] if variant == 0 else ["Swamp", "Forest", "Mountain"])
		_restack(0, ["Forest", "Forest", "Forest"] if variant == 0 else ["Serra Angel", "Island", "Swamp"])
		var line := ai.act(g)
		if variant == 0:
			first = line
		else:
			assert_eq(line, first, "the same public board, the same ignore")
	assert_true(first.begins_with("ignores Damping Engine"), first)


func test_the_null_arm_never_ignores_their_engine() -> void:
	var ai := _ai(false)
	put_battlefield(1, "Damping Engine")
	put_battlefield(1, "Forest")
	_lands(0, "Mountain", 7)
	give_hand(0, "Shivan Dragon")
	assert_eq(UT.main_action(g, ai), "")
	assert_eq(ai.act(g), "pass")


# =========================================== h5-2 the mana on the table --

func test_four_dual_lands_are_four_mana() -> void:
	var ai := _ai()
	_lands(0, "Volcanic Island", 4)
	assert_eq(UT.mana_on_table(g, ai), 4)


func test_any_color_sources_are_counted_once() -> void:
	var ai := _ai()
	put_battlefield(0, "Gaea's Cradle")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Birds of Paradise")
	assert_eq(UT.mana_on_table(g, ai), 5, "Cradle 3 (three creatures), Elves 1, Birds 1")


func test_their_city_of_brass_is_one_mana_open() -> void:
	_lands(1, "City of Brass", 2)
	assert_eq(UT.open_mana(g, 1), 2)
	_lands(1, "Volcanic Island", 1)
	assert_eq(UT.open_mana(g, 1), 3)


func test_masticore_does_not_start_pings_four_duals_cannot_finish() -> void:
	var ai := _ai()
	var masticore := put_battlefield(0, "Masticore")
	_lands(0, "Volcanic Island", 4)
	var angel := put_battlefield(1, "Serra Angel")
	assert_null(UT.option(g, ai, masticore, 0, "MAIN"), "two shots for a 4/4: no plan of its own")
	_act_all(ai)
	assert_eq(angel.damage, 0, "a ping the mana cannot follow up is a waste")


func test_masticore_does_not_start_on_three_cities() -> void:
	var ai := _ai()
	put_battlefield(0, "Masticore")
	_lands(0, "City of Brass", 3)
	var angel := put_battlefield(1, "Serra Angel")
	_act_all(ai)
	assert_eq(angel.damage, 0)
	assert_eq(g.players[0].life, 20, "no City paid for a ping that leads nowhere")


func test_a_tapped_dual_leaves_no_row_behind() -> void:
	var ai := _ai()
	var sea := put_battlefield(0, "Underground Sea")
	var sources: Array = ai._mana_sources(g)
	var plan: Array = ai._plan_taps_from(sources, ManaCost.parse("{B}"), 0)
	var rest: Array = US._rows_without(sources, plan)
	assert_false(rest.any(func(row: Array) -> bool: return row[0] == sea),
		"a land the plan taps is no mana left")


func test_yawgmoths_will_counts_the_duals_it_taps() -> void:
	var ai := _ai()
	_lands(0, "Underground Sea", 3)
	var will := give_hand(0, "Yawgmoth's Will")
	_graveyard(0, "Hypnotic Specter")
	_graveyard(0, "Sengir Vampire")
	assert_eq(US.graveyard_replay(g, ai, will), {}, "three lands, all tapped for the Will")
	_act_all(ai)
	assert_eq(will.zone, Mtg.Zone.HAND, "never cast with nothing left to replay")


func test_memory_jar_reads_two_duals_as_two_mana() -> void:
	var ai := _ai()
	put_battlefield(0, "Memory Jar")
	_lands(0, "Volcanic Island", 2)
	_restack(0, ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest",
		"Forest", "Forest", "Forest", "Forest", "Forest", "Forest"])
	assert_eq(US.memory_jar(g, ai, "MAIN"), {}, "two mana puts no fresh seven to work")


func test_the_echo_payment_reads_the_lands_it_taps_as_gone() -> void:
	var ai := _ai()
	_lands(0, "Volcanic Island", 3)
	var ogre := give_hand(0, "Gray Ogre")
	assert_gt(US._cast_lost(g, ai, ManaCost.parse("{1}")),
		0.0, "the {1} leaves two lands: the Ogre is the cast it costs")
	assert_eq(ogre.zone, Mtg.Zone.HAND)


func test_the_untap_refund_counts_each_tapped_land_once() -> void:
	var ai := _ai()
	_lands(0, "Tundra", 4)
	var search := give_hand(0, "Frantic Search")
	give_hand(0, "Juggernaut")
	assert_eq(US.untapped_on_cast(search.data), 3)
	assert_gt(US.refund_value(g, ai, search, 3, ai._mana_sources(g)), 0.0,
		"one Tundra left cannot pay the Juggernaut; the three untapped again can")


# ========================================= h5-3 our own Damping Engine --

func test_our_own_engine_is_not_cast_ahead_on_permanents() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Forest")
	var engine := give_hand(0, "Damping Engine")
	assert_eq(US.spell_choice(g, ai, engine, 0, 0), {})
	_act_all(ai)
	assert_eq(engine.zone, Mtg.Zone.HAND, "six permanents to one: the Engine stops only us")


func test_our_own_engine_is_cast_only_when_it_binds_them() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	_lands(1, "Forest", 5)
	var engine := give_hand(0, "Damping Engine")
	assert_eq(US.spell_choice(g, ai, engine, 0, 0), {}, "five each with it: it binds nobody")
	put_battlefield(1, "Forest")
	assert_null(US.spell_choice(g, ai, engine, 0, 0), "six to five: the shared reader's cast")


func test_the_engine_cast_reads_no_hidden_zone() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	_lands(1, "Forest", 6)
	var engine := give_hand(0, "Damping Engine")
	var first: Variant = US.spell_choice(g, ai, engine, 0, 0)
	_hand(1, ["Shivan Dragon", "Serra Angel", "Forest"])
	_restack(1, ["Island", "Island"])
	_restack(0, ["Swamp", "Swamp"])
	assert_eq(US.spell_choice(g, ai, engine, 0, 0), first)


func test_the_null_arm_reads_no_engine() -> void:
	var ai := _ai(false)
	_lands(0, "Mountain", 4)
	put_battlefield(1, "Forest")
	var engine := give_hand(0, "Damping Engine")
	assert_null(US.spell_choice(g, ai, engine, 0, 0))


# ============================================== h5-4 their Veiled Sentry --

func test_no_six_six_for_them_at_ten_life_against_four_power() -> void:
	var ai := _ai()
	g.players[0].life = 10
	put_battlefield(1, "Veiled Sentry")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Savannah Lions")
	_lands(0, "Swamp", 6)
	var bargain := give_hand(0, "Yawgmoth's Bargain")
	_act_all(ai)
	assert_eq(bargain.zone, Mtg.Zone.HAND, "a 6/6 for them is their lethal swing")


func test_the_sentry_charges_what_the_cast_adds_over_the_cheapest_wake() -> void:
	var ai := _ai()
	put_battlefield(1, "Veiled Sentry")
	var bargain := give_hand(0, "Yawgmoth's Bargain")
	var bolt := give_hand(0, "Lightning Bolt")
	# A 1/1 is the price of playing at all (a share of it); the 6/6 is five
	# points of body beyond it, ours to avoid by casting the Bolt first.
	assert_gt(US.awakened_worth(g, ai, bargain), 7.0)
	assert_almost_eq(US.awakened_worth(g, ai, bolt), 0.6, 0.01)


func test_a_wake_is_not_refused_when_their_board_is_lethal_already() -> void:
	var ai := _ai()
	g.players[0].life = 3
	put_battlefield(1, "Veiled Sentry")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Savannah Lions")
	var bolt := give_hand(0, "Lightning Bolt")
	assert_lt(US.awakened_worth(g, ai, bolt), 5.0, "the wake does not make their swing lethal")


func test_the_sentry_reads_no_hidden_zone() -> void:
	var ai := _ai()
	g.players[0].life = 10
	put_battlefield(1, "Veiled Sentry")
	put_battlefield(1, "Grizzly Bears")
	var bargain := give_hand(0, "Yawgmoth's Bargain")
	var first := US.awakened_worth(g, ai, bargain)
	_hand(1, ["Shivan Dragon", "Lightning Bolt"])
	_restack(1, ["Serra Angel", "Island"])
	assert_eq(US.awakened_worth(g, ai, bargain), first)


func test_the_null_arm_charges_no_wake() -> void:
	var ai := _ai(false)
	g.players[0].life = 10
	put_battlefield(1, "Veiled Sentry")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Savannah Lions")
	var bargain := give_hand(0, "Yawgmoth's Bargain")
	assert_eq(US.cast_adjustment(g, ai, bargain, ai._mana_sources(g)), 0.0)


# ================================================ h5-5 the repeat pings --

func test_splintering_wind_is_not_a_repeat_ping() -> void:
	CardPacks.set_enabled("pack-5", true)
	var wind := CardRegistry.get_card("Splintering Wind")
	assert_false(UT.repeat_ping(wind.activated_abilities[0]), "its Splinters do more than damage")
	assert_true(UT.repeat_ping(CardRegistry.get_card("Masticore").activated_abilities[0]))


func test_splintering_wind_mints_no_splinters_for_a_ping_plan() -> void:
	CardPacks.set_enabled("pack-5", true)
	var ai := _ai()
	put_battlefield(0, "Splintering Wind")
	_lands(0, "Forest", 9)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var lines := _act_all(ai, 8)
	assert_lte(_count(0, func(p: CardInstance) -> bool: return p.data.card_name == "Splinter"), 1,
		"each Splinter costs us a point and a point to each of our creatures: %s" % [lines])


func test_a_ping_that_costs_a_counter_is_not_a_repeat_ping() -> void:
	CardPacks.set_enabled("pack-9", true)
	var hydra := CardRegistry.get_card("Spitting Hydra")
	assert_false(UT.repeat_ping(hydra.activated_abilities[0]), "each ping shrinks the Hydra")
