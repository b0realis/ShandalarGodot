extends GameTest
## THE AI SEAT THROUGH THE SHARED PLANNER (whole-game campaign, 2026-10-07 —
## `engine/mana_planner.gd`, the tap line of `AiPlayer._try_cast_best`).
## Every test runs under both presets that burn (CR 500.4 as printed in
## 1997: `modern_mana_burn`, the shipped default, and `fifth`).
##
## w6-1: the Wizard paid a {1} with a Sol Ring or a Mana Vault while a basic
## land stood untapped, and burned the rest (392 life in 300 tournament
## duels). w1-1: under a Mana Flare it tapped one Mountain per pip of a Hill
## Giant, made eight red and burned four — at 5 life, a Disintegrate and a
## second Flare burned it for 11. w1-2: it tapped the Forest wearing the
## opponent's Psychic Venom, Blight or Kudzu while plain Forests stood.
##
## The planner reads only the public board — the auras on its own lands,
## the untap locks, the triggers on the battlefield — so the last test
## swaps the opponent's hidden hand and library and pins the same taps.

const PRESETS := ["modern_mana_burn", "fifth"]


func _wizard(seat: int) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _act_until(ai: AiPlayer, card_name: String) -> void:
	var guard := 0
	while guard < 8:
		var did := ai.act(g)
		resolve_stack()
		guard += 1
		if did == "" or did == "pass" or _on_battlefield(0, card_name):
			break


func _on_battlefield(pid: int, card_name: String) -> bool:
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return true
	return false


func _tapped(pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name and inst.tapped:
			n += 1
	return n


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.priority_player, 1)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ================================ w1-1: Mana Flare ================================

func test_hill_giant_under_mana_flare_taps_two_mountains_and_burns_nothing() -> void:
	for preset in PRESETS:
		before_each()
		g.rules.set_preset(preset)
		var ai := _wizard(0)
		put_battlefield(0, "Mana Flare")
		for _i in 4:
			put_battlefield(0, "Mountain")
		give_hand(0, "Hill Giant")
		advance_to_step(Mtg.Step.MAIN1)
		_act_until(ai, "Hill Giant")
		assert_true(_on_battlefield(0, "Hill Giant"), "%s: Hill Giant cast" % preset)
		assert_eq(_tapped(0, "Mountain"), 2, preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_eq(g.players[0].life, 20, "%s: nothing burned" % preset)


func test_at_three_life_the_flare_does_not_burn_the_wizard_to_death() -> void:
	for preset in PRESETS:
		before_each()
		g.rules.set_preset(preset)
		var ai := _wizard(0)
		g.players[0].life = 3
		put_battlefield(0, "Mana Flare")
		for _i in 6:
			put_battlefield(0, "Mountain")
		give_hand(0, "Hill Giant")
		advance_to_step(Mtg.Step.MAIN1)
		_act_until(ai, "Hill Giant")
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_false(g.game_over, preset)
		assert_eq(g.players[0].life, 3, preset)


func test_their_mana_flare_is_paid_through_too() -> void:
	# The Flare is symmetric: the opponent's doubles our Mountains as well.
	for preset in PRESETS:
		before_each()
		g.rules.set_preset(preset)
		var ai := _wizard(0)
		put_battlefield(1, "Mana Flare")
		for _i in 4:
			put_battlefield(0, "Mountain")
		give_hand(0, "Hill Giant")
		advance_to_step(Mtg.Step.MAIN1)
		_act_until(ai, "Hill Giant")
		assert_true(_on_battlefield(0, "Hill Giant"), preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_eq(g.players[0].life, 20, "%s: nothing burned" % preset)


# ============================ w6-1: the least surplus ============================

func test_icy_at_their_upkeep_is_paid_with_the_island_not_the_mana_vault() -> void:
	for preset in PRESETS:
		before_each()
		g.rules.set_preset(preset)
		var ai := _wizard(0)
		put_battlefield(0, "Icy Manipulator")
		var vault := put_battlefield(0, "Mana Vault")
		var island := put_battlefield(0, "Island")
		put_battlefield(1, "Serra Angel")
		advance_to_step(Mtg.Step.MAIN1)
		_their_turn_at(Mtg.Step.UPKEEP)
		var did := ai.act(g)
		assert_string_contains(did, "Icy Manipulator", preset)
		assert_false(vault.tapped, "%s: the Vault stays untapped" % preset)
		assert_true(island.tapped, preset)
		var life := g.players[0].life
		resolve_stack()
		while g.current_step() == Mtg.Step.UPKEEP and not g.game_over:
			assert_ok(g.pass_priority(g.priority_player))
		assert_eq(g.players[0].life, life, "%s: no burn for a {1} with an Island open" % preset)


func test_a_one_drop_is_paid_with_the_mountain_not_the_sol_ring() -> void:
	for preset in PRESETS:
		for ring_first in [true, false]:
			before_each()
			g.rules.set_preset(preset)
			var ai := _wizard(0)
			var ring: CardInstance = null
			if ring_first:
				ring = put_battlefield(0, "Sol Ring")
			var mountain := put_battlefield(0, "Mountain")
			if not ring_first:
				ring = put_battlefield(0, "Sol Ring")
			give_hand(0, "Black Vise")   # {1}
			advance_to_step(Mtg.Step.MAIN1)
			var did := ai.act(g)
			assert_string_contains(did, "Black Vise", preset)
			assert_true(mountain.tapped, preset)
			assert_false(ring.tapped, preset)
			assert_eq(g.players[0].mana_pool.total(), 0, "%s: nothing floats" % preset)


# ================================ w1-2: tap tolls ================================

func test_the_wizard_spares_its_cursed_forest() -> void:
	for aura_name in ["Psychic Venom", "Blight", "Kudzu"]:
		for preset in PRESETS:
			before_each()
			g.rules.set_preset(preset)
			var ai := _wizard(0)
			var cursed := put_battlefield(0, "Forest")   # first in battlefield order
			put_battlefield(0, "Forest")
			put_battlefield(0, "Forest")
			var aura := _make_instance(1, aura_name)
			g.attach_aura_from_anywhere(aura, cursed, 1)
			give_hand(0, "Grizzly Bears")
			advance_to_step(Mtg.Step.MAIN1)
			_act_until(ai, "Grizzly Bears")
			assert_true(_on_battlefield(0, "Grizzly Bears"), "%s %s" % [aura_name, preset])
			assert_false(cursed.tapped, "%s %s" % [aura_name, preset])
			assert_eq(cursed.zone, Mtg.Zone.BATTLEFIELD, "%s %s" % [aura_name, preset])
			assert_eq(g.players[0].life, 20, "%s %s" % [aura_name, preset])


# ======================== fair play: hidden information ========================

func test_the_taps_ignore_the_opponents_hidden_hand_and_library() -> void:
	var seen: Array = []
	for variant in 2:
		before_each()
		g.rules.set_preset("modern_mana_burn")
		var ai := _wizard(0)
		put_battlefield(0, "Sol Ring")
		put_battlefield(0, "Mountain")
		var cursed := put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		g.attach_aura_from_anywhere(_make_instance(1, "Psychic Venom"), cursed, 1)
		give_hand(0, "Black Vise")
		# The hidden permutation: their hand and their library's order.
		for card_name in (["Lightning Bolt", "Counterspell"] if variant == 0
				else ["Island", "Mountain"]):
			give_hand(1, card_name)
		if variant == 1:
			g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		var taps: Array = []
		for inst in g.players[0].battlefield:
			taps.append([inst.data.card_name, inst.tapped])
		seen.append(taps)
	assert_eq(seen[0], seen[1], "the same taps whatever they hold")
