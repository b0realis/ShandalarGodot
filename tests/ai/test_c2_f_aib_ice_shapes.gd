extends GameTest
## THE SHAPES NO READER READ (bug-hunt campaign 2026-10-12, b4-3 / b4-4;
## engine/ai/ice_age_tactics.gd `role_option` / `role_spell_choice`,
## engine/ai/alliances_tactics.gd `army_menace`, [member
## AiProfile.forecasts_tactics]).
##
## Five Ice Age effects were bare `Action`s with no declared shape and no
## reader, so the pilot never used them — not even for the game: Gangrenous
## Zombies and Time Bomb at exact lethal, Goblin Lyre with nothing to lose,
## Spoils of Evil at four life, Forgotten Lore with a stocked graveyard.
## Gorilla War Cry carried the role `army_menace` that nothing under
## engine/ai read. Pinned here, under both rules presets:
##  * each is used when it is plainly right, and kept when it is wrong;
##  * the opponent's hidden hand and both libraries' order move nothing;
##  * the gate off is the null arm (every reader answers null).

const ICE := preload("res://engine/ai/ice_age_tactics.gd")
const ALL := preload("res://engine/ai/alliances_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	CardPacks.set_enabled(AlliancesPack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)
	CardPacks.set_enabled(AlliancesPack.ID, false)


func _pilot(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## The AI seat plays its turn (and [param turns] - 1 more); the other seat
## passes, attacks with nothing and blocks the first attacker with its
## first untapped creature when that block is legal.
func _drive(ai: AiPlayer, turns := 2) -> void:
	var start := g.turn_number
	for k in 400:
		if g.game_over or g.turn_number >= start + turns:
			return
		if g.awaiting_attackers and g.active_player != ai.pid:
			g.declare_attackers(g.active_player, [])
			continue
		if g.awaiting_blockers and g.active_player == ai.pid:
			var blocks := {}
			var mine: Array = g.players[1 - ai.pid].creatures().filter(
				func(i: CardInstance) -> bool: return not i.tapped)
			if not mine.is_empty() and not g.combat.attackers.is_empty():
				blocks[mine[0].id] = g.combat.attackers.keys()[0]
			if g.declare_blockers(1 - ai.pid, blocks) != "":
				g.declare_blockers(1 - ai.pid, {})
			continue
		if g.priority_player == ai.pid or (g.awaiting_attackers and g.active_player == ai.pid) \
				or (g.awaiting_blockers and g.active_player != ai.pid):
			if ai.act(g) == "":
				if g.awaiting_attackers and g.active_player == ai.pid:
					g.declare_attackers(ai.pid, [])
				elif g.awaiting_blockers:
					g.declare_blockers(ai.pid, {})
				elif g.priority_player == ai.pid:
					g.pass_priority(ai.pid)
		else:
			g.pass_priority(g.priority_player)


func _ability_answer(ai: AiPlayer, s: CardInstance, window := "MAIN") -> Variant:
	return ICE.option(g, ai, s, 0, window)


# ------------------------------------------------- Gangrenous Zombies --

func _zombies_for_lethal(preset: String) -> void:
	g.rules.set_preset(preset)
	var z := put_battlefield(0, "Gangrenous Zombies")
	put_battlefield(0, "Snow-Covered Swamp")
	put_battlefield(1, "Wall of Stone")   # no attack gets through; only the ability wins
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot())
	assert_true(g.game_over or z.zone == Mtg.Zone.GRAVEYARD,
		"%s: 2 damage to a player at 2 life, for nothing" % preset)
	assert_eq(g.players[1].life <= 0, true, "%s: the sweep was fired, and won" % preset)


func test_gangrenous_zombies_fire_for_lethal() -> void:
	_zombies_for_lethal("modern_mana_burn")


func test_gangrenous_zombies_fire_for_lethal_under_the_1997_rules() -> void:
	_zombies_for_lethal("fifth")


func test_gangrenous_zombies_wait_when_the_sweep_only_costs_us() -> void:
	var ai := _pilot()
	var z := put_battlefield(0, "Gangrenous Zombies")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = _ability_answer(ai, z)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(),
		"one damage everywhere kills our two Elves and nothing of theirs: %s" % [got])


