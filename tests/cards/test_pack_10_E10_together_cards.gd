extends GameTest
## Pack 10 E10's cards: the ones whose cards now arrive at ONE moment through
## MtgGame.put_onto_battlefield_together — Victimize (lifting its
## "one after another" ledger row) and Planar Birth (cards/sets/usg/
## _choices.gd, _spells.gd). Exhume has tests/cards/test_pack_10_B1_exhume.gd;
## Living Death (Pack 9) is pinned in
## tests/unit/test_pack_10_engine_E10_arrive_together.gd.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _pay(pid: int, card_name: String) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst


## "Whenever another creature enters, you gain 1 life" — a synthetic Soul
## Warden, independent of any pack.
static func _warden() -> CardData:
	var c := CardData.new("Test Warden", "{W}", Mtg.CardType.CREATURE).pt(1, 1)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		func(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(s.controller_id, 1),
		"Whenever another creature enters, you gain 1 life.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
			var other: CardInstance = e.data.get("instance")
			return other != s and other != null and other.is_creature()))


## "Whenever a land enters, you gain 1 life" — counts land arrivals.
static func _land_watcher() -> CardData:
	var c := CardData.new("Test Surveyor", "{G}", Mtg.CardType.ENCHANTMENT)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		func(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(s.controller_id, 1),
		"Whenever a land enters, you gain 1 life.",
		func(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
			var other: CardInstance = e.data.get("instance")
			return other != null and other.is_land()))


func test_victimizes_two_cards_arrive_together() -> void:
	var wurm := _grave(0, "Craw Wurm")
	var warden := give_synthetic(0, _warden())
	g.discard_cards(0, [warden])
	put_battlefield(0, "Grizzly Bears")   # the sacrifice
	var victimize := give_hand(0, "Victimize")
	_pay(0, "Victimize")
	# The Warden is the SECOND target: one after another it would have
	# arrived after the Wurm and seen nothing.
	assert_ok(g.cast_spell(0, victimize, [TargetRef.card(wurm), TargetRef.card(warden)]))
	var life := g.players[0].life
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(warden.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wurm.tapped and warden.tapped, "both return tapped")
	assert_eq(g.players[0].life, life + 1, "the returned Warden saw the Wurm arrive with it")


func test_planar_births_lands_arrive_together_tapped() -> void:
	put_synthetic(0, _land_watcher())
	var plains := _grave(0, "Plains")
	var swamp := _grave(1, "Swamp")
	var birth := give_hand(0, "Planar Birth")
	_pay(0, "Planar Birth")
	var life := g.players[0].life
	assert_ok(g.cast_spell(0, birth))
	resolve_stack()
	for land in [plains, swamp]:
		assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
		assert_true(land.tapped)
	assert_eq(swamp.controller_id, 1)
	assert_eq(g.players[0].life, life + 2, "two land arrivals announced")
