extends GameTest
## The AI half of the 2026-10-03 bug pass: one regression per finding,
## each written against the shape a hunter's probe reproduced. Every pack
## is enabled, because half of the cards are Alliances / Ice Age /
## Homelands ones; every decision goes through [method AiPlayer.act] or
## the public MtgGame API unless the finding was in one predicate.


func before_each() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


func _pilot(seat: int, profile: AiProfile) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


## One engine step forward with nothing declared — no assertions, so a
## driver loop can call it where the GameTest helper would fail a test.
func _nudge() -> void:
	if g.awaiting_attackers:
		g.declare_attackers(g.active_player, [])
	elif g.awaiting_blockers:
		g.declare_blockers(g.opponent_of(g.active_player), {})
	else:
		g.pass_priority(g.priority_player)


## Let [param ai] act in its own first main phase until it passes;
## returns what it said.
func _main_phase(ai: AiPlayer) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var said: Array = []
	for _i in 6:
		var r := ai.act(g)
		said.append(r)
		if r == "pass" or r == "" or g.game_over:
			break
	return said


## Seat 0 attacks with [param attackers]; seat 1 is [param ai], which
## blocks and responds; everything else passes. Returns the AI's actions.
func _defend(ai: AiPlayer, attackers: Array, blocks := {}, ai_blocks := false) -> Array:
	var said: Array = []
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	var guard := 0
	while not g.game_over and guard < 300:
		guard += 1
		if g.current_step() >= Mtg.Step.COMBAT_END and g.stack.is_empty() \
				and not g.awaiting_blockers:
			break
		if g.awaiting_blockers and g.block_chooser() == 1:
			if ai_blocks:
				said.append(ai.act(g))
			else:
				assert_ok(g.declare_blockers(1, blocks))
			continue
		if g.priority_player == 1:
			var r := ai.act(g)
			if r != "pass" and r != "":
				said.append(r)
			if r == "":
				g.pass_priority(1)
			continue
		_nudge()
	return said


func _refusals() -> Array:
	var out: Array = []
	for line in g.log_lines:
		if str(line).contains("refused"):
			out.append(str(line))
	return out


# ---------------------------------------------- 0. the static cache race --

var _race_datas: Array = []
var _race_go := false
var _race_arrived := 0
var _race_lock := Mutex.new()


func _race_one(i: int) -> void:
	_race_lock.lock()
	_race_arrived += 1
	_race_lock.unlock()
	var spins := 0
	while not _race_go and spins < 50_000_000:
		spins += 1
	var data: CardData = _race_datas[i % _race_datas.size()]
	EffectIntent.stacks(data)
	EffectIntent.aura_gifts(data)
	EffectIntent.loses_the_game_on_leaving(data)


func test_effect_intent_caches_survive_a_cold_race_between_worker_threads() -> void:
	# THE BUG THIS PINS: every static cache in EffectIntent was filled
	# lazily with no lock, and the Deck Lab plays its games on a
	# WorkerThreadPool — eight duels starting together hit the same cold
	# caches on their first turns. An 8-thread probe aborted the process
	# ("double free or corruption") on 4 runs of 4. Unfixed, this test
	# does not fail: it takes the whole run down with a 134.
	for card_name in ["Giant Growth", "Lightning Bolt", "Holy Armor", "Firebreathing",
			"Llanowar Elves", "Serra Angel", "Shivan Dragon", "Dark Ritual"]:
		_race_datas.append(CardRegistry.get_card(card_name))
	var threads := clampi(OS.get_processor_count(), 2, 8)
	for _round in 150:
		EffectIntent._scaling = []
		EffectIntent._stacks_cache = {}
		EffectIntent._aura_gifts_cache = {}
		EffectIntent._reckoning_cache = {}
		_race_go = false
		_race_arrived = 0
		var task := WorkerThreadPool.add_group_task(_race_one, threads, threads, true)
		var waited := 0
		while waited < 2_000_000:
			_race_lock.lock()
			var arrived := _race_arrived
			_race_lock.unlock()
			if arrived >= threads:
				break
			waited += 1
		_race_go = true
		WorkerThreadPool.wait_for_group_task_completion(task)
		assert_eq(EffectIntent._scaling.size(), EffectIntent.SCALING_PHRASES.size())
		assert_eq(EffectIntent._stacks_cache.size(), mini(threads, _race_datas.size()))
		if is_failing():
			return
	# And the answers are still the answers.
	assert_true(EffectIntent.stacks(CardRegistry.get_card("Giant Growth")))
	assert_false(EffectIntent.stacks(CardRegistry.get_card("Serra Angel")))


