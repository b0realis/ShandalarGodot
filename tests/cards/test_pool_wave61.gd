extends GameTest
## Wave-61 tests: Aura relocation (Enchantment Alteration), the narrow
## counterspell (Ring of Immortals), the growing blocker (Infinite
## Authority), the hand-dumping sorcery (Eureka), combat tricks (Sewers of
## Estark), the free land drop (Gaea's Touch), the exile bunker (Safe
## Haven), the life tax (Wand of Ith) and Arabian Nights' two rares.


## Refuses every optional offer.
class StingyAgent extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return false


## Accepts every optional offer and picks a named card when it can.
class EagerAgent extends DecisionAgent:
	var pick_name := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == pick_name:
				return inst
		return super(game, pid, candidates, prompt)


func test_registry_loaded_wave61() -> void:
	for name in ["Enchantment Alteration", "Ring of Immortals",
			"Infinite Authority", "Eureka", "Sewers of Estark", "Gaea's Touch",
			"Safe Haven", "Wand of Ith", "Erhnam Djinn", "Guardian Beast"]:
		assert_not_null(CardRegistry.get_card(name), name)


# -------------------------------------------------- Enchantment Alteration --

func test_enchantment_alteration_moves_an_aura_between_creatures() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var strength := give_hand(1, "Holy Strength")
	var alter := give_hand(0, "Enchantment Alteration")
	advance_to_next_turn()          # their main phase: an Aura is sorcery-speed
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, strength, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.cur_power, 4)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, alter, [TargetRef.card(strength)]))
	resolve_stack()
	assert_eq(strength.attached_to, mine.id, "a helpful Aura comes to us")
	assert_eq(mine.cur_power, 3)
	assert_eq(theirs.cur_power, 3)


func test_enchantment_alteration_cannot_target_an_unattached_enchantment() -> void:
	var moat := put_battlefield(1, "Moat")   # not an Aura
	var alter := give_hand(0, "Enchantment Alteration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, alter, [TargetRef.card(moat)]))


func test_enchantment_alteration_keeps_a_land_aura_on_lands() -> void:
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	put_battlefield(1, "Grizzly Bears")
	var venom := give_hand(0, "Psychic Venom")
	var alter := give_hand(0, "Enchantment Alteration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, venom, [TargetRef.card(forest)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, alter, [TargetRef.card(venom)]))
	resolve_stack()
	assert_eq(venom.attached_to, island.id, "a land Aura stays on lands")


# ---------------------------------------------------------- Ring of Immortals --

func test_ring_of_immortals_counters_a_spell_aimed_at_us() -> void:
	var ring := put_battlefield(0, "Ring of Immortals")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, ring, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_ring_of_immortals_ignores_a_spell_aimed_elsewhere() -> void:
	var ring := put_battlefield(0, "Ring of Immortals")
	put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, ring, 0, [TargetRef.card(bolt)]))


func test_ring_of_immortals_refuses_a_sorcery() -> void:
	var ring := put_battlefield(0, "Ring of Immortals")
	var forest := put_battlefield(0, "Forest")
	var rain := give_hand(1, "Stone Rain")
	advance_to_next_turn()          # their main phase: Stone Rain is a sorcery
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, rain, [TargetRef.card(forest)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, ring, 0, [TargetRef.card(rain)]),
		"Illegal target (type).")


# ------------------------------------------------------- Infinite Authority --

func test_infinite_authority_eats_a_small_blocker_and_grows() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")     # 2/2, the enchanted one
	var wall := put_battlefield(1, "Wall of Wood")      # 0/3 — survives the 2
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "destroyed at end of combat")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(bear.cur_power, 3)


func test_infinite_authority_pays_nothing_for_a_creature_combat_killed() -> void:
	var giant := put_battlefield(0, "Hill Giant")       # 3/3, enchanted
	var bear := put_battlefield(1, "Grizzly Bears")     # 2/2 — dies to damage
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(giant.counters.get("+1/+1", 0)), 0,
		"combat damage killed it, so nothing was destroyed THIS WAY")


func test_infinite_authority_spares_a_tough_blocker() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")   # 0/8
	var aura := give_hand(0, "Infinite Authority")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "toughness 8 is not 3 or less")
	assert_eq(int(giant.counters.get("+1/+1", 0)), 0)


# ------------------------------------------------------------------ Eureka --

