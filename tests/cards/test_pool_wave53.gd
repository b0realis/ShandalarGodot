extends GameTest
## Wave-53 tests: the second batch of MULTI-PART ONE-OFFS — Rasputin's
## dream-counter economy, the Voodoo Doll's ticking pins, an Egg that
## hatches, a Monster built from corpses, a Sword that eats your army,
## Hazezon's delayed sandstorm, Halfdane's borrowed body, a Maggot that
## jumps hosts and an Aura that tolls its prisoner.


func test_registry_loaded_wave53() -> void:
	for name in ["Rasputin Dreamweaver", "Voodoo Doll", "Sword of the Ages",
			"Triassic Egg", "Frankenstein's Monster", "Hazezon Tamar",
			"Halfdane", "Takklemaggot", "Imprison"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------ Rasputin Dreamweaver --

func test_rasputin_taps_dreams_for_mana_without_tapping() -> void:
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	assert_eq(int(rasputin.counters.get("dream", 0)), 7)
	assert_ok(g.tap_for_mana(0, rasputin))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)
	assert_false(rasputin.tapped, "no {T} in that cost")
	assert_eq(int(rasputin.counters.get("dream", 0)), 6)


func test_rasputin_runs_out_of_dreams() -> void:
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	rasputin.counters["dream"] = 1
	assert_ok(g.tap_for_mana(0, rasputin))
	assert_refused(g.tap_for_mana(0, rasputin), "dream counters")


func test_rasputin_shields_itself() -> void:
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, rasputin, 0, []))
	resolve_stack()
	assert_eq(int(rasputin.counters.get("dream", 0)), 6)
	assert_eq(rasputin.prevention, 1)


func test_rasputin_refills_at_your_upkeep_but_caps_at_seven() -> void:
	var rasputin := put_battlefield(0, "Rasputin Dreamweaver")
	rasputin.counters["dream"] = 5
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(int(rasputin.counters.get("dream", 0)), 6)
	rasputin.counters["dream"] = 7
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(int(rasputin.counters.get("dream", 0)), 7, "never more than seven")


# ------------------------------------------------------------- Voodoo Doll --

func test_voodoo_doll_collects_pins_while_tapped() -> void:
	var doll := put_battlefield(0, "Voodoo Doll")
	doll.tapped = true          # untapped at your end step and it kills you
	doll.skip_untaps = 5
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: a pin goes in
	resolve_stack()
	assert_eq(int(doll.counters.get("pin", 0)), 1)
	assert_eq(doll.zone, Mtg.Zone.BATTLEFIELD, "tapped, so it survives")


func test_voodoo_doll_backfires_when_left_untapped() -> void:
	var doll := put_battlefield(0, "Voodoo Doll")
	doll.counters["pin"] = 3
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(doll.zone, Mtg.Zone.GRAVEYARD, "untapped at your end step")
	assert_eq(g.players[0].life, 17, "and it stabs you for its pins")


func test_voodoo_doll_fires_at_a_target() -> void:
	var doll := put_battlefield(0, "Voodoo Doll")
	doll.counters["pin"] = 3
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, doll, 0, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_true(doll.tapped, "and it survives its own end step")


# -------------------------------------------------------- Sword of the Ages --

func test_sword_of_the_ages_eats_your_army() -> void:
	var sword := put_battlefield(0, "Sword of the Ages")
	sword.tapped = false
	var a := put_battlefield(0, "Hill Giant")        # 3 power
	var b := put_battlefield(0, "Grizzly Bears")     # 2 power
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 15, "3 + 2 power")
	assert_eq(a.zone, Mtg.Zone.EXILE)
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(sword.zone, Mtg.Zone.EXILE)


func test_sword_of_the_ages_enters_tapped() -> void:
	var sword := put_battlefield(0, "Sword of the Ages")
	assert_true(sword.tapped)


# ------------------------------------------------------------ Triassic Egg --

func test_triassic_egg_needs_two_hatchlings() -> void:
	var egg := put_battlefield(0, "Triassic Egg")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, egg, 1, []), "hatchling")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, egg, 0, []))
	resolve_stack()
	assert_eq(int(egg.counters.get("hatchling", 0)), 1)


func test_triassic_egg_hatches_from_hand() -> void:
	var egg := put_battlefield(0, "Triassic Egg")
	egg.counters["hatchling"] = 2
	var angel := give_hand(0, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, egg, 1, []))
	resolve_stack()
	assert_eq(egg.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------- Frankenstein's Monster --

func test_frankensteins_monster_is_built_from_corpses() -> void:
	for _i in 3:
		var corpse := give_hand(0, "Grizzly Bears")
		g.players[0].hand.erase(corpse)
		corpse.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(corpse)
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, monster, [], 2))
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(monster.cur_power, 2, "0/1 plus two +1/+1 counters")
	assert_eq(monster.cur_toughness, 3)
	assert_eq(g.players[0].graveyard.size(), 1, "two corpses were exiled")


func test_frankensteins_monster_collapses_without_corpses() -> void:
	var monster := give_hand(0, "Frankenstein's Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, monster, [], 2))
	resolve_stack()
	assert_eq(monster.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Hazezon Tamar --

func test_hazezon_raises_the_sands_next_upkeep() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Sand Warrior"), "not yet")
	advance_to_next_turn()
	advance_to_next_turn()      # our next upkeep
	resolve_stack()
	var sands := 0
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Sand Warrior":
			sands += 1
	assert_eq(sands, 2, "one per land")
	g.destroy(hazezon)
	g.check_state_based_actions()
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Sand Warrior"), "they blow away")


# ---------------------------------------------------------------- Halfdane --

func test_halfdane_borrows_the_biggest_body() -> void:
	var halfdane := put_battlefield(0, "Halfdane")
	put_battlefield(1, "Serra Angel")           # 4/4
	assert_eq(halfdane.cur_power, 3)
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep
	resolve_stack()
	assert_eq(halfdane.cur_power, 4, "it wears the Angel's body")
	assert_eq(halfdane.cur_toughness, 4)


# ------------------------------------------------------------ Takklemaggot --

func test_takklemaggot_wastes_and_then_jumps() -> void:
	var host := put_battlefield(1, "Grizzly Bears")     # 2/2
	var spare := put_battlefield(1, "Hill Giant")
	var maggot := give_hand(0, "Takklemaggot")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, maggot, [TargetRef.card(host)]))
	resolve_stack()
	advance_to_next_turn()      # their upkeep: a -0/-1 counter
	resolve_stack()
	assert_eq(host.cur_toughness, 1)
	g.destroy(host)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD, "the plague moved on")
	assert_eq(maggot.attached_to, spare.id)
	assert_eq(maggot.controller_id, 0, "still ours")


# ---------------------------------------------------------------- Imprison --

func test_imprison_pulls_its_prisoner_out_of_an_attack() -> void:
	var prisoner := put_battlefield(1, "Hill Giant")
	var imprison := give_hand(0, "Imprison")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, imprison, [TargetRef.card(prisoner)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [prisoner.id]))
	resolve_stack()
	assert_false(g.combat.attackers.has(prisoner.id), "hauled back")
	assert_eq(imprison.zone, Mtg.Zone.BATTLEFIELD, "the toll was paid")


func test_imprison_breaks_when_the_toll_cant_be_paid() -> void:
	var prisoner := put_battlefield(1, "Hill Giant")
	var imprison := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, imprison, [TargetRef.card(prisoner)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [prisoner.id]))
	resolve_stack()
	assert_eq(imprison.zone, Mtg.Zone.GRAVEYARD, "no mana, no Aura")