# ------------------------------------------------- 1. the sum of the pain --

func test_two_cities_are_not_tapped_for_the_last_two_lives() -> void:
	# THE BUG: [method AiPlayer._pain_excluded] left out a City of Brass
	# only when ITS OWN point of pain met our life. At 2 life each City
	# hurts for 1, so both stayed in the plan, both were tapped for a
	# Grizzly Bears and the Wizard dealt itself the last two.
	g.players[0].life = 2
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "City of Brass")
	var bears := give_hand(0, "Grizzly Bears")
	var ai := _pilot(0, AiProfile.wizard())
	_main_phase(ai)
	resolve_stack()
	assert_false(g.game_over, "the AI killed itself with its own taps")
	assert_eq(g.players[0].life, 2)
	assert_eq(bears.zone, Mtg.Zone.HAND)


func test_the_shared_payer_refuses_a_plan_whose_pain_is_the_game() -> void:
	g.players[0].life = 2
	var cities := [put_battlefield(0, "City of Brass"), put_battlefield(0, "City of Brass")]
	var ai := _pilot(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai._plan_and_pay(g, ManaCost.parse("{2}")))
	for city in cities:
		assert_false(city.tapped, "nothing is tapped for a payment that is refused")
	g.players[0].life = 3
	assert_true(ai._plan_and_pay(g, ManaCost.parse("{2}")), "two of three lives is a price")


# ---------------------------------------- 2. the Fog that could not be cast --

func test_an_unaffordable_fog_does_not_hold_back_the_removal() -> void:
	# THE BUG: the defensive response returned the Fog's "" — an
	# unaffordable Fog — and never reached the Terror below it. Two
	# Swamps, a Fog and a Terror at 2 life against an unblocked Bears:
	# the AI died holding the answer.
	g.players[1].life = 2
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	give_hand(1, "Fog")
	var terror := give_hand(1, "Terror")
	var ai := _pilot(1, AiProfile.wizard())
	_defend(ai, [bears.id], {}, true)
	assert_false(g.game_over)
	assert_eq(g.players[1].life, 2)
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------ 3. a shrink is not a gift to our own --

func _targets_of_top() -> Array:
	var out: Array = []
	if g.stack.is_empty():
		return out
	for ref in g.stack.back().targets:
		if not ref.is_player:
			out.append(g.find_instance(ref.instance_id))
	return out


func _cast_and_targets(ai: AiPlayer) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 6:
		var r := ai.act(g)
		if r.begins_with("cast"):
			return _targets_of_top()
		if r == "pass" or r == "":
			break
	return []


func test_contagion_is_never_aimed_at_our_own_creature() -> void:
	# THE BUG: every pump read as help, and Contagion's -2/-1 counters are
	# a pump to the reader — so with nothing of theirs it could kill, the
	# AI put both counters on its own Craw Wurm (EffectIntent.is_harmful,
	# AiPlayer._is_harmful).
	for profile in [AiProfile.apprentice(), AiProfile.magician(), AiProfile.wizard()]:
		before_each()
		var wurm := put_battlefield(0, "Craw Wurm")
		put_battlefield(1, "Serra Angel")
		for _i in 5:
			put_battlefield(0, "Swamp")
		give_hand(0, "Contagion")
		var ai := _pilot(0, profile)
		for target in _cast_and_targets(ai):
			assert_ne(target.controller_id, 0,
				"%s aimed Contagion at its own %s" % [profile.profile_name, target.data.card_name])
		resolve_stack()
		assert_eq(wurm.cur_power, 6, profile.profile_name)
		assert_eq(wurm.cur_toughness, 4, profile.profile_name)


