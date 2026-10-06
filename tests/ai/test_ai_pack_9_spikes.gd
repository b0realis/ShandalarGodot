extends GameTest
## SPIKES, READ BY THE FAIR AI (Pack 9, card batch B3; CR 602.2b;
## [member AiProfile.forecasts_tactics]; engine/ai/tempest_tactics.gd).
##
## "{2}, Remove a +1/+1 counter from this creature: Put a +1/+1 counter on
## target creature" pays with the Spike's own body (a printed 0/0). The
## shared scorer never spends a body counter (AiPlayer._counter_cost_spendable)
## and the Homelands stat-counter reading stands aside for it; the Tempest
## module spends one only where it is priced:
##  * the Spike is dying anyway — their removal on the stack, the combat
##    damage about to be dealt — so each counter buys what it can: a
##    regeneration shield that keeps the Spike (Spike Hatcher), else a
##    counter on our best other creature;
##  * at their end step, a Spike their board blocks hands a counter to our
##    attacker it cannot block, and keeps its last one.
## The null arm (gate off) spends nothing; the opponent's hidden hand does
## not move a decision.


func before_each() -> void:
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


func _spike(name: String, counters: int) -> CardInstance:
	var spike := put_battlefield(0, name)
	spike.counters["+1/+1"] = counters
	g.recalculate()
	return spike


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func _they_cast_at(spell: String, target: CardInstance, colours: Array) -> void:
	_their_main()
	var card := give_hand(1, spell)
	for c in colours: add_mana(1, c)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## Act for seat 0 and pass for seat 1 until the stack is empty; the lines.
func _answer_until_resolved(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and guard < 40:
		if g.priority_player == 0:
			lines.append(ai.act(g))
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	return lines


# ------------------------------------------------------------- the save --

func test_a_spike_their_terror_kills_moves_its_counters_first() -> void:
	var ai := _ai()
	var feeder := _spike("Spike Feeder", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	_lands("Forest", 4)
	_they_cast_at("Terror", feeder, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	var lines := _answer_until_resolved(ai)
	assert_string_contains(str(lines), "activated Spike Feeder")
	assert_eq(int(bears.counters.get("+1/+1", 0)), 2, "both counters landed on the Bears")
	assert_eq(feeder.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_lets_the_counters_die() -> void:
	var ai := _ai(false)
	var feeder := _spike("Spike Feeder", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	_lands("Forest", 4)
	_they_cast_at("Terror", feeder, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_answer_until_resolved(ai)
	assert_eq(int(bears.counters.get("+1/+1", 0)), 0)


func test_spike_hatcher_regenerates_out_of_a_lost_block() -> void:
	var ai := _ai()
	var hatcher := _spike("Spike Hatcher", 3)
	_lands("Forest", 2)
	var wurm := put_battlefield(1, "Craw Wurm")
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [wurm.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {hatcher.id: wurm.id}))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_string_contains(ai.act(g), "activated Spike Hatcher")
	assert_eq(int(hatcher.counters.get("+1/+1", 0)), 2)
	_answer_until_resolved(ai)
	assert_eq(hatcher.regeneration_shields, 1, "the shield keeps the Spike")


func test_a_healthy_spike_spends_nothing() -> void:
	var ai := _ai()
	var feeder := _spike("Spike Feeder", 2)
	put_battlefield(0, "Grizzly Bears")
	_lands("Forest", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_eq(int(feeder.counters.get("+1/+1", 0)), 2)


# ------------------------------------------------------------ the shift --

## Their end step with seat 0 holding priority, the stack empty.
func _their_end_step() -> void:
	_their_main()
	var guard := 0
	while not (g.current_step() == Mtg.Step.END and g.priority_player == 0) and guard < 60:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.END)


func test_the_spike_hands_a_counter_to_the_flier_their_wall_cannot_block() -> void:
	var ai := _ai()
	var worker := _spike("Spike Worker", 2)
	var angel := put_battlefield(0, "Serra Angel")
	_lands("Plains", 4)
	put_battlefield(1, "Wall of Stone")
	_their_end_step()
	assert_string_contains(ai.act(g), "a counter onto Serra Angel")
	resolve_stack()
	assert_eq(int(angel.counters.get("+1/+1", 0)), 1)
	assert_eq(int(worker.counters.get("+1/+1", 0)), 1)
	assert_false(ai.act(g).contains("Spike Worker"), "the Spike keeps its last counter")


func test_no_shift_without_a_better_attacker() -> void:
	var ai := _ai()
	var worker := _spike("Spike Worker", 2)
	put_battlefield(0, "Grizzly Bears")
	_lands("Plains", 4)
	put_battlefield(1, "Wall of Stone")
	_their_end_step()
	assert_false(ai.act(g).contains("Spike Worker"))
	assert_eq(int(worker.counters.get("+1/+1", 0)), 2)


func test_the_null_arm_never_shifts() -> void:
	var ai := _ai(false)
	var worker := _spike("Spike Worker", 2)
	put_battlefield(0, "Serra Angel")
	_lands("Plains", 4)
	put_battlefield(1, "Wall of Stone")
	_their_end_step()
	assert_false(ai.act(g).contains("Spike Worker"))
	assert_eq(int(worker.counters.get("+1/+1", 0)), 2)


func test_the_shift_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_spike("Spike Worker", 2)
		put_battlefield(0, "Serra Angel")
		_lands("Plains", 4)
		put_battlefield(1, "Wall of Stone")
		give_hand(1, "Terror" if variant == 0 else "Giant Growth")
		g.players[1].library.reverse()
		_their_end_step()
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
