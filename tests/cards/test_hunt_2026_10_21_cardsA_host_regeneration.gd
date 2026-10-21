extends GameTest
## REGENERATION AND THE BRUTE AND THE SEARCH JOURNAL (bug hunt 2026-10-21,
## cardsA).
##
## Both Auras put their shield on the creature they ENCHANT — an object that
## is neither the ability's source nor its target, so the journal's
## whole-object record of a resolving item never covers it (the boundary
## `engine/undo_log.gd` writes down). They wrote `regeneration_shields`
## by hand without noting the old value, where `RegenerateEffect` and Pack
## 8's host shield both call `MtgGame._rec` first. A search that activated
## the Aura and unmade the move (CARD-COMBOS' walk tries every activated
## ability on its own table it can pay for) left the shield on the real
## creature, which could then survive a lethal hit for free that turn.


func _shield_and_unmake(aura_name: String, color: int, amount: int) -> CardInstance:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, aura_name)
	g.attach_aura_from_anywhere(aura, bear, 0)
	advance_to_step(Mtg.Step.MAIN1)
	var mark := g.make_mark()
	add_mana(0, color, amount)
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1, "the move really shielded the host")
	g.unmake_to(mark)
	g.end_search()
	return bear


func test_regeneration_shield_is_unmade_with_the_move() -> void:
	var bear := _shield_and_unmake("Regeneration", Mtg.ManaColor.G, 1)
	assert_eq(bear.regeneration_shields, 0,
		"a searched activation must leave no shield behind")


func test_the_brute_shield_is_unmade_with_the_move() -> void:
	var bear := _shield_and_unmake("The Brute", Mtg.ManaColor.R, 3)
	assert_eq(bear.regeneration_shields, 0,
		"a searched activation must leave no shield behind")


func test_regeneration_still_saves_its_host_for_real() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Regeneration")
	g.attach_aura_from_anywhere(aura, bear, 0)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, aura, 0, []))
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the shield is spent, the bear lives")
	assert_true(bear.tapped)