func test_contagion_still_kills_their_creature() -> void:
	var wurm := put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(1, "Grizzly Bears")
	for _i in 5:
		put_battlefield(0, "Swamp")
	give_hand(0, "Contagion")
	var ai := _pilot(0, AiProfile.apprentice())
	var targets := _cast_and_targets(ai)
	assert_eq(targets.size(), 1)
	if targets.size() == 1:
		assert_eq(targets[0], bears)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.cur_power, 6)


func test_shrink_is_never_aimed_at_our_own_creature() -> void:
	# The same bug through the other door: a PumpEffect(-5, 0) is a
	# PumpEffect, and _is_harmful called every one of them help.
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	give_hand(0, "Shrink")
	var ai := _pilot(0, AiProfile.apprentice())
	for target in _cast_and_targets(ai):
		assert_ne(target, wurm, "Shrink aimed at our own Craw Wurm")
	resolve_stack()
	assert_eq(wurm.cur_power, 6)


func test_the_harm_reading_of_a_shrink() -> void:
	var shrink := CardRegistry.get_card("Shrink")
	var contagion := CardRegistry.get_card("Contagion")
	var growth := CardRegistry.get_card("Giant Growth")
	assert_true(EffectIntent.read(shrink.spell_effects, "Shrink").is_harmful())
	assert_true(EffectIntent.read(contagion.spell_effects, "Contagion").is_harmful())
	assert_false(EffectIntent.read(growth.spell_effects, "Giant Growth").is_harmful())
	var ai := _pilot(0, AiProfile.wizard())
	var mine := put_battlefield(0, "Grizzly Bears")
	var src := give_hand(0, "Shrink")
	assert_true(ai._is_harmful(src, shrink.spell_effects[0]))
	src = give_hand(0, "Giant Growth")
	assert_false(ai._is_harmful(src, growth.spell_effects[0]))
	assert_not_null(mine)


# ------------------------------------------- 4. the pump that is a poison --

func _block_and_pump(profile: AiProfile, body_name: String, attacker_name: String,
		land: String, lands: int) -> CardInstance:
	before_each()
	var body := put_battlefield(1, body_name)
	for _i in lands:
		put_battlefield(1, land)
	var attacker := put_battlefield(0, attacker_name)
	var ai := _pilot(1, profile)
	_defend(ai, [attacker.id], {body.id: attacker.id})
	return body


func test_a_blocker_never_pumps_its_toughness_away() -> void:
	# THE BUG: _self_pump_once priced only the POWER of a +X/-Y breath.
	# Yavimaya Ancients (+1/-2) blocking a Deep Spawn it already survived
	# bought four breaths for the kill and died at 6/-1; a Phantasmal
	# Fiend (+1/-1) that survived an Ironroot Treefolk pumped into the
	# trade.
	for profile in [AiProfile.magician(), AiProfile.wizard()]:
		var ancients := _block_and_pump(profile, "Yavimaya Ancients", "Deep Spawn", "Forest", 4)
		assert_eq(ancients.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)
		var fiend := _block_and_pump(profile, "Phantasmal Fiend", "Ironroot Treefolk", "Swamp", 4)
		assert_eq(fiend.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)


func test_an_unblocked_firebreather_stops_before_its_toughness_runs_out() -> void:
	# THE BUG: the unblocked firebreathing loop read the power and nothing
	# else, so a Wizard's Phantasmal Fiend with five Swamps breathed to 6/0
	# and died before damage — 0 dealt instead of 5.
	for setup in [["Phantasmal Fiend", "Swamp", 5], ["Yavimaya Ancients", "Forest", 5]]:
		before_each()
		var body := put_battlefield(0, setup[0])
		for _i in int(setup[2]):
			put_battlefield(0, setup[1])
		var ai := _pilot(0, AiProfile.wizard())
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [body.id]))
		var guard := 0
		while not g.game_over and guard < 200 and g.current_step() <= Mtg.Step.COMBAT_DAMAGE:
			guard += 1
			if g.awaiting_blockers:
				g.declare_blockers(1, {})
				continue
			if g.priority_player == 0:
				if ai.act(g) == "":
					g.pass_priority(0)
			else:
				_nudge()
		assert_eq(body.zone, Mtg.Zone.BATTLEFIELD, "%s breathed itself to death" % setup[0])
		assert_lt(g.players[1].life, 20 - 2, "%s still breathed" % setup[0])


