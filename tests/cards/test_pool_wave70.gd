extends GameTest
## Wave-70 tests: the beginning-of-combat event (Battering Ram, Johan), the
## attack-cost hook under real pressure (Leviathan), a chosen-discard COST
## (Land's Edge), per-seat "did you act last turn" bookkeeping (Arboria),
## a land-arrival punisher (Land Equilibrium), the Vortex's three clauses,
## and Floral Spuzzem's trade.


## Says yes to every yes/no.
class Eager extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true


## Says no to every yes/no.
class Reluctant extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


## Discards a named card when asked for a cost discard.
class Thrower extends DecisionAgent:
	var throws := ""

	func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for inst in game.players[pid].hand:
			if inst.data.card_name == throws and out.size() < count:
				out.append(inst)
		if out.is_empty():
			return super(game, pid, count)
		return out


func test_registry_loaded_wave70() -> void:
	for name in ["Battering Ram", "Johan", "Leviathan", "Land's Edge",
			"Arboria", "Land Equilibrium", "Mana Vortex", "Floral Spuzzem"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------- Battering Ram --

func test_battering_ram_bands_up_at_the_beginning_of_combat() -> void:
	var ram := put_battlefield(0, "Battering Ram")
	assert_false(ram.has_keyword(Mtg.Keyword.BANDING))
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	resolve_stack()
	assert_true(ram.has_keyword(Mtg.Keyword.BANDING))


func test_battering_rams_banding_ends_with_the_combat() -> void:
	var ram := put_battlefield(0, "Battering Ram")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(ram.has_keyword(Mtg.Keyword.BANDING))


func test_battering_ram_dooms_the_wall_that_blocks_it() -> void:
	var ram := put_battlefield(0, "Battering Ram")
	var wall := put_battlefield(1, "Wall of Wood")
	run_combat([ram.id], {wall.id: ram.id})
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "destroyed at end of combat")


func test_battering_ram_spares_a_creature_that_is_no_wall() -> void:
	var ram := put_battlefield(0, "Battering Ram")
	var bear := put_battlefield(1, "Grizzly Bears")
	run_combat([ram.id], {bear.id: ram.id})
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "a bear is not a Wall")


# -------------------------------------------------------------- Johan --

func test_johan_lets_the_team_attack_without_tapping() -> void:
	g.set_agent(0, Eager.new())
	var johan := put_battlefield(0, "Johan")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	resolve_stack()
	assert_true(johan.cant_attack_this_turn, "Johan sits it out")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))
	assert_false(bear.tapped, "attacking did not tap them")
	assert_false(giant.tapped)


func test_johan_declined_leaves_the_team_tapping() -> void:
	g.set_agent(0, Reluctant.new())
	var johan := put_battlefield(0, "Johan")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	resolve_stack()
	assert_false(johan.cant_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, johan.id]))
	assert_true(bear.tapped)


func test_johans_offer_ends_with_the_combat() -> void:
	g.set_agent(0, Eager.new())
	put_battlefield(0, "Johan")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	resolve_stack()
	assert_true(g.attacks_without_tapping.has(0))
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.attacks_without_tapping.has(0))


# ----------------------------------------------------------- Leviathan --

func test_leviathan_enters_tapped_and_stays_tapped() -> void:
	var whale := put_battlefield(0, "Leviathan")
	whale.tapped = true
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(whale.tapped, "it doesn't untap during your untap step")


func test_leviathan_untaps_for_two_islands() -> void:
	g.set_agent(0, Eager.new())
	var whale := put_battlefield(0, "Leviathan")
	whale.tapped = true
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_false(whale.tapped)
	var islands := 0
	for inst in g.players[0].battlefield:
		if inst.has_subtype("island"):
			islands += 1
	assert_eq(islands, 0, "both Islands went")


func test_leviathan_cannot_attack_without_two_islands() -> void:
	var whale := put_battlefield(0, "Leviathan")
	g.untap_permanent(whale)          # it enters tapped
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [whale.id]), "sacrifice two Islands")
	var islands := 0
	for inst in g.players[0].battlefield:
		if inst.has_subtype("island"):
			islands += 1
	assert_eq(islands, 1, "a refused declaration spends nothing")


func test_leviathan_pays_its_toll_to_attack() -> void:
	var whale := put_battlefield(0, "Leviathan")
	g.untap_permanent(whale)          # it enters tapped
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [whale.id]))
	var islands := 0
	for inst in g.players[0].battlefield:
		if inst.has_subtype("island"):
			islands += 1
	assert_eq(islands, 0, "two Islands paid as attackers were declared")


# ---------------------------------------------------------- Land's Edge --

func test_lands_edge_burns_for_a_discarded_land() -> void:
	var agent := Thrower.new()
	agent.throws = "Forest"
	g.set_agent(0, agent)
	var edge := put_battlefield(0, "Land's Edge")
	give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, edge, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18)


