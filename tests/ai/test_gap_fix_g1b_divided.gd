extends GameTest
## Gap review 2026-11-10, r1b-2: the Pack 8/9 response readers read a
## DIVIDED spell's whole total as the damage each of its targets takes.
## Pyrotechnics' announced share (TargetRef.amount, CR 601.2d) and
## Fireball's even split (floor(X / N) over the N targets chosen) are what
## a target takes ([method EffectIntent.damage_on], [method
## EffectIntent.kills_on]); a Spike Feeder cashed out to 0/0 over one
## point, Cold Storage exiled a Serra Angel, a Mystic Veil was spent and
## Temper was sized at four for one.

const TT := preload("res://engine/ai/tempest_tactics.gd")
const MT := preload("res://engine/ai/mirage_tactics.gd")


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


## Seat 0 (the AI) answers; seat 1 only passes; until the stack is empty.
func _play_out_stack(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 60:
		guard += 1
		if g.priority_player == 0:
			var did := ai.act(g)
			if did != "pass" and did != "":
				lines.append(did)
		else:
			assert_ok(g.pass_priority(1))
	return lines


func _spike() -> CardInstance:
	var spike := put_battlefield(0, "Spike Feeder")
	if int(spike.counters.get("+1/+1", 0)) != 2:
		spike.counters["+1/+1"] = 2
	g.recalculate()
	return spike


## Their Pyrotechnics: [param share] at [param victim], the rest at [param rest].
func _pyro_at(victim: CardInstance, share: int, rest: TargetRef) -> void:
	_their_main()
	var pyro := give_hand(1, "Pyrotechnics")
	add_mana(1, Mtg.ManaColor.R, 5)
	rest.amount = 4 - share
	assert_ok(g.cast_spell(1, pyro, [TargetRef.card(victim, share), rest]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## Pyrotechnics: 1 to the 2/2 Spike Feeder, 3 to our face. The Spike lives
## through 1; it was read as doomed and cashed out to a 0/0.
func test_spike_feeder_is_not_cashed_out_by_one_point_of_pyrotechnics() -> void:
	var ai := _ai(true)
	var spike := _spike()
	assert_eq(spike.cur_toughness, 2)
	_pyro_at(spike, 1, TargetRef.player(0))
	var lines := _play_out_stack(ai)
	gut.p("ON  arm: AI did %s; spike zone=%d counters=%s" % [lines, spike.zone, str(spike.counters)])
	assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD,
		"a 2/2 Spike that takes 1 point lives — the AI cashed it out: %s" % [lines])


## The gate off (the null arm): nothing is spent, the Spike lives.
func test_null_arm_keeps_the_spike() -> void:
	var ai := _ai(false)
	var spike := _spike()
	_pyro_at(spike, 1, TargetRef.player(0))
	var lines := _play_out_stack(ai)
	assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD, str(lines))


## Fireball X=2 at two targets: 1 each (floor(2/2)). The 2/2 Spike lives.
func test_spike_feeder_is_not_cashed_out_by_half_a_fireball() -> void:
	var ai := _ai(true)
	var spike := _spike()
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(1, ball, [TargetRef.card(spike), TargetRef.player(0)], 2))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var lines := _play_out_stack(ai)
	gut.p("Fireball: AI did %s; spike zone=%d counters=%s" % [lines, spike.zone, str(spike.counters)])
	assert_eq(spike.zone, Mtg.Zone.BATTLEFIELD,
		"Fireball X=2 at two targets deals 1 to the Spike: %s" % [lines])


## Cold Storage: Pyrotechnics puts 1 on our Serra Angel (4/4). The Angel
## lives; storing it spends {3} and takes our best creature off the table.
func test_cold_storage_does_not_store_an_angel_from_one_point() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Cold Storage")
	for _i in 3: put_battlefield(0, "Plains")
	var angel := put_battlefield(0, "Serra Angel")
	_pyro_at(angel, 1, TargetRef.player(0))
	var lines := _play_out_stack(ai)
	gut.p("Cold Storage: AI did %s; angel zone=%d" % [lines, angel.zone])
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "a 4/4 taking 1 is not stored away: %s" % [lines])


## Temper ({X}{1}{W}) against Pyrotechnics' 1 point on a 1/1: the save is
## right, but X is the share, not the whole 4.
func test_temper_is_sized_at_the_share() -> void:
	var ai := _ai(true)
	for _i in 7: put_battlefield(0, "Plains")
	var lions := put_battlefield(0, "Savannah Lions")
	give_hand(0, "Temper")
	_pyro_at(lions, 1, TargetRef.player(0))
	var untapped_before := 0
	for p in g.players[0].battlefield:
		if p.is_land() and not p.tapped: untapped_before += 1
	var lines := _play_out_stack(ai)
	var untapped_after := 0
	for p in g.players[0].battlefield:
		if p.is_land() and not p.tapped: untapped_after += 1
	gut.p("Temper: AI did %s; lands tapped %d; lions zone=%d" % [lines,
		untapped_before - untapped_after, lions.zone])
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD, "the Lions are saved: %s" % [lines])
	assert_lte(untapped_before - untapped_after, 3,
		"Temper for 1 point costs {1}{1}{W}, not {4}{1}{W}: %s" % [lines])