func test_gangrenous_zombies_sweep_their_small_creatures_at_the_sweepers_moment() -> void:
	var ai := _pilot()
	var z := put_battlefield(0, "Gangrenous Zombies")
	put_battlefield(0, "Snow-Covered Swamp")
	for n in ["Llanowar Elves", "Grizzly Bears", "Llanowar Elves"]:
		put_battlefield(1, n)
	advance_to_step(Mtg.Step.MAIN1)
	# Their three bodies die to two damage; ours only the Zombies the cost
	# sacrifices anyway. Their creatures can swing next turn, so our main
	# phase waits for their combat, the shared sweeper's moment.
	var main: Variant = _ability_answer(ai, z, "MAIN")
	assert_true(main is Dictionary and (main as Dictionary).is_empty(), "deferred: %s" % [main])
	var combat: Variant = _ability_answer(ai, z, "COMBAT")
	assert_true(combat is Dictionary and not (combat as Dictionary).is_empty(), "their combat: %s" % [combat])
	assert_gt(float(combat["value"]), 0.0)


func test_gangrenous_zombies_read_the_snow_swamp() -> void:
	var ai := _pilot()
	var z := put_battlefield(0, "Gangrenous Zombies")
	put_battlefield(1, "Wall of Stone")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	var plain: Variant = _ability_answer(ai, z)
	assert_true(plain is Dictionary and ((plain as Dictionary).is_empty()
		or float(plain["value"]) < AiPlayer.LETHAL_WORTH), "one damage does not kill at 2")
	put_battlefield(0, "Snow-Covered Swamp")
	var snow: Variant = _ability_answer(ai, z)
	assert_true(snow is Dictionary and not (snow as Dictionary).is_empty())
	assert_gte(float(snow["value"]), AiPlayer.LETHAL_WORTH, "two damage with a snow Swamp kills at 2")


# ---------------------------------------------------------- Time Bomb --

func _bomb_for_lethal(preset: String) -> void:
	g.rules.set_preset(preset)
	var bomb := put_battlefield(0, "Time Bomb")
	g.add_counters(bomb, "time", 5)
	put_battlefield(0, "Mountain")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot())
	assert_true(g.game_over or bomb.zone == Mtg.Zone.GRAVEYARD,
		"%s: five counters against five life, the AI at twenty" % preset)
	assert_true(g.players[1].life <= 0, "%s: the bomb won" % preset)


func test_time_bomb_detonates_for_lethal() -> void:
	_bomb_for_lethal("modern_mana_burn")


func test_time_bomb_detonates_for_lethal_under_the_1997_rules() -> void:
	_bomb_for_lethal("fifth")


func test_time_bomb_never_detonates_into_its_own_death() -> void:
	var ai := _pilot()
	var bomb := put_battlefield(0, "Time Bomb")
	g.add_counters(bomb, "time", 5)
	g.players[0].life = 5
	g.players[1].life = 12
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = _ability_answer(ai, bomb)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(),
		"five damage to each player kills us first: %s" % [got])


# -------------------------------------------------------- Goblin Lyre --

func _lyre_with_nothing_to_lose(preset: String) -> void:
	g.rules.set_preset(preset)
	var lyre := put_battlefield(0, "Goblin Lyre")
	for n in 5: put_battlefield(0, "Wall of Stone")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot())
	assert_true(g.game_over or lyre.zone == Mtg.Zone.GRAVEYARD,
		"%s: a 50%% win; the loss costs nothing (they have no creatures)" % preset)


func test_goblin_lyre_flips_with_nothing_to_lose() -> void:
	_lyre_with_nothing_to_lose("modern_mana_burn")


func test_goblin_lyre_flips_with_nothing_to_lose_under_the_1997_rules() -> void:
	_lyre_with_nothing_to_lose("fifth")


func test_goblin_lyre_kept_when_the_lost_flip_kills_us() -> void:
	var ai := _pilot()
	var lyre := put_battlefield(0, "Goblin Lyre")
	put_battlefield(0, "Grizzly Bears")
	for n in 4: put_battlefield(1, "Llanowar Elves")
	g.players[0].life = 3
	g.players[1].life = 20
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = _ability_answer(ai, lyre)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(),
		"one damage to them or four to us at three life: %s" % [got])


