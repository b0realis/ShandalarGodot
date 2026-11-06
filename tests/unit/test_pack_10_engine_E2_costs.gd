extends GameTest
## Pack 10 engine package E2 — the two activation-cost readings the Urza
## block adds beside cycling:
##
##  * A LIFE COST WORKED OUT AS IT IS PAID — Lurking Evil's "Pay half your
##    life, rounded up:" (`ActivatedAbility.with_life_cost_fn` /
##    `with_half_life_cost`, read by `MtgGame.ability_life_cost`). CR 107.1a
##    rounding; CR 119.4 a player can always pay 0 life.
##  * THE GRANTOR LINK — Archery Training's granted "{T}: This creature
##    deals X damage …, where X is the number of arrow counters on Archery
##    Training": a granted ability that reads the permanent GRANTING it
##    (`ActivatedAbility.granted_by`, `grantor_counters`; CR 613.7, 608.2h).
##
## Both pinned on synthetic cards; the real cards are the batches'.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ------------------------------------------------------- the half-life cost --

## "Pay half your life, rounded up: draw a card." on an enchantment.
static func _lurker() -> CardData:
	return CardData.new("Test Lurker", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [DrawEffect.new(1)],
			"Pay half your life, rounded up: Draw a card.").with_half_life_cost())


func test_half_your_life_rounded_up_is_paid_as_the_cost() -> void:
	var lurker := put_synthetic(0, _lurker())
	var ability: ActivatedAbility = lurker.cur_activated_abilities[0]
	assert_true(ability.has_life_cost())
	assert_eq(ability.life_cost, 0, "the fixed field stays unset")
	g.players[0].life = 7
	assert_eq(g.ability_life_cost(0, lurker, ability), 4, "7 pays 4 (rounded up)")
	var hand_before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, lurker, 0))
	assert_eq(g.players[0].life, 3, "paid on activation, before it resolves")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before + 1)


func test_half_of_an_even_life_and_of_one_life() -> void:
	var lurker := put_synthetic(0, _lurker())
	var ability: ActivatedAbility = lurker.cur_activated_abilities[0]
	g.players[0].life = 20
	assert_eq(g.ability_life_cost(0, lurker, ability), 10)
	g.players[0].life = 1
	assert_eq(g.ability_life_cost(0, lurker, ability), 1)
	assert_eq(g.ability_announce_refusal(0, lurker, 0), "", "1 life can pay 1")


func test_zero_or_negative_life_pays_zero_and_is_never_refused() -> void:
	var lurker := put_synthetic(0, _lurker())
	var ability: ActivatedAbility = lurker.cur_activated_abilities[0]
	g.players[0].life = 0
	assert_eq(g.ability_life_cost(0, lurker, ability), 0, "CR 119.4: 0 life can always be paid")
	assert_eq(g._ability_resource_checks(0, lurker, ability), "")
	g.players[0].life = -3
	assert_eq(g.ability_life_cost(0, lurker, ability), 0, "never a negative payment (CR 107.1b)")
	assert_eq(g._ability_resource_checks(0, lurker, ability), "")


func test_the_amount_paid_is_on_the_activation_record() -> void:
	var seen: Array = []
	var data := _lurker()
	data.activated_abilities[0].on_cost_paid = func(_game: MtgGame, _source: CardInstance, paid: Dictionary) -> void:
		seen.append(int(paid.get("_life_paid", -1)))
	var lurker := put_synthetic(0, data)
	g.players[0].life = 9
	assert_ok(g.activate_ability(0, lurker, 0))
	assert_eq(seen, [5])
	assert_eq(g.players[0].life, 4)


func test_a_fixed_life_cost_still_refuses_what_it_cannot_pay() -> void:
	var greed := put_synthetic(0, CardData.new("Test Greed", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false, [DrawEffect.new(1)], "Pay 5 life: Draw a card.") \
			.with_life_cost(5)))
	var ability: ActivatedAbility = greed.cur_activated_abilities[0]
	assert_true(ability.has_life_cost())
	g.players[0].life = 4
	assert_eq(g.ability_life_cost(0, greed, ability), 5)
	assert_refused(g.activate_ability(0, greed, 0), "not enough life to pay 5")
	assert_eq(g.players[0].life, 4)


func test_an_ability_without_a_life_cost_reads_zero() -> void:
	var plain := ActivatedAbility.new("{1}", false, [DrawEffect.new(1)], "{1}: Draw a card.")
	assert_false(plain.has_life_cost())
	var holder := put_synthetic(0, CardData.new("Test Holder", "{1}", Mtg.CardType.ARTIFACT).activated(plain))
	assert_eq(g.ability_life_cost(0, holder, plain), 0)
	assert_eq(g.ability_life_cost(0, holder, null), 0)


