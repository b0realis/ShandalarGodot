extends GameTest
## CARD-COMBOS (2026-10-19, `engine/ai/card_combos.gd`,
## [member AiProfile.plays_combos]). The owner: *"lets teach the combos but
## also strengthen the AI engine to discover such things. Lets have a
## dedicated CARD-COMBOS in AI source code that is dedicated to potential
## card combos and their effective play!"*
##
## Five parts, each under both rules presets where the rules could differ:
##  1. THE LOOPS BY HAND — every catalogued loop played through the public
##     engine API, so the catalogue never names a loop the engine cannot run.
##  2. THE SEARCH — it finds every catalogued loop with no catalogue at all,
##     finds one nobody wrote down (synthetic cards), and refuses what only
##     looks like a loop: Corpse Dance + Workhorse + Ashnod's Altar, Wall of
##     Blossoms with one Man-o'-War, a Basalt Monolith alone, the Queen and
##     the Altar without Heartstone. It keeps to its budget, leaves the game
##     as it found it and never casts a card it cannot see.
##  3. THE PLAY — the pilot runs each loop for a purpose (a swarm, a lethal
##     X, lethal damage, twenty life, the hand's mana), never past its cap,
##     once a turn; a whole game with loops on both sides ends.
##  4. ASSEMBLY — the completing piece first, the loop's own cast card held,
##     a piece kept from a discard and from a cost.
##  5. DEFENCE — their live loop's pieces are the removal target, the spell
##     that completes it clears every counter bar, and a loop that needs a
##     hidden card is never more than near.
## And the arrival size the same day's ruling asked for: a creature card is
## sized by the +1/+1 counters it enters with.

const CC := preload("res://engine/ai/card_combos.gd")
const PACKS := ["pack-3", "pack-5", "pack-6", "pack-8", "pack-9"]
const PRESETS := ["modern", "fifth"]


## A card ask answered with the first candidate named in [member picks].
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for wanted in picks:
			for c in candidates:
				if c.data.card_name == wanted:
					return c
		return super(game, pid, candidates, prompt)


## The packs are switched ONCE for the script: every switch rebuilds the
## card pool, and switching per test was three seconds a test.
func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in PACKS)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)


func _seat(picks: Array[String]) -> Seat:
	var seat := Seat.new()
	seat.picks = picks
	g.set_agent(0, seat)
	return seat


func _pool(pid := 0) -> int:
	return g.players[pid].mana_pool.total()


func _tokens(pid := 0) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_token:
			n += 1
	return n


func _lands(pid: int, card_name: String, n: int) -> void:
	for i in n:
		put_battlefield(pid, card_name)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func _free_row(inst: CardInstance) -> int:
	var rows := g.payment_rows(0, inst)
	for i in rows.size():
		if String((rows[i] as Dictionary).get("label", "")).contains("Aluren"):
			return i
	return -1


## Power Artifact cast onto [param host] the way a player casts it.
func _power(host: CardInstance) -> CardInstance:
	var aura := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, "Power Artifact enchants the Monolith")
	return aura


func _wizard(on := true) -> AiProfile:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.plays_combos = on
	return p


## Both seats computer pilots; seat 0's is returned.
func _pilots(on := true) -> AiPlayer:
	var ai := AiPlayer.new(0, _wizard(on))
	g.set_agent(0, ai)
	g.set_agent(1, AiPlayer.new(1, _wizard(false)))
	return ai


## Let both pilots play until seat 0's turn is over (or the game is).
## Fails the test on a runaway — a turn that never ends.
func _play_our_turn(cap := 4000) -> void:
	var a0: AiPlayer = g.agents[0]
	var a1: AiPlayer = g.agents[1]
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and rounds < cap:
		var said0 := a0.act(g)
		var said1 := a1.act(g)
		if said0 == "" and said1 == "" and not g.game_over:
			break
		rounds += 1
	assert_lt(rounds, cap, "the turn ran away")


# ============================================================ 1 the loops by hand --

