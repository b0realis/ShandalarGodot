extends GameTest
## Pack 10 (the Urza block), batch B10: the echo ARTIFACTS and the flash
## creature of cards/sets/ulg/_echo.gd and cards/sets/uds/_echo.gd — Ring
## of Gix, Thran Weaponry (its affected set fixed as the ability resolves,
## CR 611.2c), Ticking Gnomes, Urza's Blueprints, Extruder and Simian
## Grunts.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


# --- Ring of Gix ---------------------------------------------------------------

func test_ring_of_gix_taps_an_artifact_creature_or_land() -> void:
	var ring := put_battlefield(0, "Ring of Gix")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, ring, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_true(bears.tapped)
	assert_true(ring.tapped)


func test_ring_of_gix_cannot_tap_an_enchantment() -> void:
	var ring := put_battlefield(0, "Ring of Gix")
	var aura := put_battlefield(1, "Castle")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, ring, 0, [TargetRef.card(aura)]))


# --- Thran Weaponry -------------------------------------------------------------

func _activate_weaponry(weaponry: CardInstance) -> void:
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, weaponry, 0, []))
	resolve_stack()


func test_thran_weaponry_pumps_every_creature_while_tapped() -> void:
	var weaponry := put_battlefield(0, "Thran Weaponry")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	_activate_weaponry(weaponry)
	assert_eq([mine.cur_power, mine.cur_toughness], [4, 4])
	assert_eq([theirs.cur_power, theirs.cur_toughness], [5, 5], "all creatures, the opponent's too")
	g.untap_permanent(weaponry)
	g.recalculate()
	assert_eq([mine.cur_power, mine.cur_toughness], [2, 2], "untapped: over")
	g.tap_permanent(weaponry)
	g.recalculate()
	assert_eq([mine.cur_power, mine.cur_toughness], [2, 2], "and tapping again does not bring it back")


func test_thran_weaponry_fixes_its_set_as_it_resolves() -> void:
	var weaponry := put_battlefield(0, "Thran Weaponry")
	var bears := put_battlefield(0, "Grizzly Bears")
	_activate_weaponry(weaponry)
	var late := put_battlefield(0, "Hill Giant")
	assert_eq([late.cur_power, late.cur_toughness], [3, 3], "arrived later: not affected (CR 611.2c)")
	assert_eq(bears.cur_power, 4)


func test_thran_weaponry_lasts_into_the_next_turn_when_kept_tapped() -> void:
	var weaponry := put_battlefield(0, "Thran Weaponry")
	weaponry.control_upkeep_mark = -1   # its echo long since paid
	var bears := put_battlefield(0, "Grizzly Bears")
	_activate_weaponry(weaponry)
	advance_to_next_turn()
	advance_to_next_turn()   # our untap step: the heuristic keeps it tapped
	assert_true(weaponry.tapped, "\"you may choose not to untap\" — it holds our Bears")
	assert_eq(bears.cur_power, 4, "still pumped")


func test_thran_weaponry_untapped_in_response_does_nothing() -> void:
	var weaponry := put_battlefield(0, "Thran Weaponry")
	var bears := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, weaponry, 0, []))
	g.untap_permanent(weaponry)
	resolve_stack()
	assert_eq(bears.cur_power, 2, "the duration was over before it began (CR 611.2b)")


func test_thran_weaponry_keeps_working_under_the_1997_tapped_artifact_rule() -> void:
	g.rules.set_preset("fifth")
	var weaponry := put_battlefield(0, "Thran Weaponry")
	var bears := put_battlefield(0, "Grizzly Bears")
	_activate_weaponry(weaponry)
	assert_eq(bears.cur_power, 4, "an effect about being tapped is not stopped by tapping")


func test_thran_weaponry_ends_when_it_leaves() -> void:
	var weaponry := put_battlefield(0, "Thran Weaponry")
	var bears := put_battlefield(0, "Grizzly Bears")
	_activate_weaponry(weaponry)
	g.destroy(weaponry)
	g.recalculate()
	assert_eq(bears.cur_power, 2)


# --- Ticking Gnomes, Urza's Blueprints, Extruder ------------------------------------

func test_ticking_gnomes_sacrifices_itself_for_1_damage() -> void:
	var gnomes := put_battlefield(0, "Ticking Gnomes")
	assert_ok(g.activate_ability(0, gnomes, 0, [TargetRef.player(1)]))
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is the cost")
	resolve_stack()
	assert_eq(g.players[1].life, 19)


func test_urzas_blueprints_draws_on_tap() -> void:
	var blueprints := put_battlefield(0, "Urza's Blueprints")
	var before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, blueprints, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1)
	assert_true(blueprints.tapped)
	assert_refused(g.activate_ability(0, blueprints, 0, []))


func test_extruder_sacrifices_an_artifact_for_a_counter() -> void:
	var extruder := put_battlefield(0, "Extruder")
	var star := put_battlefield(0, "Iron Star")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, extruder, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(int(bears.counters.get("+1/+1", 0)), 1)
	var gone := int(star.zone == Mtg.Zone.GRAVEYARD) + int(extruder.zone == Mtg.Zone.GRAVEYARD)
	assert_eq(gone, 1, "one artifact paid for it")


func test_extruder_may_sacrifice_itself() -> void:
	var extruder := put_battlefield(0, "Extruder")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, extruder, 0, [TargetRef.card(bears)]))
	assert_eq(extruder.zone, Mtg.Zone.GRAVEYARD, "its own cost")
	resolve_stack()
	assert_eq(int(bears.counters.get("+1/+1", 0)), 1)


# --- Simian Grunts --------------------------------------------------------------

func test_simian_grunts_flashed_in_on_the_opponents_turn_owes_echo_at_your_upkeep() -> void:
	advance_to_next_turn()   # the opponent's turn 2
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var grunts := give_hand(0, "Simian Grunts")
	add_mana(0, Mtg.ManaColor.G, 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, grunts))
	resolve_stack()
	assert_eq(grunts.zone, Mtg.Zone.BATTLEFIELD, "flash")
	assert_true(EchoAbility.due_next_upkeep(g, grunts))
	put_battlefield(0, "Forest")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	advance_to_next_turn()   # our turn 3
	assert_eq(grunts.zone, Mtg.Zone.BATTLEFIELD, "paid")
	assert_false(EchoAbility.due_next_upkeep(g, grunts))
