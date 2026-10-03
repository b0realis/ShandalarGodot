extends GameTest
## THE COSTS THE PLANNER NEVER REACHED (Pack 8, 2026-10-03; card batch
## B8's probes; [member AiProfile.forecasts_tactics]).
##
## 1. A PAYMENT ROW. Fireblast ("you may sacrifice two Mountains rather
##    than pay this spell's mana cost") and Spinning Darkness (three black
##    cards off the top of the graveyard) ship their own picker; the
##    planner checked and paid the PRINTED cost whatever row it cast, so
##    the row was never reached when mana was short, and with mana enough a
##    picked row would have been paid on top of it
##    ([method AiPlayer._paying_mode]).
## 2. AN OBJECT COST AS THE WHOLE PRICE. "Exile the top creature card of
##    your graveyard: Regenerate this creature" read as free — no tap, no
##    mana — and an ability that costs nothing is never offered (the sink
##    would fire it forever); a graveyard card is a finite resource and is
##    now FUEL a shield may spend ([constant AiPlayer.OBJECT_FUEL_PRICE]).
## 3. A TARGETED LIFE LOSS. Kaervek's Spite's "target player loses 5 life"
##    is a negative [GainLifeEffect]: it read as a life gain, aimed at its
##    own caster and never as lethal ([member EffectIntent.life_loss]).


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func _count(pid: int, card_name: String) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: n += 1
	return n


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


# ---------------------------------------------------------- payment rows --

func test_fireblast_sacrifices_two_mountains_for_the_win() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireblast")
	assert_eq(_count(0, "Mountain"), 0, "the two Mountains were the cost")
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	assert_eq(blast.zone, Mtg.Zone.GRAVEYARD)


func test_fireblast_never_pays_both_rows() -> void:
	# Six Mountains pay {4}{R}{R}; the picker says so, and the six stay.
	var ai := _ai()
	for _i in 6: put_battlefield(0, "Mountain")
	give_hand(0, "Fireblast")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireblast")
	assert_eq(_count(0, "Mountain"), 6, "mana paid, nothing sacrificed")


func test_fireblast_is_not_thrown_at_a_bear() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	var blast := give_hand(0, "Fireblast")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	assert_eq(blast.zone, Mtg.Zone.HAND, "two lands are not worth a 2/2")
	assert_eq(_count(0, "Mountain"), 2)


func test_spinning_darkness_pays_with_the_graveyard() -> void:
	var ai := _ai()
	for _i in 3: _in_graveyard(0, "Dark Ritual")
	var giant := put_battlefield(1, "Hill Giant")
	var darkness := give_hand(0, "Spinning Darkness")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Spinning Darkness")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].exile.size(), 3, "the three black cards were the cost")
	assert_eq(darkness.zone, Mtg.Zone.GRAVEYARD)


func test_spinning_darkness_never_pays_both_rows() -> void:
	var ai := _ai()
	var swamps: Array = []
	for _i in 6: swamps.append(put_battlefield(0, "Swamp"))
	for _i in 3: _in_graveyard(0, "Dark Ritual")
	put_battlefield(1, "Hill Giant")
	give_hand(0, "Spinning Darkness")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Spinning Darkness")
	for swamp in swamps:
		assert_false(swamp.tapped, "the graveyard paid: no Swamp tapped as well")


func test_null_arm_never_reaches_the_row() -> void:
	var ai := _ai(_null())
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(blast.zone, Mtg.Zone.HAND, "the pilot as it was")


# ------------------------------------------------------- the fuel cost --

func _zombie_blocks_a_giant() -> CardInstance:
	var zombie := put_battlefield(0, "Zombie Scavengers")
	var giant := put_battlefield(1, "Hill Giant")
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 200:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [giant.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {zombie.id: giant.id}))
	# seat 1 (active) passes; seat 0 holds priority in declare blockers
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return zombie


func test_zombie_scavengers_regenerates_off_its_graveyard() -> void:
	var ai := _ai()
	var bears := _in_graveyard(0, "Grizzly Bears")
	var zombie := _zombie_blocks_a_giant()
	assert_string_contains(ai.act(g), "shields Zombie Scavengers")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.EXILE, "the top creature card was the cost")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(zombie.zone, Mtg.Zone.BATTLEFIELD, "regenerated (CR 701.15)")


func test_zombie_scavengers_cannot_regenerate_on_lands() -> void:
	var ai := _ai()
	_in_graveyard(0, "Swamp")
	var zombie := _zombie_blocks_a_giant()
	assert_false(ai.act(g).contains("shields"), "no creature card to exile")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(zombie.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------ the life loss --

func test_kaervek_s_spite_is_cast_for_the_win() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Swamp")
	put_battlefield(0, "Grizzly Bears")
	var spite := give_hand(0, "Kaervek's Spite")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Kaervek's Spite")
	assert_eq(g.stack.back().targets[0].player_id, 1, "at them, never at itself")
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	assert_eq(spite.zone, Mtg.Zone.GRAVEYARD)


func test_a_drain_is_aimed_at_the_opponent() -> void:
	var ai := _ai()
	var spite := give_hand(0, "Kaervek's Spite")
	var effect: EffectBase = spite.data.spell_effects[0]
	var intent := EffectIntent.read(spite.data.spell_effects, spite.data.card_name)
	assert_eq(intent.life_loss, 5)
	assert_eq(intent.life_gain, 0, "no longer read as a gain of -5")
	assert_true(intent.is_harmful())
	var pick: TargetRef = ai._pick_for_spec(g, spite, effect.target_spec, effect, 0)
	assert_eq(pick.player_id, 1)


func test_an_untargeted_life_loss_keeps_its_old_reading() -> void:
	# "You lose 2 life" is the caster's own price: unchanged, so no deck
	# that does not hold a targeted drain sees a different pilot.
	var intent := EffectIntent.read([GainLifeEffect.new(-2)])
	assert_eq(intent.life_loss, 0)
	assert_eq(intent.life_gain, -2)


# ------------------------------------------ in a real duel loop (audit, C) --
#
# The audit cast Fireblast once (paying mana) and Kaervek's Spite never:
# the situations did not come up in 18 games. These put the lethal board
# in front of two AI seats and let AiPlayer.act drive the duel — every
# step, both seats, nothing called by hand.

func _duel_loop(max_turns := 4) -> void:
	var a := _ai()
	var b := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, b)
	var guard := 0
	var start := g.turn_number
	while not g.game_over and g.turn_number <= start + max_turns and guard < 4000:
		if a.act(g) == "" and b.act(g) == "" and not g.game_over:
			break
		guard += 1


func test_fireblast_s_mountains_win_a_duel_loop() -> void:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var blast := give_hand(0, "Fireblast")
	put_battlefield(1, "Wall of Stone")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	_duel_loop()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	assert_eq(blast.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_count(0, "Mountain"), 0, "won with the sacrifice row")


func test_kaervek_s_spite_wins_a_duel_loop() -> void:
	for _i in 3: put_battlefield(0, "Swamp")
	var spite := give_hand(0, "Kaervek's Spite")
	put_battlefield(1, "Wall of Stone")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	_duel_loop()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	assert_eq(spite.zone, Mtg.Zone.GRAVEYARD)