func test_every_catalogued_piece_is_a_card_of_the_pool() -> void:
	for recipe in CC.RECIPES:
		for slot in recipe["slots"]:
			for card_name in slot:
				assert_not_null(CardRegistry.get_card(card_name), "%s: %s" % [recipe["name"], card_name])


func test_the_sliver_queen_engine_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_seat(["Sliver"])
		put_battlefield(0, "Heartstone")
		var queen := put_battlefield(0, "Sliver Queen")
		var altar := put_battlefield(0, "Ashnod's Altar")
		add_mana(0, Mtg.ManaColor.C, 1)
		for i in 10:
			assert_ok(g.activate_ability(0, queen, 0))
			resolve_stack()
			assert_ok(g.tap_for_mana(0, altar))
		assert_eq(_pool(), 11, "%s: {C} a round" % preset)
		assert_eq(queen.zone, Mtg.Zone.BATTLEFIELD, preset)


func test_sliver_queen_and_pandemonium_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_seat(["Sliver"])
		var queen := put_battlefield(0, "Sliver Queen")
		var altar := put_battlefield(0, "Ashnod's Altar")
		put_battlefield(0, "Pandemonium")
		add_mana(0, Mtg.ManaColor.C, 2)
		for i in 5:
			assert_ok(g.activate_ability(0, queen, 0))
			resolve_stack()
			assert_ok(g.tap_for_mana(0, altar))
		assert_eq(g.players[1].life, 15, "%s: a damage a round" % preset)
		assert_eq(_pool(), 2, "%s: mana-neutral" % preset)


func test_earthcraft_slivers_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_seat(["Sliver"])
		put_battlefield(0, "Heartstone")
		var queen := put_battlefield(0, "Sliver Queen")
		var craft := put_battlefield(0, "Earthcraft")
		var forest := put_battlefield(0, "Forest")
		for i in 5:
			assert_ok(g.tap_for_mana(0, forest))
			assert_ok(g.activate_ability(0, queen, 0))
			resolve_stack()
			assert_ok(g.activate_ability(0, craft, 0, [TargetRef.card(forest)]))
			resolve_stack()
		assert_eq(_tokens(), 5, "%s: a Sliver a round" % preset)
		assert_false(forest.tapped, preset)
		assert_false(queen.tapped, "%s: the Slivers paid Earthcraft" % preset)


func test_free_man_o_war_with_soul_warden_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_seat(["Man-o'-War"])
		put_battlefield(0, "Aluren")
		put_battlefield(0, "Soul Warden")
		var jelly := give_hand(0, "Man-o'-War")
		for i in 10:
			assert_ok(g.cast_spell(0, jelly, [], 0, _free_row(jelly)))
			resolve_stack()
		assert_eq(g.players[0].life, 30, "%s: a life a round" % preset)
		assert_eq(jelly.zone, Mtg.Zone.HAND, "%s: it returned itself" % preset)


func test_free_shrieking_drake_with_pandemonium_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_seat(["Shrieking Drake"])
		put_battlefield(0, "Aluren")
		put_battlefield(0, "Pandemonium")
		var drake := give_hand(0, "Shrieking Drake")
		for i in 5:
			assert_ok(g.cast_spell(0, drake, [], 0, _free_row(drake)))
			resolve_stack()
		assert_eq(g.players[1].life, 15, "%s: a damage a round" % preset)
		assert_eq(drake.zone, Mtg.Zone.HAND, preset)


func test_renewed_thopter_by_hand() -> void:
	for preset in PRESETS:
		for outlet in ["Ashnod's Altar", "Goblin Bombardment"]:
			_fresh(preset)
			_seat(["Ornithopter"])
			put_battlefield(0, "Enduring Renewal")
			var sac := put_battlefield(0, outlet)
			var bird := give_hand(0, "Ornithopter")
			for i in 5:
				assert_ok(g.cast_spell(0, bird, [], 0, 0))
				resolve_stack()
				if outlet == "Ashnod's Altar":
					assert_ok(g.tap_for_mana(0, sac))
				else:
					assert_ok(g.activate_ability(0, sac, 0, [TargetRef.player(1)]))
				resolve_stack()
				assert_eq(bird.zone, Mtg.Zone.HAND, "%s %s: Enduring Renewal returned it" % [preset, outlet])
			if outlet == "Ashnod's Altar":
				assert_eq(_pool(), 10, "%s: {C}{C} a round" % preset)
			else:
				assert_eq(g.players[1].life, 15, "%s: a damage a round" % preset)