# -------------------------------------- 5. a face-down card has no name --

func test_a_face_down_permanent_does_not_bury_our_legend_in_the_planner() -> void:
	# RULE 8, and CR 708.2: a face-down permanent has no name and no
	# supertypes, and its hidden identity is not the AI's to read.
	# _arrival_wasted compared our Ramirez DePietro with the opponent's
	# face-down card's PRINTED name, so the Wizard held its legend whenever
	# the hidden card happened to be one — the decision moved with a card
	# nobody had revealed.
	var answers: Array = []
	for hidden_name in ["Ramirez DePietro", "Grizzly Bears"]:
		before_each()
		for _i in 4:
			put_battlefield(0, "Island")
		for _i in 2:
			put_battlefield(0, "Swamp")
		var mine := give_hand(0, "Ramirez DePietro")
		var masked := give_hand(1, hidden_name)
		g.put_from_hand_face_down(masked, 1)
		assert_true(masked.face_down)
		var ai := _pilot(0, AiProfile.wizard())
		advance_to_step(Mtg.Step.MAIN1)
		answers.append([ai._arrival_wasted(g, mine.data), ai.act(g)])
	assert_eq(answers[0], answers[1], "the hidden identity changed the decision")
	assert_false(bool(answers[0][0]))
	assert_string_contains(String(answers[0][1]), "Ramirez DePietro")


func test_a_face_up_legend_still_holds_ours_back() -> void:
	# The public-change control: the same legend face UP is public, and
	# the second copy is a card thrown away.
	for _i in 4:
		put_battlefield(0, "Island")
	for _i in 2:
		put_battlefield(0, "Swamp")
	var mine := give_hand(0, "Ramirez DePietro")
	put_battlefield(1, "Ramirez DePietro")
	var ai := _pilot(0, AiProfile.wizard())
	assert_true(ai._arrival_wasted(g, mine.data))


# ------------------------------------------- 6. the land tax on attacking --

## Seat 0 (the AI) with [param lands] Forests and [param bears] Grizzly
## Bears at its declaration, against a Flooded Woodlands ("green creatures
## can't attack unless their controller sacrifices a land").
func _taxed_attack(lands: int, bears: int, their_life := 20) -> Dictionary:
	before_each()
	g.players[1].life = their_life
	put_battlefield(1, "Flooded Woodlands")
	for _i in lands:
		put_battlefield(0, "Forest")
	for _i in bears:
		put_battlefield(0, "Grizzly Bears")
	var ai := _pilot(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var said := ai.act(g)
	var left := g.players[0].battlefield.filter(func(c: CardInstance) -> bool:
		return c.is_land()).size()
	return {"said": said, "attackers": g.combat.attackers.size(), "lands": left,
		"refused": _refusals()}


func test_a_land_taxed_attack_is_priced_and_never_refused() -> void:
	# THE BUG: the declaration never read cur_attack_land_sacrifices. With
	# fewer lands than Bears the engine refused the whole declaration
	# ("not enough lands to sacrifice") and nothing attacked; with enough,
	# every Bears went and took a land each, for free as far as the
	# planner knew.
	var short := _taxed_attack(2, 3)
	assert_eq(short["refused"], [], "a declaration the lands cannot pay for")
	assert_eq(short["lands"], 2, "two damage at twenty is not worth a Forest at two lands")
	var lethal := _taxed_attack(2, 3, 4)
	assert_eq(lethal["refused"], [])
	assert_eq(lethal["attackers"], 2, "the push is cut to what two Forests pay for")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.game_over, "and two Bears are still lethal at 4")
	var rich := _taxed_attack(7, 2)
	assert_eq(rich["refused"], [])
	assert_eq(rich["attackers"], 2)
	assert_eq(rich["lands"], 5)