# ------------------------------------------------------ Spoils of Evil --

func _stock_their_graveyard(n: int) -> void:
	for k in n:
		var c := give_hand(1, "Grizzly Bears")
		g.discard_cards(1, [c])


func test_spoils_of_evil_cast_at_four_life() -> void:
	_stock_their_graveyard(6)
	for n in 3: put_battlefield(0, "Swamp")
	g.players[0].life = 4
	var spoils := give_hand(0, "Spoils of Evil")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot())
	assert_ne(spoils.zone, Mtg.Zone.HAND, "+6 life for one card at 4 life")
	assert_eq(g.players[0].life, 10)


func test_spoils_of_evil_is_no_gain_when_the_mana_only_burns() -> void:
	# Mana burn on, nothing in hand to spend six colourless on: the life
	# comes straight back off. Nothing gained, nothing lost — kept.
	g.rules.set_preset("modern_mana_burn")
	var ai := _pilot()
	_stock_their_graveyard(6)
	for n in 3: put_battlefield(0, "Swamp")
	g.players[0].life = 4
	var spoils := give_hand(0, "Spoils of Evil")
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = ICE.spell_choice(g, ai, spoils, 0, 0)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "all six mana would burn: %s" % [got])


func test_spoils_of_evil_spends_its_mana_under_the_1997_rules() -> void:
	g.rules.set_preset("fifth")
	_stock_their_graveyard(6)
	for n in 3: put_battlefield(0, "Swamp")
	g.players[0].life = 4
	var spoils := give_hand(0, "Spoils of Evil")
	var juggernaut := give_hand(0, "Juggernaut")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := _pilot()
	var got: Variant = ICE.spell_choice(g, ai, spoils, 0, 0)
	assert_true(got is Dictionary and not (got as Dictionary).is_empty(),
		"four of the six colourless cast the Juggernaut: %s" % [got])
	_drive(ai, 1)
	assert_ne(spoils.zone, Mtg.Zone.HAND)
	assert_eq(juggernaut.zone, Mtg.Zone.BATTLEFIELD, "the mana was spent")
	assert_gt(g.players[0].life, 4, "the gain beat the burn")


func test_spoils_of_evil_waits_for_a_graveyard() -> void:
	var ai := _pilot()
	for n in 3: put_battlefield(0, "Swamp")
	g.players[0].life = 4
	var spoils := give_hand(0, "Spoils of Evil")
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = ICE.spell_choice(g, ai, spoils, 0, 0)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "nothing to count")


# ----------------------------------------------------- Forgotten Lore --

func test_forgotten_lore_cast_with_a_stocked_graveyard() -> void:
	var angel := give_hand(0, "Serra Angel")
	var bolt := give_hand(0, "Lightning Bolt")
	g.discard_cards(0, [angel, bolt])
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var lore := give_hand(0, "Forgotten Lore")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot())
	assert_ne(lore.zone, Mtg.Zone.HAND)
	assert_true(angel.zone == Mtg.Zone.HAND or bolt.zone == Mtg.Zone.HAND, "a card came back")


func test_forgotten_lore_waits_while_only_lands_could_come_back() -> void:
	var ai := _pilot()
	var land := give_hand(0, "Forest")
	g.discard_cards(0, [land])
	put_battlefield(0, "Forest")
	var lore := give_hand(0, "Forgotten Lore")
	advance_to_step(Mtg.Step.MAIN1)
	var got: Variant = ICE.spell_choice(g, ai, lore, 0, 0)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(),
		"a card for a basic land is no trade: %s" % [got])
	var empty := give_hand(0, "Forgotten Lore")
	g.players[0].graveyard.clear()
	got = ICE.spell_choice(g, ai, empty, 0, 0)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "an empty graveyard returns nothing")


# --------------------------------------------------- Gorilla War Cry --