func test_the_powered_monolith_by_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var mono := put_battlefield(0, "Basalt Monolith")
		_power(mono)
		for i in 5:
			assert_ok(g.tap_for_mana(0, mono))
			assert_ok(g.activate_ability(0, mono, 0))
			resolve_stack()
		assert_eq(_pool(), 10, "%s: {C}{C} a round" % preset)
		assert_false(mono.tapped, preset)


# ================================================================== 2 the search --

## Each catalogued board, and the gain its loop makes.
func _board(which: String) -> String:
	match which:
		"queen":
			put_battlefield(0, "Heartstone")
			put_battlefield(0, "Sliver Queen")
			put_battlefield(0, "Ashnod's Altar")
			return "mana"
		"queen_pandemonium":
			put_battlefield(0, "Sliver Queen")
			put_battlefield(0, "Ashnod's Altar")
			put_battlefield(0, "Pandemonium")
			return "damage"
		"earthcraft":
			put_battlefield(0, "Heartstone")
			put_battlefield(0, "Sliver Queen")
			put_battlefield(0, "Earthcraft")
			put_battlefield(0, "Forest")
			return "tokens"
		"warden":
			put_battlefield(0, "Aluren")
			put_battlefield(0, "Soul Warden")
			give_hand(0, "Man-o'-War")
			return "life"
		"drake":
			put_battlefield(0, "Aluren")
			put_battlefield(0, "Pandemonium")
			give_hand(0, "Shrieking Drake")
			return "damage"
		"thopter_altar":
			put_battlefield(0, "Enduring Renewal")
			put_battlefield(0, "Ashnod's Altar")
			give_hand(0, "Ornithopter")
			return "mana"
		"thopter_bombardment":
			put_battlefield(0, "Enduring Renewal")
			put_battlefield(0, "Goblin Bombardment")
			give_hand(0, "Ornithopter")
			return "damage"
		"monolith":
			_power(put_battlefield(0, "Basalt Monolith"))
			return "mana"
	return ""


func test_the_open_search_finds_every_catalogued_loop() -> void:
	for preset in PRESETS:
		for which in ["queen", "queen_pandemonium", "earthcraft", "warden", "drake",
				"thopter_altar", "thopter_bombardment", "monolith"]:
			_fresh(preset)
			var gain := _board(which)
			var loop := CC.find_loop(g, 0, {}, 96)
			assert_false(loop.is_empty(), "%s %s: found with no catalogue" % [preset, which])
			if loop.is_empty():
				continue
			assert_gt(int(loop["gains"][gain]), 0, "%s %s: gains %s" % [preset, which, gain])


func test_the_catalogue_focuses_the_search() -> void:
	_board("queen")
	var focus := CC.assembled_focus(g, 0)
	assert_true(focus.has("Ashnod's Altar"))
	var loop := CC.find_loop(g, 0, focus, CC.FOCUS_NODES)
	assert_false(loop.is_empty())
	assert_lte(CC.last_nodes, CC.FOCUS_NODES)


