extends GameTest
## THE PACK 9 BUG PASS, fix-ai-2 — the Mirage and Tempest tactics price
## what the ENGINE charges ([member AiProfile.forecasts_tactics]):
##  * h5-3: an ability tool (a phase-out, a damage shield, a shadow grant,
##    the Lion's Eye Diamond's check) is planned through
##    [method MtgGame.ability_payment] — Heartstone's floored {1} off a
##    creature's ability makes Mist Dragon's {3}{U}{U} phase-out payable from
##    four Islands (mirage_tactics.gd `ability_mana`);
##  * h2-1: a {0} spell under a discount (Helm of Awakening: surcharge -1,
##    clamped to nothing by the engine) is free to these readers, as it is
##    without the Helm.
## Null arms (gate off) and a hidden-information permutation.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Our Mist Dragon and four Islands; [param heartstone] puts one on their
## side (it reduces every creature's ability). Their Terror is aimed at the
## Dragon and we hold priority.
func _terror_at_the_dragon(heartstone: bool) -> CardInstance:
	var dragon := put_battlefield(0, "Mist Dragon")
	for _i in 4: put_battlefield(0, "Island")
	if heartstone:
		put_battlefield(1, "Heartstone")
	_their_main()
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(dragon)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return dragon


# ---------------------------------------------------- h5-3: the ability's price --

func test_the_tool_is_priced_as_the_engine_charges_it() -> void:
	var ai := _ai()
	var dragon := _terror_at_the_dragon(true)
	var index := 2
	assert_eq(int(g.ability_payment(0, dragon, index)["extra"]), -1, "precondition: {1} off")
	assert_eq(M.ability_mana(g, ai, dragon, index, ai._mana_sources(g)), 4)


func test_mist_dragon_phases_out_of_a_terror_under_heartstone() -> void:
	var ai := _ai()
	var dragon := _terror_at_the_dragon(true)
	var line := ai.act(g)
	assert_string_contains(line, "phases out", "{2}{U}{U} from four Islands")
	resolve_stack()
	assert_true(dragon.phased_out)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")


func test_without_heartstone_four_islands_do_not_pay_for_it() -> void:
	var ai := _ai()
	var dragon := _terror_at_the_dragon(false)
	assert_eq(M.ability_mana(g, ai, dragon, 2, ai._mana_sources(g)), -1)
	assert_false(ai.act(g).contains("phases out"))


func test_the_null_arm_lets_the_terror_resolve() -> void:
	var ai := _ai(false)
	var dragon := _terror_at_the_dragon(true)
	assert_false(ai.act(g).contains("phases out"))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)


func test_the_phase_out_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		give_hand(1, "Giant Growth" if variant == 0 else "Counterspell")
		if variant == 1: g.players[1].library.reverse()
		_terror_at_the_dragon(true)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the answer")


# ------------------------------------------- h2-1: a free card under a discount --

## King Cheetah would wait for an ambush of their Elves — unless another
## card wants the turn. A {0} Ornithopter is such a card with or without
## Helm of Awakening's {1} off (an unclamped -1 used to read it unpayable).
func _cheetah_board(helm: bool) -> CardInstance:
	for _i in 4: put_battlefield(0, "Forest")
	var cheetah := give_hand(0, "King Cheetah")
	give_hand(0, "Ornithopter")
	put_battlefield(1, "Llanowar Elves")
	if helm:
		put_battlefield(1, "Helm of Awakening")
	advance_to_step(Mtg.Step.MAIN1)
	return cheetah


func test_a_free_card_under_a_discount_is_still_free() -> void:
	var ai := _ai()
	var plain := M.flash_creature_waits(g, ai, _cheetah_board(false))
	before_each()
	ai = _ai()
	var cheetah := _cheetah_board(true)
	assert_lt(g.spell_surcharge(0, CardRegistry.get_card("Ornithopter")), 0, "precondition: the Helm's -1")
	assert_eq(M.flash_creature_waits(g, ai, cheetah), plain,
		"the Helm's discount on a {0} card changes nothing")


func test_the_null_arm_never_holds_the_cheetah() -> void:
	var ai := _ai(false)
	assert_false(M.flash_creature_waits(g, ai, _cheetah_board(true)))
