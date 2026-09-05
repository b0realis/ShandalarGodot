extends GameTest
## Wave-72 tests: Forethought Amulet (a player-side damage CAP, applied as a
## replacement before prevention), Reflecting Mirror (retargeting a spell on
## the stack, with an X the engine can refuse), Runesword (a floating
## "damage this creature deals" watch) and All Hallow's Eve (a trigger that
## listens from EXILE).


## Says yes to every yes/no (pays the Amulet's rent).
class Eager extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true


func test_registry_loaded_wave72() -> void:
	for name in ["Forethought Amulet", "Reflecting Mirror", "Runesword",
			"All Hallow's Eve"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------ Forethought Amulet --

func test_amulet_caps_a_big_burn_spell() -> void:
	put_battlefield(0, "Forethought Amulet")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 18, "3 became 2")


func test_amulet_leaves_small_damage_alone() -> void:
	put_battlefield(0, "Forethought Amulet")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "an ABILITY is not a spell")


func test_amulet_does_not_shield_your_creatures() -> void:
	put_battlefield(0, "Forethought Amulet")
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "'dealt to YOU'")


func test_amulet_is_sacrificed_when_the_rent_is_not_paid() -> void:
	var amulet := put_battlefield(0, "Forethought Amulet")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(amulet.zone, Mtg.Zone.GRAVEYARD, "no mana, no Amulet")


# ------------------------------------------------------ Reflecting Mirror --

func _incoming_bolt() -> CardInstance:
	var bolt := give_hand(1, "Lightning Bolt")     # mana value 1, so X is 2
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	return bolt


func test_mirror_turns_a_spell_around() -> void:
	var mirror := put_battlefield(0, "Reflecting Mirror")
	var bolt := _incoming_bolt()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mirror, 0, [TargetRef.card(bolt)], 2))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "it never hit you")
	assert_eq(g.players[1].life, 17, "it hit them instead")


func test_mirror_refuses_the_wrong_x() -> void:
	var mirror := put_battlefield(0, "Reflecting Mirror")
	var bolt := _incoming_bolt()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, mirror, 0, [TargetRef.card(bolt)], 3),
		"X must be 2")


func test_mirror_cannot_touch_a_spell_aimed_elsewhere() -> void:
	var mirror := put_battlefield(0, "Reflecting Mirror")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, mirror, 0, [TargetRef.card(bolt)], 2),
		"Illegal target")


# ------------------------------------------------------------- Runesword --

func test_runesword_pumps_and_exiles_what_it_cuts() -> void:
	var sword := put_battlefield(0, "Runesword")
	var bear := put_battlefield(0, "Grizzly Bears")
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4, "+2/+0")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {troll.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(troll.zone, Mtg.Zone.EXILE,
		"no regeneration, and exiled instead of dying")


func test_runesword_breaks_when_its_bearer_leaves() -> void:
	var sword := put_battlefield(0, "Runesword")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, sword, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear)
	resolve_stack()
	assert_eq(sword.zone, Mtg.Zone.GRAVEYARD)


func test_runesword_needs_an_attacking_creature() -> void:
	var sword := put_battlefield(0, "Runesword")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, sword, 0, [TargetRef.card(bear)]),
		"Illegal target")


# ------------------------------------------------------ All Hallow's Eve --

func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func test_all_hallows_eve_exiles_itself_with_two_counters() -> void:
	var eve := give_hand(0, "All Hallow's Eve")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eve, []))
	resolve_stack()
	assert_eq(eve.zone, Mtg.Zone.EXILE)
	assert_eq(int(eve.counters.get("scream", 0)), 2)


func test_all_hallows_eve_raises_everyone_after_two_upkeeps() -> void:
	var mine := _bury(0, "Grizzly Bears")
	var theirs := _bury(1, "Serra Angel")
	var eve := give_hand(0, "All Hallow's Eve")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eve, []))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()   # p0's first upkeep: one counter comes off
	resolve_stack()
	assert_eq(int(eve.counters.get("scream", 0)), 1)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "not yet")
	advance_to_next_turn()
	advance_to_next_turn()   # p0's second upkeep: the screaming stops
	resolve_stack()
	assert_eq(eve.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.controller_id, 0, "each under its own owner's control")
	assert_eq(theirs.controller_id, 1)
