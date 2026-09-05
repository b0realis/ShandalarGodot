extends GameTest
## Wave-9 tests: sweepers and prison pieces (Inferno, Moat), artifact hate
## with life riders (Divine Offering, Crumble), exile removal (Ashes to
## Ashes), ramp tutoring onto the battlefield (Untamed Wilds), the
## land-sting aura (Psychic Venom), and utility bodies (Ghost Ship, Blood
## Lust, Aladdin's Ring).


# --------------------------------------------------------------- Inferno --

func test_inferno_burns_everything_including_players() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	var inferno := give_hand(0, "Inferno")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, inferno, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "6 kills the 2/2")
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD, "6 kills the 4/4 — even the caster's foes' angels")
	assert_eq(g.players[0].life, 14, "the caster burns too")
	assert_eq(g.players[1].life, 14)


# ------------------------------------------------------------------ Moat --

func test_moat_grounds_non_flyers() -> void:
	put_battlefield(1, "Moat")
	var bear := put_battlefield(0, "Grizzly Bears")
	var serra := put_battlefield(0, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "can't attack")
	assert_ok(g.declare_attackers(0, [serra.id]))


func test_moat_lifts_when_destroyed() -> void:
	var moat := put_battlefield(1, "Moat")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(moat, false)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]), )


# ------------------------------------------------------------- Blood Lust --

func test_blood_lust_pumps_but_leaves_one_toughness() -> void:
	# A 2/2: +4/-X where X = toughness - 1 → 6/1.
	var bear := put_battlefield(0, "Grizzly Bears")
	var lust := give_hand(0, "Blood Lust")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lust, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 6)
	assert_eq(bear.cur_toughness, 1, "toughness floors at 1, not 0")


func test_blood_lust_full_minus_four_on_big_toughness() -> void:
	# Toughness 5+: the printed +4/-4 applies in full (a 0/8 Wall → 4/4).
	var wall := put_battlefield(0, "Wall of Stone")
	var lust := give_hand(0, "Blood Lust")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lust, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.cur_power, 4)
	assert_eq(wall.cur_toughness, 4)


# ------------------------------------------------------- artifact removal --

func test_divine_offering_destroys_and_feeds_its_caster() -> void:
	var juggernaut := put_battlefield(1, "Juggernaut")   # mana value 4
	var offering := give_hand(0, "Divine Offering")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, offering, [TargetRef.card(juggernaut)]))
	resolve_stack()
	assert_eq(juggernaut.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 24, "the CASTER gains its mana value (4)")


func test_crumble_feeds_the_artifacts_controller_instead() -> void:
	var juggernaut := put_battlefield(1, "Juggernaut")
	var crumble := give_hand(0, "Crumble")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, crumble, [TargetRef.card(juggernaut)]))
	resolve_stack()
	assert_eq(juggernaut.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 24, "the OWNER'S consolation prize (4 life)")
	assert_eq(g.players[0].life, 20, "the caster gets nothing")


func test_crumble_ignores_regeneration() -> void:
	# "It can't be regenerated": a shielded artifact creature still dies.
	var golem := put_battlefield(1, "Obsianus Golem")
	golem.regeneration_shields = 1
	var crumble := give_hand(0, "Crumble")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, crumble, [TargetRef.card(golem)]))
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD, "the shield is useless")


# --------------------------------------------------------- Ashes to Ashes --

func test_ashes_to_ashes_exiles_two_for_five_life() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	var ashes := give_hand(0, "Ashes to Ashes")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, ashes, [TargetRef.card(bear), TargetRef.card(serra)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "gone for good — no graveyard recursion")
	assert_eq(serra.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].life, 15, "the 5-damage price")


func test_ashes_to_ashes_refuses_artifact_creatures() -> void:
	var golem := put_battlefield(1, "Obsianus Golem")
	var bear := put_battlefield(1, "Grizzly Bears")
	var ashes := give_hand(0, "Ashes to Ashes")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, ashes, [TargetRef.card(golem), TargetRef.card(bear)]),
		"Illegal target")


# --------------------------------------------------------- Untamed Wilds --

func test_untamed_wilds_puts_a_basic_onto_the_battlefield() -> void:
	var wilds := give_hand(0, "Untamed Wilds")
	var lands_before := g.players[0].battlefield.size()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wilds, []))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), lands_before + 1,
		"a basic land arrived (the filler library is all Forests)")
	var fetched: CardInstance = g.players[0].battlefield.back()
	assert_true(fetched.is_land())
	assert_true(fetched.summoning_sick, "entered this turn like any permanent")


# --------------------------------------------------------- Psychic Venom --

func test_psychic_venom_stings_the_tapping_controller() -> void:
	var swamp := put_battlefield(1, "Swamp")
	var venom := give_hand(0, "Psychic Venom")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, venom, [TargetRef.card(swamp)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, swamp))
	resolve_stack()   # the sting trigger
	assert_eq(g.players[1].life, 18, "2 damage for tapping their own land")
	assert_eq(g.players[0].life, 20, "the venom's owner is safe")


# ------------------------------------------------------------ Ghost Ship --

func test_ghost_ship_flies_and_regenerates() -> void:
	var ship := put_battlefield(0, "Ghost Ship")
	assert_true(ship.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.activate_ability(0, ship, 0, []))
	resolve_stack()
	assert_eq(ship.regeneration_shields, 1)
	g.destroy(ship, true)
	assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "the ship sails on")


# -------------------------------------------------------- Aladdin's Ring --

func test_aladdins_ring_pings_for_four() -> void:
	var ring := put_battlefield(0, "Aladdin's Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 8)
	assert_ok(g.activate_ability(0, ring, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16)
	assert_true(ring.tapped)
