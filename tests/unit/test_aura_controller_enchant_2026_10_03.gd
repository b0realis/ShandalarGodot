extends GameTest
## An enchant restriction stated relative to the Aura's controller ("enchant
## creature you control" — Cocoon; "enchant artifact an opponent controls" —
## Relic Bind) is re-checked as a state-based action (CR 303.4d, 704.5m), so
## a control change of the enchanted permanent OR of the Aura makes the Aura
## fall off. Found by the Pack 8 Aura batch (Fire Whip, Betrayal) on
## 2026-10-03: the check used to read only what the host IS.


func _bound_ring() -> Array:
	var ring := put_battlefield(1, "Sol Ring")
	var aura := give_hand(0, "Relic Bind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "Relic Bind resolved onto the Ring")
	return [ring, aura]


func test_relic_bind_falls_off_when_you_gain_control_of_the_artifact() -> void:
	var pair := _bound_ring()
	var ring: CardInstance = pair[0]
	var aura: CardInstance = pair[1]
	g.change_control(ring, 0)
	g.check_state_based_actions()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD,
		"the Ring is no longer an artifact an opponent controls")
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


func test_relic_bind_falls_off_when_the_aura_changes_control() -> void:
	var pair := _bound_ring()
	var aura: CardInstance = pair[1]
	g.change_control(aura, 1)
	g.check_state_based_actions()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD,
		"its new controller controls the Ring, so the restriction fails")


func test_relic_bind_stays_while_the_restriction_holds() -> void:
	var pair := _bound_ring()
	var aura: CardInstance = pair[1]
	g.check_state_based_actions()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)


func test_cocoon_falls_off_when_the_creature_is_stolen() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var cocoon := give_hand(0, "Cocoon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, cocoon, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(cocoon.zone, Mtg.Zone.BATTLEFIELD)
	g.change_control(bears, 1)
	g.check_state_based_actions()
	assert_eq(cocoon.zone, Mtg.Zone.GRAVEYARD,
		"the Bears are no longer a creature Cocoon's controller controls")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_aura_can_enchant_reads_the_controller_filter() -> void:
	var pair := _bound_ring()
	var aura: CardInstance = pair[1]
	var mine := put_battlefield(0, "Sol Ring")
	assert_false(g.aura_can_enchant(aura, mine),
		"Relic Bind can't enchant an artifact its controller controls")
