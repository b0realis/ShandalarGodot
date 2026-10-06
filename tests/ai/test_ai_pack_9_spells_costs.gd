extends GameTest
## Pack 9 (the Tempest block), the fair AI's COSTS (stage 4; engine
## package E7, [member AiProfile.forecasts_tactics]).
##
## 1. THE NEW OBJECT COSTS, PRICED ([method AlliancesTactics.object_price]).
##    "Discard a card at random" is nobody's choice: it costs the AVERAGE
##    card of the hand it is rolled from, never the cheapest (Sonic Burst,
##    Flowstone Flood's buyback). "Put a card from your hand on top of your
##    library" (Penance, Hidden Retreat) costs a draw, not a card. "Remove
##    a +1/+1 counter from a creature you control" (Spike Rogue) costs the
##    counter — or the creature, when it is the last of its toughness.
## 2. HEARTSTONE. "Activated abilities of creatures cost {1} less" reached
##    the activation's own payment but not the planner's affordability
##    check ([method MtgGame.ability_surcharge] alone): a Sliver Queen on
##    one land never made a Sliver.
## 3. EVASION AFTER BLOCKS. A creature that gains shadow (or flying) once
##    its blockers are declared is still blocked (CR 506.4, 509.1h): the
##    "gains <evasion>" activation is worth nothing then.
## With the gate off the pilot prices and refuses as before Pack 9.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


const OC := preload("res://engine/additional_object_costs.gd")
const AT := preload("res://engine/ai/alliances_tactics.gd")


# --------------------------------------------------------------- object prices --

func test_a_random_discard_costs_the_average_card() -> void:
	var ai := _ai()
	var burst := give_hand(0, "Sonic Burst")
	var dragon := give_hand(0, "Shivan Dragon")
	var forest := give_hand(0, "Forest")
	var discard := OC.discarding("card")
	var cheapest := AT._object_unit_price(g, ai, discard, forest)
	var dearest := AT._object_unit_price(g, ai, discard, dragon)
	assert_gt(dearest, cheapest)
	var price: float = AT.object_price(g, ai, burst, [OC.discarding_at_random()])
	assert_almost_eq(price, (cheapest + dearest) / 2.0, 0.001, "nobody chooses the Forest")


func test_a_card_on_top_costs_a_draw() -> void:
	var ai := _ai()
	var penance := put_battlefield(0, "Penance")
	var dragon := give_hand(0, "Shivan Dragon")
	var price: float = AT.object_price(g, ai, penance, [OC.putting_on_top()])
	assert_lt(price, AT._object_unit_price(g, ai, OC.discarding("card"), dragon),
		"the card comes back as the next draw")
	assert_gt(price, 0.0)


func test_a_counter_off_a_creature_costs_the_counter_or_the_body() -> void:
	var ai := _ai()
	var feeder := put_battlefield(0, "Spike Feeder")   # enters with two counters
	feeder.counters["+1/+1"] = 2
	g.recalculate()
	var group := OC.removing_counter("+1/+1", "creature you control")
	var cheap: float = AT._object_unit_price(g, ai, group, feeder)
	feeder.counters["+1/+1"] = 1
	g.recalculate()
	var dear: float = AT._object_unit_price(g, ai, group, feeder)
	assert_lt(cheap, dear, "the last counter is the whole Spike")


# ------------------------------------------------------------------- Heartstone --

func test_heartstone_lets_the_queen_make_a_sliver_from_one_land() -> void:
	var ai := _ai()
	put_battlefield(0, "Heartstone")
	put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Plains")
	_their_turn_at(Mtg.Step.END)
	assert_eq(ai.act(g), "activated Sliver Queen", "{2} less {1} is {1}")


func test_the_null_arm_sees_the_full_price() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Heartstone")
	var queen := put_battlefield(0, "Sliver Queen")
	put_battlefield(0, "Plains")
	_their_turn_at(Mtg.Step.END)
	assert_ne(ai.act(g), "activated Sliver Queen")
	assert_eq(queen.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- evasion after blocks --

func test_shadow_bought_after_blocks_is_worth_nothing() -> void:
	var ai := _ai()
	var emissary := put_battlefield(0, "Soltari Emissary")
	var bears := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [emissary.id]))
	var before: Variant = AT.option(g, ai, emissary, 0, "COMBAT")
	assert_true(before is Dictionary and not before.is_empty(), "before blocks: an evasion")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bears.id: emissary.id}))
	var after: Variant = AT.option(g, ai, emissary, 0, "COMBAT")
	assert_true(after is Dictionary and after.is_empty(), "blocked is blocked (CR 506.4)")