## "{1}: Create a 1/1 colourless Test Spark" and "Sacrifice a creature: Add
## {C}{C}" — the Queen engine under names the catalogue has never seen.
func test_the_search_finds_a_loop_nobody_wrote_down() -> void:
	for preset in PRESETS:
		_fresh(preset)
		var forge := CardData.new("Test Spark Forge", "{3}", Mtg.CardType.ARTIFACT) \
			.activated(ActivatedAbility.new("{1}", false,
				[CreateTokenEffect.new("Test Spark", 1, 1, 0, "spark")], "{1}: Create a 1/1 Test Spark."))
		var crucible := CardData.new("Test Crucible", "{3}", Mtg.CardType.ARTIFACT) \
			.mana(ManaAbility.new(Mtg.ManaColor.C, 2).without_tap() \
				.with_sacrifice_of("creature", func(i: CardInstance) -> bool: return i.is_creature()))
		put_synthetic(0, forge)
		put_synthetic(0, crucible)
		assert_true(CC.pieces_of("Test Spark Forge").is_empty(), "not catalogued")
		var loop := CC.find_loop(g, 0, {}, 96)
		assert_false(loop.is_empty(), preset)
		if not loop.is_empty():
			assert_eq(int(loop["gains"]["mana"]), 1, "%s: {C} a round" % preset)


func test_the_search_finds_a_real_loop_the_catalogue_does_not_name() -> void:
	# Sliver Queen + Ashnod's Altar is mana-neutral; Soul Warden makes every
	# Sliver a life.
	put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Ashnod's Altar")
	put_battlefield(0, "Soul Warden")
	assert_true(CC.assembled_focus(g, 0).is_empty(), "no recipe is whole")
	var loop := CC.find_loop(g, 0, {}, 96)
	assert_false(loop.is_empty())
	if not loop.is_empty():
		assert_eq(int(loop["gains"]["life"]), 1)


## A free ability is a loop; the same ability once a turn only looks like
## one for one round — the second round, which every loop must pay for
## itself, is refused.
func test_a_line_must_come_round_twice() -> void:
	var free_life := func(per_turn: int) -> CardData:
		var ability := ActivatedAbility.new("{0}", false, [GainLifeEffect.new(1)], "{0}: You gain 1 life.")
		if per_turn > 0:
			ability.per_turn(per_turn)
		return CardData.new("Test Fountain %d" % per_turn, "{1}", Mtg.CardType.ARTIFACT).activated(ability)
	put_synthetic(0, free_life.call(0))
	var loop := CC.find_loop(g, 0, {}, 32)
	assert_false(loop.is_empty(), "unlimited: a loop")
	before_each()
	put_synthetic(0, free_life.call(1))
	assert_true(CC.find_loop(g, 0, {}, 32).is_empty(), "once a turn: no loop")


func test_the_search_refuses_what_is_no_loop() -> void:
	for preset in PRESETS:
		# Corpse Dance with buyback is {4}{B}; the Workhorse and the Altar
		# make colourless only.
		_fresh(preset)
		put_battlefield(0, "Ashnod's Altar")
		_to_graveyard(0, "Workhorse")
		give_hand(0, "Corpse Dance")
		_lands(0, "Swamp", 5)
		assert_true(CC.find_loop(g, 0, {}, 400, 6).is_empty(), "%s: Corpse Dance" % preset)
		# Two draws, then the Man-o'-War stays on the table.
		_fresh(preset)
		put_battlefield(0, "Aluren")
		give_hand(0, "Wall of Blossoms")
		give_hand(0, "Man-o'-War")
		assert_true(CC.find_loop(g, 0, {}, 400, 5).is_empty(), "%s: Wall of Blossoms" % preset)
		# Tap for three, untap for three.
		_fresh(preset)
		put_battlefield(0, "Basalt Monolith")
		assert_true(CC.find_loop(g, 0, {}, 400, 5).is_empty(), "%s: Basalt Monolith alone" % preset)
		# {2} a Sliver, {C}{C} for it: neutral, and nothing else gained.
		_fresh(preset)
		put_battlefield(0, "Sliver Queen")
		put_battlefield(0, "Ashnod's Altar")
		assert_true(CC.find_loop(g, 0, {}, 400, 5).is_empty(), "%s: no Heartstone" % preset)
		# A discard is a cost the walk does not count, and the Tome costs four.
		_fresh(preset)
		put_battlefield(0, "Mind Over Matter")
		put_battlefield(0, "Jayemdae Tome")
		put_battlefield(0, "Basalt Monolith")
		for i in 3: give_hand(0, "Grizzly Bears")
		assert_true(CC.find_loop(g, 0, {}, 400, 5).is_empty(), "%s: Mind Over Matter" % preset)