# ------------------------------------------- 7. Force of Will's own bar --

## Seat 0 casts [param spell] off six Forests; seat 1 (the AI, five
## Islands, [param counter] and a blue creature that answers nothing in
## hand — so the shape reading has no "answered later" to fall back on
## and the bar is what decides) answers once.
func _counter_or_not(profile: AiProfile, counter: String, spell: String) -> CardInstance:
	before_each()
	for _i in 5:
		put_battlefield(1, "Island")
	var held := give_hand(1, counter)
	give_hand(1, "Merfolk of the Pearl Trident")
	for _i in 6:
		put_battlefield(0, "Forest")
	var cast := give_hand(0, spell)
	var ai := _pilot(1, profile)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ManaPlanner.plan_and_pay(g, 0, g.spell_cost_for(0, cast.data), 0))
	assert_ok(g.cast_spell(0, cast, [], 0))
	g.pass_priority(0)
	ai.act(g)
	return held


func test_force_of_will_asks_the_profiles_counter_bar() -> void:
	# THE BUG: the Alliances tactics' CounterEffect branch countered
	# anything worth more than a flat 2.0, so a Magician (bar 7.0)
	# Forced a Llanowar Elves and a Wizard (bar 5.0) a Grizzly Bears.
	var fow := _counter_or_not(AiProfile.magician(), "Force of Will", "Llanowar Elves")
	assert_eq(fow.zone, Mtg.Zone.HAND, "a Magician Forced a Llanowar Elves")
	fow = _counter_or_not(AiProfile.wizard(), "Force of Will", "Grizzly Bears")
	assert_eq(fow.zone, Mtg.Zone.HAND, "a Wizard Forced a Grizzly Bears")
	fow = _counter_or_not(AiProfile.wizard(), "Force of Will", "Craw Wurm")
	assert_ne(fow.zone, Mtg.Zone.HAND, "a threat over the bar is still countered")


func test_force_of_will_still_answers_the_burn_that_kills_us() -> void:
	# The other side of the bar: a Lightning Bolt prints far below a
	# Magician's 7.0, and at 3 life it is the game.
	g.players[1].life = 3
	for _i in 5:
		put_battlefield(1, "Island")
	var fow := give_hand(1, "Force of Will")
	give_hand(1, "Merfolk of the Pearl Trident")
	put_battlefield(0, "Mountain")
	var bolt := give_hand(0, "Lightning Bolt")
	var ai := _pilot(1, AiProfile.magician())
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ManaPlanner.plan_and_pay(g, 0, g.spell_cost_for(0, bolt.data), 0))
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	g.pass_priority(0)
	ai.act(g)
	assert_ne(fow.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(g.players[1].life, 3)


# ------------------------------------- 8. the target is not the payment --

func test_an_aura_is_not_paid_for_by_sacrificing_its_target() -> void:
	# THE BUG: the final plan of _try_cast_best drew on every source we
	# control, the spell's own target included — Firebreathing aimed at
	# a Tinder Wall was paid for by sacrificing the Tinder Wall, and the
	# engine refused the cast with the Wall already in the graveyard.
	for profile in [AiProfile.apprentice(), AiProfile.wizard()]:
		for setup in [["Firebreathing", 1], ["Veteran's Voice", 2]]:
			before_each()
			var wall := put_battlefield(1, "Tinder Wall")
			for _i in int(setup[1]):
				put_battlefield(1, "Forest")
			give_hand(1, setup[0])
			var ai := _pilot(1, profile)
			while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
					and g.turn_number < 5:
				_nudge()
			for _i in 6:
				var r := ai.act(g)
				if r == "pass" or r == "":
					break
			assert_eq(_refusals(), [], "%s / %s" % [profile.profile_name, setup[0]])
			assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "%s / %s" % [profile.profile_name, setup[0]])


