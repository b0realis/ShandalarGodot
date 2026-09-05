extends GameTest
## Wave-5 tests: +1/+1 counters (Sengir/Fungusaur), sacrifice & life costs
## (Strip Mine/Greed), the UNBLOCKABLE grant, dynamic swarms, and the
## first atq/drk set-folder graduations.


# ------------------------------------------------------------- counters --

func test_sengir_grows_on_its_kills() -> void:
	var sengir := put_battlefield(0, "Sengir Vampire")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(sengir, TargetRef.card(bear), 4)   # lethal, sengir-sourced
	resolve_stack()   # the dies-trigger
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(sengir.counters.get("+1/+1", 0), 1)
	assert_eq(sengir.cur_power, 5, "4/4 + a counter = 5/5")


func test_sengir_ignores_unrelated_deaths() -> void:
	var sengir := put_battlefield(0, "Sengir Vampire")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)   # died, but not to Sengir's damage
	resolve_stack()
	assert_eq(sengir.counters.get("+1/+1", 0), 0, "no credit, no counter")


func test_fungusaur_grows_when_poked() -> void:
	var fungusaur := put_battlefield(0, "Fungusaur")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(fungusaur)]))
	resolve_stack()
	# 3 damage vs 2 toughness: the SBA kills it BEFORE its grow-trigger
	# resolves — a bolted Fungusaur just dies (the counter never lands).
	assert_eq(fungusaur.zone, Mtg.Zone.GRAVEYARD, "lethal outruns the trigger")
	assert_eq(fungusaur.counters.get("+1/+1", 0), 0)


func test_fungusaur_survivable_poke_adds_counter() -> void:
	var fungusaur := put_battlefield(0, "Fungusaur")
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(fungusaur)]))
	resolve_stack()
	assert_eq(fungusaur.counters.get("+1/+1", 0), 1, "1 damage, +1/+1")
	assert_eq(fungusaur.cur_toughness, 3, "2/2 + counter with 1 marked damage")


func test_counters_survive_cleanup_unlike_pumps() -> void:
	var fungusaur := put_battlefield(0, "Fungusaur")
	g.add_counters(fungusaur, "+1/+1", 2)
	advance_to_next_turn()
	assert_eq(fungusaur.cur_power, 4, "counters are permanent")


# ------------------------------------------------- sacrifice & life costs --

func test_strip_mine_sacrifices_to_kill_a_land() -> void:
	var mine := put_battlefield(0, "Strip Mine")
	var dual := put_battlefield(1, "Tundra")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, mine, 0, [TargetRef.card(dual)]))
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the cost is paid up front")
	resolve_stack()
	assert_eq(dual.zone, Mtg.Zone.GRAVEYARD, "the dual died anyway")


func test_greed_trades_life_for_cards() -> void:
	var greed := put_battlefield(0, "Greed")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, greed, 0, []))
	assert_ok(g.activate_ability(0, greed, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 16, "2 life per activation")
	assert_eq(g.players[0].hand.size(), 2)


func test_greed_refuses_the_overdraft() -> void:
	g.players[0].life = 1
	var greed := put_battlefield(0, "Greed")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, greed, 0, []), "not enough life")


# ------------------------------------------------------------ unblockable --

func test_dwarven_warriors_sneak_a_small_creature_through() -> void:
	var dwarves := put_battlefield(0, "Dwarven Warriors")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, dwarves, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: bear.id}), "can't be blocked")


func test_dwarven_warriors_refuse_big_cargo() -> void:
	var dwarves := put_battlefield(0, "Dwarven Warriors")
	var serra := put_battlefield(0, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(
		g.activate_ability(0, dwarves, 0, [TargetRef.card(serra)]),
		"Illegal target")


# ------------------------------------------------------ assorted wave 5 --

func test_plague_rats_swarm_across_both_sides() -> void:
	var mine := put_battlefield(0, "Plague Rats")
	var theirs := put_battlefield(1, "Plague Rats")
	assert_eq(mine.cur_power, 2, "rats count rats on BOTH battlefields")
	assert_eq(theirs.cur_power, 2)
	put_battlefield(0, "Plague Rats")
	assert_eq(mine.cur_power, 3)


func test_twiddle_toggles_both_ways() -> void:
	var forest := put_battlefield(1, "Forest")
	var twiddle1 := give_hand(0, "Twiddle")
	var twiddle2 := give_hand(0, "Twiddle")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, twiddle1, [TargetRef.card(forest)]))
	resolve_stack()
	assert_true(forest.tapped, "untapped -> tapped")
	assert_ok(g.cast_spell(0, twiddle2, [TargetRef.card(forest)]))
	resolve_stack()
	assert_false(forest.tapped, "tapped -> untapped")


func test_tsunami_drowns_duals_too() -> void:
	put_battlefield(1, "Island")
	var dual := put_battlefield(1, "Tropical Island")
	var forest := put_battlefield(1, "Forest")
	var tsunami := give_hand(0, "Tsunami")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, tsunami, []))
	resolve_stack()
	assert_eq(dual.zone, Mtg.Zone.GRAVEYARD, "island subtype drowns")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


func test_manabarbs_taxes_every_land_tap() -> void:
	put_battlefield(0, "Manabarbs")
	var swamp := put_battlefield(1, "Swamp")
	assert_ok(g.tap_for_mana(1, swamp))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_su_chi_death_rattle_feeds_its_controller() -> void:
	var su_chi := put_battlefield(1, "Su-Chi")
	var terror: CardInstance = null
	# Terror can't hit an artifact creature — use engine destroy directly.
	g.destroy(su_chi, false)
	resolve_stack()
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 4,
		"four colorless in the moment of death")


func test_land_tax_collects_when_behind() -> void:
	put_battlefield(0, "Land Tax")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var hand_before := g.players[0].hand.size()
	advance_to_next_turn()
	advance_to_next_turn()   # through P0's upkeep (0 lands vs 2) + draw
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before + 4,
		"three fetched basics + the turn's normal draw")


func test_winds_of_change_rerolls_hands() -> void:
	give_hand(0, "Lightning Bolt")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	var winds := give_hand(0, "Winds of Change")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, winds, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "1 card back (Winds was on the stack)")
	assert_eq(g.players[1].hand.size(), 2)
	assert_eq(g.players[1].graveyard.size(), 0, "graveyards untouched")


func test_regeneration_aura_shields_the_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)   # {1}{G} to cast + {G} to activate
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)
	g.destroy(bear, true)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated through the aura")


func test_fountain_of_youth_trickles() -> void:
	var fountain := put_battlefield(0, "Fountain of Youth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, fountain, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 21)