# ---------------------------------------------------------- the grantor --

## "deals X damage to target player, where X is the number of arrow
## counters on the Aura that granted this" — read at resolution.
class ArrowShot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.adjust_life(target.player_id, -ActivatedAbility.grantor_counters(game, "arrow"))


## An Aura granting its host that ability, the copy linked to ITSELF.
static func _training() -> CardData:
	var shot := ActivatedAbility.new("", true, [ArrowShot.new()],
		"{T}: This creature deals X damage to target player, where X is the number of arrow counters on Test Training.")
	return CardData.new("Test Training", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_grant.bind(shot),
			"Enchanted creature has \"{T}: This creature deals X damage to target player.\"").changing_abilities())


static func _grant(game: MtgGame, aura: CardInstance, shot: ActivatedAbility) -> void:
	var host := game.find_instance(aura.attached_to)
	if game.is_present(host):
		host.cur_activated_abilities.append(shot.granted_by(aura))


func _aura_on(host: CardInstance, data: CardData, arrows: int) -> CardInstance:
	var aura := CardInstance.new(data, g._next_instance_id, host.controller_id)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	g._put_on_battlefield(aura, host.controller_id, host)
	if arrows > 0:
		g.add_counters(aura, "arrow", arrows)
	g.recalculate()
	return aura


func _bear(pid := 0) -> CardInstance:
	return put_synthetic(pid, CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2))


static func _index_from(host: CardInstance, aura: CardInstance) -> int:
	for i in host.cur_activated_abilities.size():
		if host.cur_activated_abilities[i].grantor_id == aura.id:
			return i
	return -1


func test_two_auras_on_one_creature_each_read_their_own_counters() -> void:
	var data := _training()
	var bear := _bear()
	var one := _aura_on(bear, data, 1)
	var three := _aura_on(bear, data, 3)
	assert_eq(bear.cur_activated_abilities.size(), 2, "one ability from each Aura")
	assert_ne(_index_from(bear, one), -1)
	assert_ne(_index_from(bear, three), -1)
	assert_ok(g.activate_ability(0, bear, _index_from(bear, one), [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the first Aura's one arrow")
	bear.tapped = false
	assert_ok(g.activate_ability(0, bear, _index_from(bear, three), [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "the second Aura's three")


func test_the_granted_copy_keeps_one_identity_across_recalculations() -> void:
	var data := _training()
	var bear := _bear()
	var aura := _aura_on(bear, data, 1)
	var before: ActivatedAbility = bear.cur_activated_abilities[_index_from(bear, aura)]
	g.recalculate()
	g.recalculate()
	assert_same(bear.cur_activated_abilities[_index_from(bear, aura)], before)
	assert_eq(before.grantor_id, aura.id)
	# The printed ability is untouched, and a copy of the original carries
	# no cache of its own copies (no reference cycle).
	var printed: ActivatedAbility = before.shallow_copy()
	assert_true(printed._granted_copies.is_empty())


func test_a_grantor_gone_in_response_is_read_as_it_last_was() -> void:
	var data := _training()
	var bear := _bear()
	var aura := _aura_on(bear, data, 2)
	assert_ok(g.activate_ability(0, bear, _index_from(bear, aura), [TargetRef.player(1)]))
	g.card_to_graveyard_from_anywhere(aura)   # destroyed in response
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "last known information: two arrows (CR 608.2h)")


func test_a_counter_added_in_response_counts_while_the_grantor_stays() -> void:
	var data := _training()
	var bear := _bear()
	var aura := _aura_on(bear, data, 1)
	assert_ok(g.activate_ability(0, bear, _index_from(bear, aura), [TargetRef.player(1)]))
	g.add_counters(aura, "arrow", 2)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "X is counted as it resolves")


func test_a_printed_ability_has_no_grantor() -> void:
	var shot := ActivatedAbility.new("", true, [ArrowShot.new()], "{T}: X damage.")
	assert_eq(shot.grantor_id, -1)
	assert_same(shot.granted_by(null), shot)
	var gun := put_synthetic(0, CardData.new("Test Gun", "{3}", Mtg.CardType.ARTIFACT).activated(shot))
	g.add_counters(gun, "arrow", 4)
	assert_ok(g.activate_ability(0, gun, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "no grantor, no X")


func test_the_grantor_link_round_trips_under_the_journal() -> void:
	var data := _training()
	var bear := _bear()
	var aura := _aura_on(bear, data, 2)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, bear, _index_from(bear, aura), [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[1].life, 20)
	assert_false(bear.tapped)
	assert_eq(_index_from(bear, aura), 0, "the same copy is granted again")