# ------------------------------- 9. a {T} ability does not tap for itself --

## Caribou Range on the first of [param plains] Plains; the AI (seat 1)
## at seat 0's end step, the mana sink.
func _caribou(plains: int) -> Array:
	before_each()
	var lands: Array = []
	for _i in plains:
		lands.append(put_battlefield(1, "Plains"))
	var aura := _make_instance(1, "Caribou Range")
	g._put_on_battlefield(aura, 1, lands[0])
	g.recalculate()
	var ai := _pilot(1, AiProfile.wizard())
	advance_to_step(Mtg.Step.END)
	var guard := 0
	while g.current_step() == Mtg.Step.END and guard < 20:
		guard += 1
		if g.priority_player == 1:
			if ai.act(g) == "":
				g.pass_priority(1)
		else:
			g.pass_priority(0)
	var tokens := g.players[1].battlefield.filter(func(c: CardInstance) -> bool:
		return c.is_token).size()
	return [tokens, _refusals()]


func test_a_tap_ability_is_never_paid_for_with_its_own_source() -> void:
	# THE BUG: _try_activate's payment plan could tap the very permanent
	# whose {T} ability it was paying for (Caribou Range's Plains,
	# Kjeldoran Outpost): the activation was refused "already tapped",
	# with the mana left floating (and burning, under the 1997 rule).
	var two := _caribou(2)
	assert_eq(two[1], [], "with one other Plains the {W}{W} cannot be paid")
	assert_eq(two[0], 0)
	var three := _caribou(3)
	assert_eq(three[1], [])
	assert_eq(three[0], 1, "two other Plains pay for it, and the enchanted one taps")


## Kjeldoran Outpost behind [param plains] Plains (its own replacement
## sacrifices one as it enters); the AI (seat 1) at seat 0's end step.
func _outpost(plains: int) -> Array:
	before_each()
	for _i in plains:
		put_battlefield(1, "Plains")
	var outpost := put_battlefield(1, "Kjeldoran Outpost")
	var ai := _pilot(1, AiProfile.wizard())
	advance_to_step(Mtg.Step.END)
	var guard := 0
	while g.current_step() == Mtg.Step.END and guard < 20:
		guard += 1
		if g.priority_player == 1:
			if ai.act(g) == "":
				g.pass_priority(1)
		else:
			g.pass_priority(0)
	return [g.players[1].battlefield.filter(func(c: CardInstance) -> bool:
		return c.is_token).size(), _refusals(), outpost.tapped]


func test_kjeldoran_outpost_is_paid_for_by_the_plains() -> void:
	var one := _outpost(2)
	assert_eq(one[1], [], "one Plains cannot pay {1}{W} without the Outpost's own tap")
	assert_eq(one[0], 0)
	var two := _outpost(3)
	assert_eq(two[1], [])
	assert_eq(two[0], 1, "two Plains pay, the Outpost taps")


# --------------------------------- 10. a dual land is one source, not two --

func test_pump_shares_count_a_dual_land_once() -> void:
	# THE BUG: _sources_after dropped the plan's spent sources by
	# "id:ability index", so the Bayou's {G} row went and its {B} row
	# stayed: two Bayous were four breaths between two Carrion Ants.
	var a := put_battlefield(0, "Carrion Ants")
	var b := put_battlefield(0, "Carrion Ants")
	put_battlefield(0, "Bayou")
	put_battlefield(0, "Bayou")
	var ai := _pilot(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.MAIN1)
	var bodies: Array[CardInstance] = [a, b]
	var shares := ai._pump_shares(g, bodies)
	var total := 0
	for id in shares:
		total += int(shares[id]["count"])
	assert_eq(total, 2, "two lands, two breaths")


# ------------------------------------ 11. a flier is not banded into a wall --