func test_an_ordinary_board_is_never_searched() -> void:
	var ai := _pilots()
	_lands(0, "Mountain", 4)
	put_battlefield(0, "Shivan Dragon")
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Hill Giant")
	assert_eq(int(CC._motors(g, 0)["recyclers"]), 0, "a firebreather recycles nothing")
	CC.last_nodes = -1
	CC.main_action(g, ai)
	assert_eq(CC.last_nodes, -1, "no walk was taken")


func test_the_search_keeps_to_its_budget() -> void:
	put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Ashnod's Altar")
	put_battlefield(0, "Basalt Monolith")
	put_battlefield(0, "Shivan Dragon")
	_lands(0, "Forest", 3)
	CC.find_loop(g, 0, {}, 20)
	assert_lte(CC.last_nodes, 30, "twenty, and half again for the second walk at most")
	assert_gt(CC.last_nodes, 0)


func test_the_search_leaves_the_game_as_it_found_it() -> void:
	var ai := _pilots()
	_board("warden")
	_lands(0, "Island", 2)
	var state := g.rng.state
	var life := g.players[0].life
	var hand: Array[int] = []
	for c in g.players[0].hand: hand.append(c.id)
	var top := g.players[0].library.back() as CardInstance
	var table := g.players[0].battlefield.size()
	assert_false(CC.find_loop(g, 0, {}, 96).is_empty())
	assert_eq(g.rng.state, state, "the random stream")
	assert_eq(g.players[0].life, life)
	var after: Array[int] = []
	for c in g.players[0].hand: after.append(c.id)
	assert_eq(after, hand)
	assert_eq(g.players[0].library.back(), top)
	assert_eq(g.players[0].battlefield.size(), table)
	assert_eq(_pool(), 0, "the loan went back")
	assert_eq(g.agents[0], ai, "our seat is ours again")
	assert_false(g.probe_target_pick.is_valid())
	assert_null(g.undo_log, "the search is closed")


func test_the_search_never_casts_a_card_it_cannot_see() -> void:
	# The Man-o'-War that makes the loop is on top of OUR library and in
	# THEIR hand — neither is ours to cast.
	put_battlefield(0, "Aluren")
	put_battlefield(0, "Soul Warden")
	var ours := _make_instance(0, "Man-o'-War")
	ours.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(ours)
	give_hand(1, "Man-o'-War")
	assert_true(CC.find_loop(g, 0, {}, 96).is_empty())
	# A loop of theirs is not ours either.
	assert_true(CC.assembled_focus(g, 0).is_empty())


# ==================================================================== 3 the play --

func test_the_queen_engine_makes_a_swarm() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilots()
		_board("queen")
		put_battlefield(0, "Plains")
		_play_our_turn()
		assert_eq(_tokens(), CC.TOKEN_TARGET, "%s: a swarm" % preset)
		assert_eq(g.players[0].life, 20, "%s: the mana made was the mana spent" % preset)


func test_the_queen_engine_feeds_a_lethal_disintegrate() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilots()
		_board("queen")
		put_battlefield(0, "Plains")
		put_battlefield(0, "Mountain")
		give_hand(0, "Disintegrate")
		_play_our_turn()
		assert_true(g.game_over, preset)
		assert_eq(g.winner, 0, "%s: X was their life" % preset)


func test_damage_loops_burn_them_out() -> void:
	for preset in PRESETS:
		for which in ["queen_pandemonium", "drake", "thopter_bombardment"]:
			_fresh(preset)
			_pilots()
			_board(which)
			_lands(0, "Plains", 2)
			g.players[1].life = 8
			_play_our_turn()
			assert_true(g.game_over, "%s %s" % [preset, which])
			assert_eq(g.winner, 0, "%s %s" % [preset, which])


