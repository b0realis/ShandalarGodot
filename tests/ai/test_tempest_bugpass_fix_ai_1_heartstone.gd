extends GameTest
## Pack 9 bug pass (h5-3): the AI pays a creature's ability at the price
## the ENGINE charges ([member AiProfile.forecasts_tactics]).
##
## Heartstone ("Activated abilities of creatures cost {1} less to activate.
## This effect can't reduce the mana in that cost to less than one mana")
## is in [method MtgGame.ability_payment] — a floored reduction — and not
## in the plain surcharge the AI's pricing and paying sites read. So a
## Screeching Harpy's {1}{B} regeneration tapped two Swamps where the engine
## charged {B}, and the spare {B} burned under the mana-burn presets. The
## sites now read [method AiPlayer._ability_extra]. With the gate off, the
## plain surcharge, as before. The opponent's hidden hand never moves it.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


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


## Their Bolt on our Harpy, our priority; returns [ai line, swamps].
func _bolt_the_harpy(on: bool, their_hand: Array = []) -> Array:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(on)
	var harpy := put_battlefield(0, "Screeching Harpy")
	var swamps := [put_battlefield(0, "Swamp"), put_battlefield(0, "Swamp")]
	put_battlefield(1, "Heartstone")
	for card_name in their_hand: give_hand(1, card_name)
	assert_eq(int(g.ability_payment(0, harpy, 0)["extra"]), -1, "precondition: {1}{B} costs {B}")
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(harpy)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var line := ai.act(g)
	var tapped := 0
	for s in swamps:
		if s.tapped: tapped += 1
	return [line, tapped, harpy]


func test_the_harpy_regenerates_under_heartstone_for_one_swamp() -> void:
	var out := _bolt_the_harpy(true)
	assert_string_contains(out[0], "Screeching Harpy", "the AI shields its Harpy")
	assert_eq(out[1], 1, "one Swamp pays {B}")
	assert_eq(g.players[0].mana_pool.total(), 0, "no mana left floating to burn")
	resolve_stack()
	assert_eq((out[2] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, "the shield saved it")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.players[0].life, 20, "modern_mana_burn: nothing burned")


func test_gate_off_pays_the_printed_price() -> void:
	var out := _bolt_the_harpy(false)
	assert_eq(out[1], 2, "gate off: the plain surcharge plans {1}{B}, as before")


func test_the_shield_price_ignores_their_hidden_hand() -> void:
	var taps: Array = []
	for hand in [["Counterspell", "Shivan Dragon"], ["Forest"], []]:
		g = null
		before_each()
		taps.append(_bolt_the_harpy(true, hand)[1])
	assert_eq(taps, [1, 1, 1])


## The combat maths' "can it put up a shield?" ([method AiPlayer._can_shield])
## asks the same price: one Swamp is a shield under Heartstone.
func test_one_swamp_is_a_shield_under_heartstone() -> void:
	var on := _ai(true)
	var harpy := put_battlefield(0, "Screeching Harpy")
	put_battlefield(0, "Swamp")
	put_battlefield(1, "Heartstone")
	assert_true(on._can_shield(g, harpy))
	var off := _ai(false)
	assert_false(off._can_shield(g, harpy), "gate off: {1}{B} from one Swamp, as before")


## Their side too: their Harpy behind one Swamp is shieldable under
## Heartstone ([method AiPlayer._shieldable] reads their public mana).
func test_their_harpy_behind_one_swamp_is_shieldable_under_heartstone() -> void:
	var ai := _ai(true)
	var harpy := put_battlefield(1, "Screeching Harpy")
	put_battlefield(1, "Swamp")
	put_battlefield(0, "Heartstone")
	assert_true(ai._shieldable(g, harpy))
	var off := _ai(false)
	assert_false(off._shieldable(g, harpy), "gate off: as before")
