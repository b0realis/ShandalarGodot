extends GameTest
## Guardian Angel's rider, lifted 2026-09-02 (docs/simplified-cards.md,
## "Guardian Angel"): "Until end of turn, you may pay {1} any time you
## could cast an instant. If you do, prevent the next 1 damage that would
## be dealt to that permanent or player this turn." `Duel.hlp`: "Until end
## of turn, for each {1} you pay, you may prevent 1 damage to that creature
## or player." The payment is a seat-level game action
## (MtgGame.pay_for_prevention), the Channel shape.


func _cast_angel(x: int, target: TargetRef) -> void:
	var angel := give_hand(0, "Guardian Angel")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, x)
	assert_ok(g.cast_spell(0, angel, [target], x))
	resolve_stack()


func test_paying_one_buys_one_more_point_each_time() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_angel(1, TargetRef.card(bears))
	assert_eq(bears.prevention, 1, "X = 1 from the spell itself")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.pay_for_prevention(0, TargetRef.card(bears)))
	assert_ok(g.pay_for_prevention(0, TargetRef.card(bears)))
	assert_eq(bears.prevention, 3, "two payments, two more points")
	assert_eq(g.players[0].mana_pool.total(), 0, "each payment cost {1}")
	g.deal_damage(giant, TargetRef.card(bears), 3)
	assert_eq(bears.damage, 0, "the 3 damage was wholly prevented")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_the_rider_needs_mana_a_ward_and_priority() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Scryb Sprites")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.pay_for_prevention(0, TargetRef.card(bears)), "no prevention to buy")
	_cast_angel(0, TargetRef.card(bears))
	assert_eq(bears.prevention, 0, "X = 0 prevents nothing by itself")
	assert_refused(g.pay_for_prevention(0, TargetRef.card(other)), "no prevention to buy")
	assert_refused(g.pay_for_prevention(0, TargetRef.card(bears)), "can't pay {1}")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.pay_for_prevention(0, TargetRef.card(bears)))
	assert_eq(bears.prevention, 1, "X = 0 still grants the rider")
	assert_ok(g.pass_priority(0))
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.pay_for_prevention(0, TargetRef.card(bears)), "priority")


func test_the_rider_lasts_until_end_of_turn() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_angel(0, TargetRef.card(bears))
	assert_false(g.paid_prevention_for(0, TargetRef.card(bears)).is_empty())
	advance_to_next_turn()
	assert_true(g.paid_prevention_for(0, TargetRef.card(bears)).is_empty(),
		"cleanup forgets the rider")
	advance_to_next_turn()   # back to P0's own turn, priority in hand
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.pay_for_prevention(0, TargetRef.card(bears)), "no prevention to buy")


func test_a_warded_player_can_keep_buying() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_angel(0, TargetRef.player(0))
	add_mana(0, Mtg.ManaColor.C, 3)
	for _i in 3:
		assert_ok(g.pay_for_prevention(0, TargetRef.player(0)))
	assert_eq(g.players[0].damage_prevention, 3)
	g.deal_damage(giant, TargetRef.player(0), 5)
	assert_eq(g.players[0].life, 18, "three of the five were prevented")


func test_a_permanent_that_left_is_a_new_object() -> void:
	# CR 400.7: the Bears that come back are not "that permanent".
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_angel(0, TargetRef.card(bears))
	g.return_to_hand(bears)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.pay_for_prevention(0, TargetRef.card(bears)), "no prevention to buy")


## Bolt [param victim] from P0 and resolve it with both seats passing once,
## which is where the 1997 window opens (or auto-skips).
func _bolt(victim: CardInstance) -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(victim)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))


func test_the_window_stays_open_for_a_seat_holding_only_the_rider() -> void:
	# The window auto-skips when nobody could act in it; a seat that may
	# still pay {1} can.
	g.rules.damage_prevention_window = true
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_bolt(bears)
	assert_false(g.awaiting_damage_prevention, "nothing to do: the window auto-skipped")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	var bears2 := put_battlefield(1, "Grizzly Bears")
	g.grant_paid_prevention(1, TargetRef.card(bears2), "Guardian Angel")
	_bolt(bears2)
	assert_true(g.awaiting_damage_prevention, "the rider alone keeps the window open")


func test_the_ai_buys_exactly_what_saves_its_creature_in_the_window() -> void:
	g.rules.damage_prevention_window = true
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var bears := put_battlefield(1, "Grizzly Bears")
	for _i in 4:
		put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	g.grant_paid_prevention(1, TargetRef.card(bears), "Guardian Angel")
	_bolt(bears)
	assert_true(g.awaiting_damage_prevention)
	var said := PackedStringArray()
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration) and guard < 12:
		guard += 1
		if g.priority_player != 1:
			assert_ok(g.pass_priority(g.priority_player))
			continue
		var did := ai.act(g)
		if did != "":
			said.append(did)
	assert_true(str(said).contains("Guardian Angel"), str(said))
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Bears live")
	var tapped := 0
	for p in g.players[1].battlefield:
		if p.is_land() and p.tapped:
			tapped += 1
	assert_eq(tapped, 2, "paid {2}: enough to live, not a point more")


func test_the_ai_buys_prevention_for_a_doomed_blocker_without_the_window() -> void:
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var bears := put_battlefield(1, "Grizzly Bears")
	for _i in 3:
		put_battlefield(1, "Plains")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.grant_paid_prevention(1, TargetRef.card(bears), "Guardian Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bears.id: giant.id}))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	var did := ai.act(g)
	assert_true(did.contains("Guardian Angel"), did)
	assert_eq(bears.prevention, 2, "3 incoming against toughness 2: two points")
