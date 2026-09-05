extends GameTest
## Wave-12 tests: triggered payments (MtgGame.try_pay) and everything that
## rides them — the five lucky charms + Soul Net, upkeep-cost creatures
## (Phantasmal Forces, Force of Nature, Lord of the Pit), the tap-punisher
## enchantment (Lifetap) and the classic locked-mana artifacts (Mana
## Vault, Basalt Monolith).


# --------------------------------------------------- try_pay (engine pins) --

func test_try_pay_uses_floating_mana_first() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_true(g.try_pay(0, ManaCost.parse("{1}")))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_try_pay_taps_lands_for_missing_colors() -> void:
	var island := put_battlefield(0, "Island")
	var forest := put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(g.can_afford_cost(0, ManaCost.parse("{U}")))
	assert_true(g.try_pay(0, ManaCost.parse("{U}")))
	assert_true(island.tapped, "the island was auto-tapped for {U}")
	assert_false(forest.tapped, "the forest wasn't needed")


func test_try_pay_refuses_without_touching_state() -> void:
	var forest := put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(g.try_pay(0, ManaCost.parse("{U}")), "no blue source")
	assert_false(forest.tapped, "nothing was tapped on refusal")


# ------------------------------------------------------------- lucky charms --

func test_ivory_cup_pays_off_white_spells() -> void:
	put_battlefield(0, "Ivory Cup")
	put_battlefield(0, "Forest")   # the {1} will auto-tap this
	var lions := give_hand(0, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lions, []))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "paid {1}, gained 1")


func test_ivory_cup_triggers_on_opponents_spells_too() -> void:
	put_battlefield(0, "Ivory Cup")
	put_battlefield(0, "Plains")
	var lions := give_hand(1, "Savannah Lions")
	advance_to_next_turn()   # turn 2 — the opponent's own main phase
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, lions, []))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "the cup's controller pays and gains")


func test_ivory_cup_silent_when_unaffordable() -> void:
	put_battlefield(0, "Ivory Cup")   # no lands, no floating mana
	var lions := give_hand(0, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lions, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "can't pay — no gain")


func test_ivory_cup_ignores_nonwhite_spells() -> void:
	put_battlefield(0, "Ivory Cup")
	put_battlefield(0, "Plains")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "red spell — white charm silent")


func test_the_other_charms_watch_their_colors() -> void:
	put_battlefield(0, "Crystal Rod")
	put_battlefield(0, "Throne of Bone")
	put_battlefield(0, "Iron Star")
	put_battlefield(0, "Wooden Sphere")
	put_battlefield(0, "Plains")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "only the Iron Star paid out")


func test_soul_net_pays_on_any_death() -> void:
	put_battlefield(0, "Soul Net")
	put_battlefield(0, "Plains")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	resolve_stack()
	assert_eq(g.players[0].life, 21, "a creature died — {1} paid, 1 gained")


# ------------------------------------------------------- upkeep-cost bodies --

func test_phantasmal_forces_upkeep_toll() -> void:
	var forces := put_battlefield(0, "Phantasmal Forces")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)   # our turn 1 main (upkeep already past)
	advance_to_step(Mtg.Step.UPKEEP)  # opponent's upkeep — no trigger
	resolve_stack()
	assert_eq(forces.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)  # OUR upkeep: the island pays the toll
	resolve_stack()
	assert_eq(forces.zone, Mtg.Zone.BATTLEFIELD, "paid {U} — survives")
	assert_true(g.find_on_battlefield(0, "Island").tapped)


func test_phantasmal_forces_dies_unpaid() -> void:
	var forces := put_battlefield(0, "Phantasmal Forces")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # our upkeep, no blue anywhere
	resolve_stack()
	assert_eq(forces.zone, Mtg.Zone.GRAVEYARD, "sacrificed — no {U}")


func test_force_of_nature_burns_unpaid() -> void:
	var force := put_battlefield(0, "Force of Nature")
	assert_eq(force.cur_power, 8)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # our upkeep, no forests
	resolve_stack()
	assert_eq(g.players[0].life, 12, "8 damage — couldn't pay {G}{G}{G}{G}")
	assert_eq(force.zone, Mtg.Zone.BATTLEFIELD, "the Force itself stays")


func test_force_of_nature_fed_stays_peaceful() -> void:
	put_battlefield(0, "Force of Nature")
	for i in 4:
		put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "all four forests tapped instead")


func test_lord_of_the_pit_eats_a_creature_or_you() -> void:
	var lord := put_battlefield(0, "Lord of the Pit")
	var snack := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # our upkeep: feed it the bear
	resolve_stack()
	assert_eq(snack.zone, Mtg.Zone.GRAVEYARD, "the bear was sacrificed")
	assert_eq(lord.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 20)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # nothing left to feed it
	resolve_stack()
	assert_eq(g.players[0].life, 13, "7 damage — no other creature to sacrifice")


# ----------------------------------------------------------------- Lifetap --

func test_lifetap_profits_from_enemy_forests() -> void:
	put_battlefield(0, "Lifetap")
	var their_forest := put_battlefield(1, "Forest")
	var my_forest := put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, my_forest))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "our own forest doesn't pay")
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, their_forest))
	resolve_stack()
	assert_eq(g.players[0].life, 21, "the opponent's forest tapped — gain 1")


# --------------------------------------------------- locked-mana artifacts --

func test_basalt_monolith_stays_tapped_but_unlocks() -> void:
	var monolith := put_battlefield(0, "Basalt Monolith")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, monolith))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(monolith.tapped, "skipped its controller's untap step")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, monolith, 0, []))
	resolve_stack()
	assert_false(monolith.tapped, "{3} untapped it")


func test_mana_vault_full_cycle() -> void:
	var vault := put_battlefield(0, "Mana Vault")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, vault))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3)
	# Next OUR upkeep: no mana to pay {4} → stays tapped; draw step burns.
	advance_to_next_turn()   # opponent's turn
	advance_to_next_turn()   # our turn again — past upkeep AND draw
	assert_true(vault.tapped, "no {4} available — still tapped")
	assert_eq(g.players[0].life, 19, "tapped at our draw step: 1 damage")


func test_mana_vault_untaps_when_paid() -> void:
	var vault := put_battlefield(0, "Mana Vault")
	for i in 4:
		put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, vault))
	g.players[0].mana_pool.clear()
	advance_to_next_turn()   # opponent's turn
	advance_to_next_turn()   # our upkeep pays {4} from the plains
	assert_false(vault.tapped, "paid {4} — untapped, no draw-step burn")
	assert_eq(g.players[0].life, 20)