func test_free_man_o_war_buys_twenty_life_once_a_turn() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilots()
		_board("warden")
		put_battlefield(0, "Island")
		_play_our_turn()
		assert_eq(g.players[0].life, 20 + CC.LIFE_STEP, "%s: twenty more, and not twice" % preset)


func test_free_man_o_war_with_pandemonium_kills() -> void:
	_pilots()
	put_battlefield(0, "Aluren")
	put_battlefield(0, "Pandemonium")
	give_hand(0, "Man-o'-War")
	g.players[1].life = 10
	_play_our_turn()
	assert_eq(g.winner, 0, "two a round")


func test_renewed_thopter_and_the_altar_pay_for_the_hand() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilots()
		_board("thopter_altar")
		var juggernaut := give_hand(0, "Juggernaut")
		_play_our_turn()
		assert_eq(juggernaut.zone, Mtg.Zone.BATTLEFIELD, "%s: four from the loop" % preset)
		assert_eq(g.players[0].life, 20, "%s: nothing left to burn" % preset)


func test_the_powered_monolith_feeds_a_lethal_disintegrate() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_board("monolith")
		_pilots()
		put_battlefield(0, "Mountain")
		give_hand(0, "Disintegrate")
		g.players[1].life = 30
		_play_our_turn()
		assert_eq(g.winner, 0, preset)


func test_earthcraft_slivers_make_a_swarm() -> void:
	for preset in PRESETS:
		_fresh(preset)
		_pilots()
		_board("earthcraft")
		_play_our_turn()
		assert_eq(_tokens(), CC.TOKEN_TARGET, preset)


func test_a_run_never_outlasts_its_cap() -> void:
	_pilots()
	put_battlefield(0, "Sliver Queen", true)   # sick: no attack muddies the count
	put_battlefield(0, "Ashnod's Altar")
	put_battlefield(0, "Pandemonium")
	_lands(0, "Plains", 2)
	g.players[1].life = 999
	_play_our_turn()
	assert_eq(g.players[1].life, 999 - CC.MAX_ROUNDS)


func test_a_game_with_a_loop_on_each_side_ends() -> void:
	for pid in 2:
		put_battlefield(pid, "Heartstone")
		put_battlefield(pid, "Sliver Queen")
		put_battlefield(pid, "Ashnod's Altar")
		_lands(pid, "Plains", 2)
	var a0 := AiPlayer.new(0, _wizard())
	var a1 := AiPlayer.new(1, _wizard())
	g.set_agent(0, a0)
	g.set_agent(1, a1)
	assert_true(AiPlayer.play_out(g, a0, a1, 20000), "it ended")


func test_without_the_knob_the_pilot_plays_as_before() -> void:
	_pilots(false)
	_board("queen")
	put_battlefield(0, "Plains")
	_play_our_turn()
	assert_lte(_tokens(), 1, "one Sliver from the one land, the Altar untouched")


# ===================================================================== 4 assembly --

func test_the_piece_that_completes_a_loop_is_cast_first() -> void:
	var ai := _pilots()
	put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Ashnod's Altar")
	_lands(0, "Mountain", 4)
	give_hand(0, "Hill Giant")
	give_hand(0, "Heartstone")
	assert_string_contains(ai.act(g), "Heartstone")


func test_the_card_a_loop_casts_is_held_for_it() -> void:
	for on in [true, false]:
		before_each()
		_pilots(on)
		put_battlefield(0, "Soul Warden")
		_lands(0, "Island", 3)
		give_hand(0, "Aluren")       # {2}{G}{G}: not castable yet
		var jelly := give_hand(0, "Man-o'-War")
		put_battlefield(1, "Grizzly Bears")
		_play_our_turn()
		if on:
			assert_eq(jelly.zone, Mtg.Zone.HAND, "held for the Aluren")
		else:
			assert_ne(jelly.zone, Mtg.Zone.HAND, "the null arm bounces the Bears")


