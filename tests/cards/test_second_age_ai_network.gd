extends GameTest
const T := preload("res://engine/ai/second_age_tactics.gd")

class DamageChooser extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool: return true

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func test_new_tactics_use_public_information_not_opponents_hidden_names() -> void:
	var pilot := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, pilot)
	var spy := give_hand(0, "Eye Spy")
	give_hand(1, "Forest")
	var before: Dictionary = T.spell_choice(g, pilot, spy)
	var rng := g.rng.state
	for card in g.players[1].hand: card.data = CardRegistry.get_card("Black Lotus")
	g.players[1].library.reverse()
	var after: Dictionary = T.spell_choice(g, pilot, spy)
	assert_eq(before.value, after.value)
	assert_eq(before.targets[0].player_id, after.targets[0].player_id)
	assert_eq(rng, g.rng.state)

func test_ai_declines_empty_edict_and_lethal_rain_of_daggers() -> void:
	var pilot := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, pilot)
	var edict := give_hand(0, "Cruel Edict")
	assert_eq(T.spell_choice(g, pilot, edict), {})
	put_battlefield(1, "Craw Wurm")
	assert_false(T.spell_choice(g, pilot, edict).is_empty())
	g.players[0].life = 2
	assert_eq(T.spell_choice(g, pilot, give_hand(0, "Rain of Daggers")), {})

func test_ai_uses_priestess_for_its_own_green_creature() -> void:
	var pilot := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, pilot)
	var priestess := put_battlefield(0, "Norwood Priestess")
	assert_eq(T.option(g, pilot, priestess, 0), {})
	give_hand(0, "Craw Wurm")
	assert_false(T.option(g, pilot, priestess, 0).is_empty())

func test_ai_special_damage_prefers_lethal_player_or_valuable_creature() -> void:
	var pilot := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, pilot)
	var giant := put_battlefield(0, "Cunning Giant")
	var enemy := put_battlefield(1, "Serra Angel")
	var request := {"source": giant, "targets": [enemy.id], "amount": 4, "defender": 1, "assigner": 0, "trample": false, "free_order": false, "special": "redirect"}
	assert_eq(pilot.assign_special_combat_damage(g, request), {enemy.id: 4})
	g.players[1].life = 4
	assert_eq(pilot.assign_special_combat_damage(g, request), {MtgGame.DAMAGE_TO_PLAYER: 4})

func test_piracy_options_cross_lan_projection_without_other_enemy_abilities() -> void:
	var land := put_battlefield(1, "Island")
	var piracy := give_hand(0, "Piracy")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, piracy))
	resolve_stack()
	var options := SgDuelActions.options(land, 0, g)
	assert_eq(options.size(), 1)
	assert_eq(options[0].kind, "mana")
	var match_game := SgPracticeMatch.new(42)
	match_game.game = g
	var projection := SgDuelProjection.new()
	projection.ingest({"seat": 0, "names": ["One", "Two"], "deck": {}, "deck_names": match_game.deck_names.duplicate(), "game": match_game.view(0)})
	var shown := projection.find_instance(projection.local_id(match_game._handle(0, land)))
	assert_true(projection.may_tap_foreign_land(0, shown))
	assert_ok(match_game.act(0, {"op": "mana", "card": match_game._handle(0, land), "index": 0}))
	assert_true(land.tapped)
	assert_eq(g.players[1].mana_pool.total(), 0)

func test_piracy_urza_mana_counts_activators_lands_and_undo_expires_permission() -> void:
	var tower := put_battlefield(1, "Urza's Tower")
	put_battlefield(1, "Urza's Mine")
	put_battlefield(1, "Urza's Power Plant")
	var piracy := give_hand(0, "Piracy")
	add_mana(0, Mtg.ManaColor.U, 2)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, piracy))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, tower))
	assert_eq(g.players[0].mana_pool.total(), 1, "the borrower does not control the three Urza lands")
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.may_tap_foreign_land(0, tower))

func test_piracy_does_not_inherit_the_land_owners_deep_water() -> void:
	var forest := put_battlefield(1, "Forest")
	g.players[1].land_mana_becomes = Mtg.ManaColor.U
	g.recalculate()
	var piracy := give_hand(0, "Piracy")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, piracy))
	resolve_stack()
	var sources := ManaPlanner.sources(g, 0)
	assert_true(sources.any(func(row: Array) -> bool: return row[0] == forest and row[2] == Mtg.ManaColor.G))
	assert_ok(g.tap_for_mana(0, forest))
	assert_true(g.players[0].mana_pool.can_pay(ManaCost.parse("{G}"), 0, ["spell"]))
	assert_false(g.players[0].mana_pool.can_pay(ManaCost.parse("{U}"), 0, ["spell"]))

func test_piracy_mana_triggers_distinguish_activator_and_land_controller() -> void:
	var forest := put_battlefield(1, "Forest")
	put_battlefield(1, "Mana Flare")
	put_battlefield(1, "Manabarbs")
	var growth := give_hand(0, "Wild Growth")
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(forest)]))
	resolve_stack()
	var piracy := give_hand(0, "Piracy")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, piracy))
	resolve_stack()
	assert_ok(g.tap_for_mana(0, forest))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total(), 2, "land mana and Mana Flare go to the activator")
	assert_eq(g.players[1].mana_pool.total(), 1, "Wild Growth goes to the land controller")
	assert_eq(g.players[0].life, 19, "Manabarbs damages the activator")
	assert_eq(g.players[1].life, 20)

func test_piracy_planner_keeps_high_tide_bonus_unrestricted() -> void:
	CardPacks.set_enabled("pack-2", true)
	var land := put_battlefield(1, "Island")
	var tide := give_hand(0, "High Tide")
	add_mana(0, Mtg.ManaColor.U, 1)
	assert_ok(g.cast_spell(0, tide))
	resolve_stack()
	var piracy := give_hand(0, "Piracy")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, piracy))
	resolve_stack()
	var sources := ManaPlanner.sources(g, 0)
	assert_false(ManaPlanner.plan_from(sources, ManaCost.parse("{U}"), 0).is_empty(), "the bonus may pay for abilities")
	assert_false(ManaPlanner.plan_from(sources, ManaCost.parse("{U}{U}"), 0, ["spell"]).is_empty())
	assert_true(ManaPlanner.plan_from(sources, ManaCost.parse("{U}{U}"), 0).is_empty(), "the land's own mana is spell-only")
	assert_ok(g.tap_for_mana(0, land))
	assert_true(g.players[0].mana_pool.can_pay(ManaCost.parse("{U}")))
	assert_false(g.players[0].mana_pool.can_pay(ManaCost.parse("{U}{U}")))

func test_cunning_giant_choice_survives_lan_projection_and_host_validation() -> void:
	var giant := put_battlefield(0, "Cunning Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, DamageChooser.new())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	var view := referee.view(0)
	assert_true(SgViewProtocol.game(view))
	assert_true(SgViewProtocol.game(referee.view(1)))
	var projection := SgDuelProjection.new()
	projection.ingest({"seat": 0, "names": ["One", "Two"], "deck": {}, "deck_names": referee.deck_names.duplicate(), "game": view})
	var request := projection.damage_assignment_request()
	assert_eq(request.special, "redirect")
	assert_eq(request.amount, 4)
	var target := referee._handle(0, bear)
	assert_refused(referee.act(0, {"op": "damage", "points": [[target, 1], ["player", 3]]}))
	assert_ok(referee.act(0, {"op": "damage", "points": [[target, 4]]}))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)