func test_eureka_empties_both_hands_of_permanents() -> void:
	var mine := give_hand(0, "Hill Giant")
	var also_mine := give_hand(0, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")   # not a permanent
	var theirs := give_hand(1, "Serra Angel")
	var spell := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(also_mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bolt.zone, Mtg.Zone.HAND, "instants stay home")


func test_eureka_stops_when_a_player_declines() -> void:
	g.set_agent(0, StingyAgent.new())
	g.set_agent(1, StingyAgent.new())
	var mine := give_hand(0, "Hill Giant")
	var spell := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.HAND)


# -------------------------------------------------------- Sewers of Estark --

func test_sewers_make_an_attacker_unblockable() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var spell := give_hand(0, "Sewers of Estark")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: giant.id}))


func test_sewers_silence_a_block_from_both_sides() -> void:
	var giant := put_battlefield(0, "Hill Giant")     # 3/3
	var bear := put_battlefield(1, "Grizzly Bears")   # 2/2
	var spell := give_hand(1, "Sewers of Estark")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.damage, 0, "the attacker's damage is prevented too")
	assert_eq(giant.damage, 0)
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------------- Gaea's Touch --

func test_gaeas_touch_plants_a_forest_without_the_land_drop() -> void:
	var touch := put_battlefield(0, "Gaea's Touch")
	var forest := give_hand(0, "Forest")
	var second := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, second))            # the turn's real land drop
	assert_ok(g.activate_ability(0, touch, 0, []))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "the enchantment is not a land drop")


func test_gaeas_touch_works_only_once_a_turn_and_at_sorcery_speed() -> void:
	var touch := put_battlefield(0, "Gaea's Touch")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, touch, 0, []))
	resolve_stack()
	assert_refused(g.activate_ability(0, touch, 0, []), "once")
	advance_to_next_turn()          # the opponent's main phase
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, touch, 0, []), "sorcery")


func test_gaeas_touch_cashes_itself_in_for_two_green() -> void:
	var touch := put_battlefield(0, "Gaea's Touch")
	assert_ok(g.tap_for_mana(0, touch))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2)
	assert_eq(touch.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Safe Haven --

func test_safe_haven_banks_and_returns_a_creature() -> void:
	var haven := put_battlefield(0, "Safe Haven")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, haven, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: the Haven cashes itself in
	assert_eq(haven.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)


func test_safe_haven_strands_its_prisoners_when_it_is_destroyed() -> void:
	var haven := put_battlefield(0, "Safe Haven")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, haven, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(haven)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "the link died with the land")


# --------------------------------------------------------------- Wand of Ith --

func test_wand_of_ith_taxes_a_card_out_of_a_hand() -> void:
	g.set_agent(1, StingyAgent.new())    # refuse to pay
	var wand := put_battlefield(0, "Wand of Ith")
	give_hand(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(g.players[1].graveyard.size(), 1)
	assert_eq(g.players[1].life, 20)


func test_wand_of_ith_can_be_paid_off_in_life() -> void:
	g.set_agent(1, EagerAgent.new())
	var wand := put_battlefield(0, "Wand of Ith")
	give_hand(1, "Hill Giant")           # mana value 4
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].life, 16)


func test_wand_of_ith_only_works_on_your_turn() -> void:
	var wand := put_battlefield(0, "Wand of Ith")
	give_hand(1, "Hill Giant")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, wand, 0, [TargetRef.player(1)]))


# --------------------------------------------------------------- Erhnam Djinn --

func test_erhnam_djinn_gives_forestwalk_to_the_smallest_enemy() -> void:
	put_battlefield(0, "Erhnam Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Wall of Stone")
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep
	assert_true(bear.cur_landwalk.has("forest"), "the weakest non-Wall body")


func test_erhnam_djinn_forestwalk_actually_evades() -> void:
	var djinn := put_battlefield(0, "Erhnam Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.cur_landwalk.has("forest"))
	# On THEIR turn the walk matters: we hold a Forest, so it cannot be blocked.
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {djinn.id: bear.id}), "forestwalk")


# -------------------------------------------------------------- Guardian Beast --

func test_guardian_beast_shields_your_artifacts_while_untapped() -> void:
	var beast := put_battlefield(0, "Guardian Beast")
	var ring := put_battlefield(0, "Sol Ring")
	assert_true(ring.cur_indestructible)
	assert_true(ring.cur_cant_be_aura_target)
	g.destroy(ring)
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "indestructible")
	g.tap_permanent(beast)
	assert_false(ring.cur_indestructible, "the shield is off while it is tapped")
	g.destroy(ring)
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_guardian_beast_leaves_artifact_creatures_out() -> void:
	put_battlefield(0, "Guardian Beast")
	var robot := put_battlefield(0, "Clockwork Beast")   # artifact CREATURE
	assert_false(robot.cur_indestructible, "the printed word is noncreature")