func test_an_evasive_rider_is_not_banded_where_it_could_be_blocked() -> void:
	# THE BUG: the band rider was the most valuable non-bander, whatever
	# could block it. A Serra Angel nothing over there could block rode
	# with two Benalish Heroes, the Wall of Wood blocked a Hero and the
	# whole band — Angel included — was blocked.
	var h1 := put_battlefield(0, "Benalish Hero")
	put_battlefield(0, "Benalish Hero")
	var angel := put_battlefield(0, "Serra Angel")
	var wall := put_battlefield(1, "Wall of Wood")
	var ai := _pilot(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.has(angel.id))
	assert_eq(g.combat.band_of(angel.id).size(), 1, "the Angel rides alone")
	if g.combat.attackers.has(h1.id):
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {wall.id: h1.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_lte(g.players[1].life, 16, "the Angel's four got through")


# ------------------------------- 12. the damage order reads protection --

func test_the_damage_order_puts_a_protected_blocker_last() -> void:
	# THE BUG: order_blockers priced a pro-black White Knight at its full
	# worth in front of a Bog Wraith, so the Wraith's three went into a
	# body that took none of it and the Grizzly Bears behind it lived.
	var wraith := put_battlefield(0, "Bog Wraith")
	var knight := put_battlefield(1, "White Knight")
	var bears := put_battlefield(1, "Grizzly Bears")
	_pilot(0, AiProfile.wizard())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wraith.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {knight.id: wraith.id, bears.id: wraith.id}))
	var order: Array = g.combat.damage_order.get(wraith.id, [])
	assert_eq(order.front() if not order.is_empty() else -1, bears.id)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------- 13. the lethal push counts a matching --

func test_damage_through_blocks_is_the_defenders_best_matching() -> void:
	# THE BUG: the greedy gave the Craw Wurm the first blocker that could
	# take it (the Birds), left the Serra Angel unblockable and counted 4
	# through — a lethal push at 4 life — while Birds on the Angel, Wall
	# on the Wurm and Bears on the Elves stop all of it.
	g.players[1].life = 4
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Serra Angel")
	var elves := put_battlefield(0, "Llanowar Elves")
	var blockers: Array[CardInstance] = [put_battlefield(1, "Birds of Paradise"),
		put_battlefield(1, "Wall of Stone"), put_battlefield(1, "Grizzly Bears")]
	var ai := _pilot(0, AiProfile.magician())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var candidates := ai._attack_candidates(g, 1)
	assert_eq(ai._damage_through_blocks(g, candidates, blockers, 1), 0)
	ai.act(g)
	assert_false(g.combat.attackers.has(elves.id), "no lethal push, so the Elves stay home")


# --------------------------------------- 14. the band's damage, divided --

func test_a_banded_block_divides_the_damage_so_nothing_dies() -> void:
	# CR 702.22j: a band of blockers lets the DEFENDER divide the
	# attacker's damage. The AI had no answer of its own and the engine's
	# default put all three of a Hill Giant's points on the Shield Bearer
	# (0/3) — dead — when two and one kill nobody.
	var giant := put_battlefield(0, "Hill Giant")
	var bearer := put_battlefield(1, "Shield Bearer")
	var bears := put_battlefield(1, "Grizzly Bears")
	_pilot(1, AiProfile.wizard())
	assert_true(bearer.has_keyword(Mtg.Keyword.BANDING))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bearer.id: giant.id, bears.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bearer.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_a_banded_block_that_must_lose_a_body_loses_the_cheapest() -> void:
	var wurm := put_battlefield(0, "Craw Wurm")
	var bearer := put_battlefield(1, "Shield Bearer")
	var bears := put_battlefield(1, "Grizzly Bears")
	var ai := _pilot(1, AiProfile.wizard())
	var targets := [bearer.id, bears.id]
	var split: Dictionary = ai.assign_combat_damage(g, wurm, targets, 6, false, {}, true)
	var total := 0
	for id in split:
		total += int(split[id])
	assert_eq(total, 6)
	var dead := 0
	for id in split:
		var body := g.find_instance(int(id))
		if int(split[id]) >= body.cur_toughness:
			dead += 1
	assert_eq(dead, 1, "one death soaks the rest")


