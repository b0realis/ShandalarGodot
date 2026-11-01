extends GameTest
## Pack 2 recheck: absent mana costs and timestamped ability grants.

var pack_was_enabled := false

func before_each() -> void:
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	super.before_each()

func after_each() -> void:
	g = null
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

func net(host: CardInstance) -> CardInstance:
	var aura := give_hand(0, "Merseine")
	g.attach_aura_from_anywhere(aura, host, 0)
	g.tap_permanent(host)
	advance_to_step(Mtg.Step.MAIN1)
	return aura

func test_merseine_no_mana_cost_is_unpayable() -> void:
	var token := CardData.new("Saproling", "", Mtg.CardType.CREATURE)
	token.power = 1
	token.toughness = 1
	var host := g.create_token(0, token)[0]
	var aura := net(host)
	assert_refused(g.activate_ability(0, aura, 0))
	assert_eq(int(aura.counters.get("net", 0)), 3)
	assert_true(host.cur_skips_untap)

func test_merseine_printed_zero_is_payable() -> void:
	var aura := net(put_battlefield(0, "Ornithopter"))
	assert_ok(g.activate_ability(0, aura, 0))
	resolve_stack()
	assert_eq(int(aura.counters.get("net", 0)), 2)

func test_merseine_copied_token_keeps_its_copiable_mana_cost() -> void:
	var host := g.create_token(0, CardRegistry.get_card("Grizzly Bears"))[0]
	var aura := net(host)
	assert_refused(g.activate_ability(0, aura, 0))
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, aura, 0))
	resolve_stack()
	assert_eq(int(aura.counters.get("net", 0)), 2)

func humility() -> CardInstance:
	# Use the shipped card script without requiring Pack 9's artwork.
	return put_synthetic(1, load("res://cards/sets/tmp/humility.gd").new().build())

func test_newer_humility_removes_earlier_shroud() -> void:
	var spawn := put_battlefield(0, "Deep Spawn")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, spawn, 0))
	resolve_stack()
	assert_true(spawn.cur_shroud)
	humility()
	g.recalculate()
	assert_false(spawn.cur_shroud)

func test_shroud_resolving_after_humility_still_applies_then_expires() -> void:
	var priest := put_battlefield(0, "Svyelunite Priest")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.activate_ability(0, priest, 0, [TargetRef.card(bear)]))
	humility()
	resolve_stack()
	assert_true(bear.cur_shroud, "the ability on the stack survives Humility")
	advance_to_next_turn()
	assert_false(bear.cur_shroud, "the floating grant expires normally")
