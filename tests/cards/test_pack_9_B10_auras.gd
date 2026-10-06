extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold Auras in
## cards/sets/sth/_auras.gd — Contempt, Conviction, Flowstone Blade,
## Overgrowth, Samite Blessing and Torment.

const CLAIMED := ["Contempt", "Conviction", "Flowstone Blade", "Overgrowth",
	"Samite Blessing", "Torment"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## Cast Aura [param card_name] from [param pid]'s hand onto [param host].
func _enchant(pid: int, card_name: String, host: CardInstance, color: int, mana: int) -> CardInstance:
	var aura := give_hand(pid, card_name)
	add_mana(pid, color, mana)
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id)
	return aura

func _index_of(i: CardInstance, text_start: String) -> int:
	for n in i.cur_activated_abilities.size():
		if i.cur_activated_abilities[n].text.begins_with(text_start): return n
	return -1


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------------- Contempt --

func test_contempt_returns_the_attacker_and_itself_after_combat() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var contempt := _enchant(0, "Contempt", bear, Mtg.ManaColor.U, 2)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "it still dealt its damage")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(contempt.zone, Mtg.Zone.HAND)

func test_contempt_on_an_opponents_creature_goes_home_to_its_owner() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var contempt := _enchant(0, "Contempt", giant, Mtg.ManaColor.U, 2)
	advance_to_next_turn()   # P1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_true(g.players[1].hand.has(giant))
	assert_true(g.players[0].hand.has(contempt), "the Aura to ITS owner's hand")

func test_contempt_dead_attacker_leaves_nothing_to_return() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var contempt := _enchant(0, "Contempt", bear, Mtg.ManaColor.U, 2)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(contempt.zone, Mtg.Zone.GRAVEYARD, "it fell off; a new object is not returned")

func test_contempt_does_nothing_while_the_creature_stays_home() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var contempt := _enchant(0, "Contempt", bear, Mtg.ManaColor.U, 2)
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(contempt.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------ Conviction --

func test_conviction_pumps_and_goes_home_for_white() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var conviction := _enchant(0, "Conviction", bear, Mtg.ManaColor.W, 2)
	assert_eq(_pt(bear), [3, 5])
	assert_refused(g.activate_ability(0, conviction, 0, []))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, conviction, 0, []))
	resolve_stack()
	assert_eq(conviction.zone, Mtg.Zone.HAND)
	assert_eq(_pt(bear), [2, 2])


# ------------------------------------------------------------- Flowstone Blade --

func test_flowstone_blade_trades_toughness_for_power() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var blade := _enchant(0, "Flowstone Blade", giant, Mtg.ManaColor.R, 1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, blade, 0, []))
	assert_ok(g.activate_ability(0, blade, 0, []))
	resolve_stack()
	assert_eq(_pt(giant), [5, 1])
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, blade, 0, []))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "toughness 0")

func test_flowstone_blade_wears_off() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var blade := _enchant(0, "Flowstone Blade", bear, Mtg.ManaColor.R, 1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, blade, 0, []))
	resolve_stack()
	assert_eq(_pt(bear), [3, 1])
	advance_to_next_turn()
	assert_eq(_pt(bear), [2, 2])


# ------------------------------------------------------------------ Overgrowth --

func test_overgrowth_adds_two_green_when_its_land_taps() -> void:
	var forest := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Overgrowth", forest, Mtg.ManaColor.G, 3)
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.total(), 3)
	assert_ok(g.tap_for_mana(0, other))
	assert_eq(g.players[0].mana_pool.total(), 4, "only the enchanted land")

func test_overgrowth_on_an_opponents_land_feeds_them() -> void:
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Overgrowth", forest, Mtg.ManaColor.G, 3)
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, forest))
	assert_eq(g.players[1].mana_pool.total(), 3, "its controller adds the {G}{G}")
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_overgrowth_enchants_only_a_land() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var overgrowth := give_hand(0, "Overgrowth")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_refused(g.cast_spell(0, overgrowth, [TargetRef.card(bear)]))


# -------------------------------------------------------------- Samite Blessing --

func test_samite_blessing_grants_a_source_shield() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Samite Blessing", bear, Mtg.ManaColor.W, 1)
	var at := _index_of(bear, "{T}: The next time")
	assert_ne(at, -1, "the enchanted creature has the ability")
	var shock := give_hand(0, "Shock")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, bear, at, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "Shock's damage prevented")
	assert_eq(bear.damage, 0)
	assert_true(bear.tapped)
	var again := give_hand(0, "Shock")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, again, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the shield is used up (CR 615.8)")

func test_samite_blessing_ability_is_a_prevention_effect_and_goes_with_the_aura() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var blessing := _enchant(0, "Samite Blessing", bear, Mtg.ManaColor.W, 1)
	var at := _index_of(bear, "{T}: The next time")
	assert_true(bear.cur_activated_abilities[at].effects[0].is_damage_prevention)
	g.destroy(blessing)
	g.recalculate()
	assert_eq(_index_of(bear, "{T}: The next time"), -1)

func test_samite_blessing_needs_an_untapped_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Samite Blessing", bear, Mtg.ManaColor.W, 1)
	g.tap_permanent(bear)
	assert_refused(g.activate_ability(0, bear, _index_of(bear, "{T}: The next time"), [TargetRef.card(bear)]))


# --------------------------------------------------------------------- Torment --

func test_torment_shrinks_power_by_three() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	var torment := _enchant(0, "Torment", giant, Mtg.ManaColor.B, 2)
	assert_eq(_pt(giant), [0, 3])
	g.destroy(torment)
	g.recalculate()
	assert_eq(_pt(giant), [3, 3])