func test_lands_edge_does_nothing_for_a_spell() -> void:
	var agent := Thrower.new()
	agent.throws = "Lightning Bolt"
	g.set_agent(0, agent)
	var edge := put_battlefield(0, "Land's Edge")
	give_hand(0, "Lightning Bolt")
	assert_ok(g.activate_ability(0, edge, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].graveyard.size(), 1, "the card went either way")


func test_lands_edge_can_be_used_by_the_opponent() -> void:
	var agent := Thrower.new()
	agent.throws = "Forest"
	g.set_agent(1, agent)
	var edge := put_battlefield(0, "Land's Edge")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, edge, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 18, "any player may activate it")


func test_lands_edge_needs_a_card_to_throw() -> void:
	var edge := put_battlefield(0, "Land's Edge")
	assert_refused(g.activate_ability(0, edge, 0, [TargetRef.player(1)]),
		"not enough cards in hand")


# -------------------------------------------------------------- Arboria --

func test_arboria_grounds_an_idle_players_attackers() -> void:
	put_battlefield(0, "Arboria")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()   # p1 does nothing at all
	advance_to_next_turn()   # back to p0
	assert_true(bear.cur_cant_attack, "p1 sat still last turn")


func test_arboria_lets_you_attack_a_player_who_acted() -> void:
	put_battlefield(0, "Arboria")
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	advance_to_next_turn()   # p1's turn
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, g.players[1].hand[0], []))
	resolve_stack()
	advance_to_next_turn()   # back to p0
	assert_false(bear.cur_cant_attack, "p1 cast a spell on their own turn")


# ------------------------------------------------------ Land Equilibrium --

func test_land_equilibrium_taxes_a_land_when_they_are_ahead() -> void:
	# The opponent's board is set up FIRST: putting a land down while the
	# enchantment is already out is itself a trigger.
	put_battlefield(1, "Forest")
	put_battlefield(0, "Land Equilibrium")
	var land := give_hand(1, "Forest")
	advance_to_next_turn()
	assert_ok(g.play_land(1, land))
	resolve_stack()
	var theirs := 0
	for inst in g.players[1].battlefield:
		if inst.is_land():
			theirs += 1
	assert_eq(theirs, 1, "the new land arrived and one was sacrificed")


func test_land_equilibrium_spares_a_player_behind_on_lands() -> void:
	for _i in 3:
		put_battlefield(0, "Forest")
	put_battlefield(0, "Land Equilibrium")
	var land := give_hand(1, "Forest")
	advance_to_next_turn()
	assert_ok(g.play_land(1, land))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "1 land is not 'at least 3'")


func test_land_equilibrium_ignores_your_own_lands() -> void:
	put_battlefield(0, "Land Equilibrium")
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, land))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "'an OPPONENT who controls...'")


# ----------------------------------------------------------- Mana Vortex --

func test_mana_vortex_is_countered_by_its_own_trigger_without_a_land() -> void:
	# Lifted 2026-09-02: "When you cast this spell, counter it unless you
	# sacrifice a land" is a cast TRIGGER, so the cast is allowed and the
	# Vortex is countered when the trigger resolves (it used to be an
	# additional cost that refused the cast).
	var vortex := give_hand(0, "Mana Vortex")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, vortex, []))
	resolve_stack()
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD, "countered")


func test_mana_vortex_grinds_both_players_lands() -> void:
	put_battlefield(0, "Mana Vortex")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	advance_to_next_turn()   # p1's upkeep grinds p1
	resolve_stack()
	var theirs := 0
	for inst in g.players[1].battlefield:
		if inst.is_land():
			theirs += 1
	assert_eq(theirs, 1)


func test_mana_vortex_eats_itself_when_the_board_runs_dry() -> void:
	var vortex := put_battlefield(0, "Mana Vortex")
	var land := put_battlefield(0, "Forest")
	g.destroy(land)
	g.check_state_based_actions()
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD, "no lands left")


# ------------------------------------------------------- Floral Spuzzem --

func test_floral_spuzzem_trades_its_damage_for_an_artifact() -> void:
	g.set_agent(0, Eager.new())
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	run_combat([spuzzem.id])
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "and it dealt no combat damage")


func test_floral_spuzzem_may_decline_and_swing() -> void:
	g.set_agent(0, Reluctant.new())
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	run_combat([spuzzem.id])
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 18)


func test_floral_spuzzem_does_nothing_when_blocked() -> void:
	g.set_agent(0, Eager.new())
	var spuzzem := put_battlefield(0, "Floral Spuzzem")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	var bear := put_battlefield(1, "Grizzly Bears")
	run_combat([spuzzem.id], {bear.id: spuzzem.id})
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD, "it was blocked")