func test_a_piece_in_reach_is_kept() -> void:
	var ai := _pilots()
	var stone := give_hand(0, "Heartstone")
	assert_eq(CC.keep_value(g, ai, stone), 0.0, "nothing else in reach")
	var queen := put_battlefield(0, "Sliver Queen")
	assert_eq(CC.keep_value(g, ai, stone), CC.KEEP_WORTH, "two of three")
	put_battlefield(0, "Ashnod's Altar")
	assert_eq(CC.keep_value(g, ai, stone), CC.KEEP_WORTH * 2.0, "the whole loop")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Grizzly Bears")
	var gone := ai.answer_discard(g, 0, 1)
	assert_eq(gone.size(), 1)
	assert_ne(gone[0], stone, "a Bears goes, not the Heartstone")
	var off := AiPlayer.new(0, _wizard(false))
	assert_almost_eq(ai._own_value(g, queen) - off._own_value(g, queen), CC.KEEP_WORTH * 2.0, 0.001,
		"the Queen is not the body a cost eats")


# ====================================================================== 5 defence --

func test_their_live_loop_is_the_removal_target() -> void:
	var ai := _pilots()
	var off := AiPlayer.new(0, _wizard(false))
	put_battlefield(1, "Sliver Queen")
	put_battlefield(1, "Heartstone")
	var altar := put_battlefield(1, "Ashnod's Altar")
	var tome := put_battlefield(1, "Jayemdae Tome")
	assert_almost_eq(ai._victim_value(g, altar) - off._victim_value(g, altar), CC.THREAT_LIVE, 0.001)
	assert_gt(ai._victim_value(g, altar), ai._victim_value(g, tome), "the Altar before the Tome")
	assert_almost_eq(off._victim_value(g, tome), ai._victim_value(g, tome), 0.001, "the Tome is no piece")


func test_the_spell_that_completes_their_loop_clears_every_bar() -> void:
	put_battlefield(1, "Sliver Queen")
	put_battlefield(1, "Ashnod's Altar")
	advance_to_next_turn()   # their main phase: an artifact is cast at sorcery speed
	assert_eq(g.active_player, 1)
	var stone := give_hand(1, "Heartstone")
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, stone))
	var top := g.stack.back() as StackItem
	var magician := AiProfile.magician()
	magician.mistake_chance = 0.0
	var ai := AiPlayer.new(0, magician)
	assert_true(ai._counter_clears_bar(g, top), "the last piece, at the Magician's bar")
	magician.plays_combos = false
	assert_false(ai._counter_clears_bar(g, top), "a {3} artifact alone is under it")


func test_a_loop_that_needs_a_hidden_card_is_never_more_than_near() -> void:
	var ai := _pilots()
	var aluren := put_battlefield(1, "Aluren")
	put_battlefield(1, "Soul Warden")
	assert_eq(CC.threat_value(g, ai, aluren), CC.THREAT_NEAR, "the Man-o'-War may not be in their hand")


# ================================================================ the arrival size --

func test_a_creature_card_is_sized_as_it_arrives() -> void:
	var horse := CardRegistry.get_card("Workhorse")
	assert_eq(Evaluator.arrival_power(horse), 4)
	assert_eq(Evaluator.arrival_toughness(horse), 4)
	assert_eq(Evaluator.card_value(horse), 8.0, "a 4/4, not a 0/0")
	assert_eq(Evaluator.card_value(CardRegistry.get_card("Spike Feeder")), 4.0)
	assert_eq(Evaluator.card_value(CardRegistry.get_card("Triskelion")), 8.0, "1/1 and three counters")
	assert_eq(Evaluator.card_value(CardRegistry.get_card("Grizzly Bears")), 4.0, "no counters, as printed")


func test_a_pinger_answers_the_elf_not_the_spike() -> void:
	var ai := _pilots()
	put_battlefield(1, "Prodigal Sorcerer")
	assert_true(ai._answered_on_arrival(g, CardRegistry.get_card("Llanowar Elves")), "a 1/1")
	assert_false(ai._answered_on_arrival(g, CardRegistry.get_card("Spike Feeder")), "it arrives a 2/2")