# ------------------------------------ 15. their open mana has colours --

func test_their_regeneration_needs_the_right_colour() -> void:
	# THE BUG: _shieldable counted their untapped mana sources colour-
	# blind, so a Drudge Skeletons behind a lone Forest was read as
	# regenerating ({B}) and a Hill Giant would never kill it.
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	var forest := put_battlefield(1, "Forest")
	var giant := put_battlefield(0, "Hill Giant")
	var ai := _pilot(0, AiProfile.wizard())
	assert_false(ai._shieldable(g, skeletons))
	assert_true(ai._dies_to(g, skeletons, giant))
	assert_not_null(forest)
	put_battlefield(1, "Swamp")
	assert_true(ai._shieldable(g, skeletons), "the colour it needs is open")


# --------------------------- 16. first strike that protection blanks --

func test_a_first_striker_whose_damage_is_prevented_does_not_save_itself() -> void:
	# THE BUG: _damage_from's first-strike clause read the victim's raw
	# power: Tundra Wolves (white, first strike) "kill" an Order of the
	# Ebon Hand (protection from white) before it strikes, so the Ebon
	# Hand's two were read as zero and the Wolves as surviving.
	var wolves := put_battlefield(1, "Tundra Wolves")
	var ebon := put_battlefield(0, "Order of the Ebon Hand")
	var ai := _pilot(1, AiProfile.wizard())
	assert_eq(ai._damage_from(ebon, wolves), 2)
	assert_true(ai._dies_to(g, wolves, ebon))
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_eq(ai._damage_from(bears, wolves), 2, "Bears are not killed by one first-strike point")
	var hero := put_battlefield(0, "Benalish Hero")
	assert_eq(ai._damage_from(hero, wolves), 0, "a 1/1 Hero is")


# --------------- 17. a regenerated creature is removed from combat --

func test_the_combat_model_removes_a_regenerated_attacker_from_combat() -> void:
	# CR 701.15a: a creature that regenerates is removed from combat. The
	# model's "immune" flag was indestructible OR a payable shield, and a
	# Drudge Skeletons struck down by first strike was still dealing its
	# damage afterwards — killing the Tundra Wolves that had blocked it.
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	put_battlefield(0, "Swamp")
	var wolves := put_battlefield(1, "Tundra Wolves")
	var ai := _pilot(0, AiProfile.wizard())
	var mine: Array[CardInstance] = [skeletons]
	var theirs: Array[CardInstance] = [wolves]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	var outcome: Array = model.resolve_block(0, [0], true)
	assert_false(bool(outcome[0]), "the Skeletons regenerate")
	assert_eq(int(outcome[1]), 0, "and deal nothing once they have")
	assert_eq(bool(outcome[0]), ai._dies_to(g, skeletons, wolves))
	assert_eq(int(outcome[1]) != 0, ai._dies_to(g, wolves, skeletons),
		"a gang of one agrees with _dies_to")


# ------------------------------------------ 18. the mistake roll's guard --

func test_a_wizard_declares_without_touching_the_random_stream() -> void:
	# A profile with no mistakes to make rolled for one anyway at every
	# attack and block declaration — the other mistake sites were guarded.
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var ai := _pilot(0, AiProfile.wizard())
	var them := _pilot(1, AiProfile.wizard())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var before := g.rng.state
	ai.act(g)
	assert_eq(g.rng.state, before, "attack declaration")
	if g.combat.attackers.has(bears.id):
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		before = g.rng.state
		them.act(g)
		assert_eq(g.rng.state, before, "block declaration")


func test_prepare_forgets_the_last_games_plan_and_refusals() -> void:
	var ai := _pilot(0, AiProfile.wizard())
	ai._pump_plan = {12345: 3}
	ai._pump_plan_turn = 1
	ai._refused = {"12345": true}
	ai.prepare(g, 0)
	assert_true(ai._pump_plan.is_empty())
	assert_true(ai._refused.is_empty())