func _war_cry_alpha(preset: String) -> void:
	g.rules.set_preset(preset)
	for n in 3: put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 9
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var cry := give_hand(0, "Gorilla War Cry")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(_pilot(), 1)
	assert_ne(cry.zone, Mtg.Zone.HAND, "%s: menace on 9 power against one blocker and 9 life" % preset)
	assert_true(g.game_over, "%s: with the War Cry the attack is lethal" % preset)


func test_gorilla_war_cry_makes_the_alpha_lethal() -> void:
	_war_cry_alpha("modern_mana_burn")


func test_gorilla_war_cry_makes_the_alpha_lethal_under_the_1997_rules() -> void:
	_war_cry_alpha("fifth")


func test_gorilla_war_cry_waits_when_menace_changes_nothing() -> void:
	var ai := _pilot()
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var cry := give_hand(0, "Gorilla War Cry")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	# Two Bears can still double-block the one Giant: menace stops nothing.
	var got: Variant = ALL.spell_choice(g, ai, cry)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "%s" % [got])


func test_gorilla_war_cry_waits_for_attackers() -> void:
	var ai := _pilot()
	for n in 3: put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Grizzly Bears")
	var cry := give_hand(0, "Gorilla War Cry")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var got: Variant = ALL.spell_choice(g, ai, cry)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "nothing declared yet")


# -------------------------------------------------------- fair play, gate --

func test_their_hidden_hand_and_the_libraries_move_nothing() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _pilot()
		var z := put_battlefield(0, "Gangrenous Zombies")
		put_battlefield(0, "Snow-Covered Swamp")
		var lyre := put_battlefield(0, "Goblin Lyre")
		put_battlefield(1, "Llanowar Elves")
		_stock_their_graveyard(3)
		for n in 3: put_battlefield(0, "Swamp")
		var spoils := give_hand(0, "Spoils of Evil")
		var lore := give_hand(0, "Forgotten Lore")
		var bolt := give_hand(0, "Lightning Bolt")
		g.discard_cards(0, [bolt])
		g.players[0].life = 6
		g.players[1].life = 7
		for n in 3:
			give_hand(1, "Fog" if variant == 0 else "Shivan Dragon")
		if variant == 1:
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		var row: Array = []
		for got in [_ability_answer(ai, z), _ability_answer(ai, lyre),
				ICE.spell_choice(g, ai, spoils, 0, 0), ICE.spell_choice(g, ai, lore, 0, 0)]:
			row.append("null" if got == null else ("{}" if (got as Dictionary).is_empty()
				else "%.4f" % float(got["value"])))
		answers.append(row)
		after_each()
	assert_eq(answers[0], answers[1], "hidden cards changed a reading")


func test_the_null_arm_reads_no_shape() -> void:
	var ai := _pilot(false)
	var z := put_battlefield(0, "Gangrenous Zombies")
	var bomb := put_battlefield(0, "Time Bomb")
	var lyre := put_battlefield(0, "Goblin Lyre")
	var spoils := give_hand(0, "Spoils of Evil")
	var lore := give_hand(0, "Forgotten Lore")
	var cry := give_hand(0, "Gorilla War Cry")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(ICE.role_option(g, ai, z, 0, "MAIN"))
	assert_null(ICE.role_option(g, ai, bomb, 0, "MAIN"))
	assert_null(ICE.role_option(g, ai, lyre, 0, "MAIN"))
	assert_null(ICE.role_spell_choice(g, ai, spoils))
	assert_null(ICE.role_spell_choice(g, ai, lore))
	assert_null(ALL.spell_choice(g, ai, cry))


func test_the_cards_declare_their_shapes() -> void:
	var expected := {"Gangrenous Zombies": &"sweep_each_creature_and_player",
		"Time Bomb": &"sweep_each_creature_and_player",
		"Goblin Lyre": &"coin_creature_count_damage"}
	for card_name in expected:
		var data := CardRegistry.get_card(card_name)
		assert_eq(data.activated_abilities[0].effects[0].ai_role, expected[card_name], card_name)
	assert_eq(CardRegistry.get_card("Spoils of Evil").spell_effects[0].ai_role, &"graveyard_count_life_mana")
	assert_eq(CardRegistry.get_card("Forgotten Lore").spell_effects[0].ai_role, &"opponent_picks_regrowth")