## Mystic Veil (a flash-rider shroud aura, gone at cleanup) is not spent
## on an Angel that takes 1.
func test_mystic_veil_is_not_spent_on_one_point() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var angel := put_battlefield(0, "Serra Angel")
	var veil := give_hand(0, "Mystic Veil")
	_pyro_at(angel, 1, TargetRef.player(0))
	var did := ai.act(g)
	gut.p("Mystic Veil: AI did '%s'; veil zone=%d" % [did, veil.zone])
	assert_false(did.begins_with("cast Mystic Veil"), "the Angel takes 1 and lives")


## Reality Ripple (phase out) is not spent on an Angel that takes 1
## (mirage_tactics.gd `save_by_phasing`).
func test_reality_ripple_is_not_spent_on_one_point() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var angel := put_battlefield(0, "Serra Angel")
	give_hand(0, "Reality Ripple")
	_pyro_at(angel, 1, TargetRef.player(1))
	var did: String = MT.save_by_phasing(g, ai)
	gut.p("Reality Ripple: '%s'" % did)
	assert_eq(did, "", "the Angel takes 1 and lives")


## ...and is, for the 4 of it that kills.
func test_reality_ripple_saves_from_the_whole_four() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var angel := put_battlefield(0, "Serra Angel")
	give_hand(0, "Reality Ripple")
	_their_main()
	var pyro := give_hand(1, "Pyrotechnics")
	add_mana(1, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(1, pyro, [TargetRef.card(angel, 4)]))
	assert_ok(g.pass_priority(1))
	var did: String = MT.save_by_phasing(g, ai)
	gut.p("Reality Ripple at 4: '%s'" % did)
	assert_string_contains(did, "phases out")


## Shadowbane (a chosen-source shield, mirage_tactics.gd `shield_response`)
## is not spent on an Angel that takes 1 when the rest goes elsewhere.
func test_shadowbane_is_not_spent_on_one_point() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var angel := put_battlefield(0, "Serra Angel")
	give_hand(0, "Shadowbane")
	_pyro_at(angel, 1, TargetRef.player(1))
	var did: String = MT.shield_response(g, ai)
	gut.p("Shadowbane: '%s'" % did)
	assert_eq(did, "", "the Angel takes 1 and lives")


## The Pack 9 readers, one by one, against 1 of Pyrotechnics on a 4/4 —
## and their control: the 4/4 that takes all 4 is read as dying.
func test_the_tempest_readers_take_the_share() -> void:
	var ai := _ai(true)
	var licid := put_battlefield(0, "Calming Licid")
	var angel := put_battlefield(0, "Serra Angel")
	_pyro_at(angel, 1, TargetRef.player(0))
	assert_false(TT.licid_doomed(g, ai, licid, angel), "licid_doomed")
	assert_null(TT._dying_creature(g, ai, null, null), "_dying_creature")
	assert_eq(TT._incoming_to(g, ai, angel), 1, "_incoming_to")
	assert_false(TT._removal_aimed_at(g, ai, angel), "_removal_aimed_at")
	assert_eq(TT.spike_threat(g, ai, angel), "", "spike_threat")


func test_the_tempest_readers_see_a_lethal_share() -> void:
	var ai := _ai(true)
	var licid := put_battlefield(0, "Calming Licid")
	var angel := put_battlefield(0, "Serra Angel")
	_their_main()
	var pyro := give_hand(1, "Pyrotechnics")
	add_mana(1, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(1, pyro, [TargetRef.card(angel, 4)]))
	assert_ok(g.pass_priority(1))
	assert_true(TT.licid_doomed(g, ai, licid, angel), "licid_doomed")
	assert_eq(TT._dying_creature(g, ai, null, null), angel, "_dying_creature")
	assert_eq(TT._incoming_to(g, ai, angel), 4, "_incoming_to")
	assert_true(TT._removal_aimed_at(g, ai, angel), "_removal_aimed_at")
	assert_eq(TT.spike_threat(g, ai, angel), "stack", "spike_threat")


## Fireball X=7 at three targets: 2 each (floor(7/3)) — the Angel's
## incoming damage and our face's.
func test_fireball_shares_evenly_in_the_readers() -> void:
	var ai := _ai(true)
	var angel := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 10)
	assert_ok(g.cast_spell(1, ball, [TargetRef.card(angel), TargetRef.card(bears),
		TargetRef.player(0)], 7))
	assert_ok(g.pass_priority(1))
	var top: StackItem = g.stack.back()
	var intent := EffectIntent.read(top.effects, "Fireball")
	assert_eq(TT._incoming_to(g, ai, angel), 2, "_incoming_to")
	assert_eq(ai._damage_at_us(g, top, intent), 2, "_damage_at_us: the even split, not X - 2")


## OUR OWN divided spell on the stack (ai_player.gd `_answered_on_stack`):
## our Pyrotechnics' 1 point at their 4/4 is no answer to it already.
func test_our_own_share_is_no_answer_already() -> void:
	var ai := _ai(true)
	var giant := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	var pyro := give_hand(0, "Pyrotechnics")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, pyro, [TargetRef.card(giant, 1), TargetRef.player(1, 3)]))
	assert_false(ai._answered_on_stack(g, giant), "1 point does not kill a 4/4")
