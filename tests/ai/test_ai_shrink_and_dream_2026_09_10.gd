extends GameTest
## TWO ARMS THE BURN SAVE DOES NOT ANSWER — BOTH RULED, NOT BUILT
## (2026-09-10; both were named in `docs/ai-difficulty.md` §5 and at their
## own sites, [method AiPlayer._pump_out_of_reach] and
## [method AiPlayer._counter_cost_spendable]).
##
## ONE — THE `-2/-2` SHAPE. [method AiPlayer._pump_out_of_reach] answers
## DAMAGE, reading [method EffectIntent.damage_at], so the note at the site
## said a removal spell that kills by SHRINKING has no damage to read and
## no answer. The census below is the whole of what this pool actually
## ships, and it says the shape is not in it:
##
##  * every shrink that can be aimed at a creature of OURS takes POWER
##    only — Ghosts of the Damned and Hell Swarm at -1/-0, Pradesh Gypsies,
##    Staff of Zegon and Marsh Gas at -2/-0, Bone Flute at -1/-0 — and no
##    amount of it kills anything;
##  * the only two effects in the pool with a negative TOUGHNESS term are
##    `self_buff()`s on their own card (Urza's Avenger's `{0}: -1/-1`,
##    Wall of Wonder's `+4/-4`), which nobody aims at us;
##  * the one until-end-of-turn toughness shrink that could kill one of
##    ours — Holy Light, *"nonwhite creatures get -1/-1"* — TARGETS
##    NOTHING. [method AiPlayer._save_from_the_stack] walks `top.targets`,
##    and there are none, so the arm is never reached; answering it is a
##    mass-shrink reader's job, and [EffectIntent] reads the card-local
##    effect as `unknown` besides. It is in no shipped deck.
##  * everything else that takes toughness off one of ours is PERMANENT —
##    the Immolation and Weakness auras (which ARE in the 1997 decks), the
##    Spirit Shackle, Takklemaggot and Unstable Mutation counters. A breath
##    lasts until end of turn (CR 514.2), so it does not save the victim,
##    it postpones the state-based action by one cleanup, and the mana is
##    gone. Pinned below with the Shade that lives the turn as a 6/3 and is
##    in the graveyard at the cleanup anyway.
##
## So the arm answers nothing because there is nothing in this pool for it
## to answer, and [method AiPlayer._find_pump_instant] is silent for the
## same reason — the two readers stay in step. Widening either one is a
## READER's question (an intent that reports the toughness a spell TAKES)
## and it is blocked on a card this pool does not have.
##
## TWO — RASPUTIN'S DREAM COUNTERS. The ruling of the counter-cost pass
## said a counter with TWO uses is spent on whichever comes first, unpriced
## — the shield and the colourless mana are within a mana of each other, so
## nothing is measurably wrong. The measurement below says something
## stronger and simpler: the pilot spends the dream counter on NEITHER, so
## there is no preference to decide.
##
##  * THE MANA is refused by the mana planner itself
##    ([code]ManaPlanner.sources[/code]): a mana ability with a rider the
##    plan's arithmetic cannot model — mana, life, a sacrifice, counters —
##    is left out, and Rasputin's *"Remove a dream counter: Add {C}"* is
##    the comment's own example. Rasputin is not a source to this AI.
##  * THE SHIELD is admitted by [method AiPlayer._ability_available] and
##    then priced at nothing by [method AiPlayer._ability_option], because
##    `DreamShieldEffect` is card-local and [EffectIntent] reads it as
##    `unknown` — the same scorer gap §5 already names for Necropolis of
##    Azar's token. It is not reachable in the 1997 damage-prevention
##    window either: [method AiPlayer._effects_answer] wants
##    `is_damage_prevention` and one of two known effect classes, and the
##    card's own effect declares neither.
##
## Both fences are outside [member AiProfile.spends_counters] — one is the
## mana planner's, one is the general scorer's and the card's own script —
## so the knob has nothing to prefer between and no price to carry. What
## WOULD have to be read the day both uses are reachable is written at the
## end of this file.
##
## Nothing here changes behaviour. Every test is run on BOTH arms of the
## knob it belongs to, and both arms agree — which is the ruling.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _pumps(profile_on: bool) -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = profile_on
	return profile


func _counters(profile_on: bool) -> AiProfile:
	var profile := AiProfile.wizard()
	profile.spends_counters = profile_on
	return profile


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


func _resolve_top() -> void:
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ================================== one: the shrink shape, card by card --

## The summed P/T delta of every [PumpEffect]/[MassPumpEffect] in a list.
func _delta(effects: Array) -> Vector2i:
	var out := Vector2i.ZERO
	for e in effects:
		if e is PumpEffect or e is MassPumpEffect:
			out += Vector2i(e.power, e.toughness)
	return out


func test_no_card_in_the_pool_shrinks_another_creatures_toughness() -> void:
	# THE CENSUS, and it is the whole ruling. Walk every printed effect the
	# registry holds: a negative TOUGHNESS term exists on exactly two
	# cards, and both are self-buffs. If a card is ever added that takes
	# toughness off a creature it targets, this test is the one that says
	# the ruling has to be re-argued.
	var shrinkers: Array[String] = []
	var self_only: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data: CardData = CardRegistry.get_card(card_name)
		if data == null:
			continue
		var lists: Array = [data.spell_effects]
		for ability in data.activated_abilities:
			lists.append(ability.effects)
		for effects in lists:
			if _delta(effects).y >= 0:
				continue
			var aimed_at_others := false
			for e in effects:
				if e is PumpEffect and e.toughness < 0 and not e.self_mode:
					aimed_at_others = true
				elif e is MassPumpEffect and e.toughness < 0:
					aimed_at_others = true
			if aimed_at_others:
				if not shrinkers.has(card_name):
					shrinkers.append(card_name)
			elif not self_only.has(card_name):
				self_only.append(card_name)
	self_only.sort()
	assert_eq(shrinkers, [] as Array[String],
		"nothing in the pool takes toughness off a creature it aims at")
	assert_eq(self_only, ["Urza's Avenger", "Wall of Wonder"] as Array[String],
		"the two negative-toughness effects are self-buffs on their own card")


func test_the_shrinks_that_do_aim_at_us_take_power_and_never_kill() -> void:
	# The six that CAN be pointed at one of ours, listed by what they take.
	# A toughness breath answers none of them, and neither does a Giant
	# Growth: nothing here can kill.
	var expected := {
		"Bone Flute": Vector2i(-1, 0),
		"Ghosts of the Damned": Vector2i(-1, 0),
		"Hell Swarm": Vector2i(-1, 0),
		"Marsh Gas": Vector2i(-2, 0),
		"Pradesh Gypsies": Vector2i(-2, 0),
		"Staff of Zegon": Vector2i(-2, 0),
	}
	for card_name in expected:
		var data: CardData = CardRegistry.get_card(String(card_name))
		assert_not_null(data, "%s is in the pool" % card_name)
		var worst := Vector2i.ZERO
		var lists: Array = [data.spell_effects]
		for ability in data.activated_abilities:
			lists.append(ability.effects)
		for effects in lists:
			var d := _delta(effects)
			if d.x < worst.x or d.y < worst.y:
				worst = d
		assert_eq(worst, Vector2i(expected[card_name]),
			"%s takes power only" % card_name)


func test_holy_light_kills_the_shade_and_the_arm_never_sees_it() -> void:
	# THE ONE UNTIL-END-OF-TURN TOUGHNESS SHRINK IN THE POOL, reproduced on
	# both arms: a Frozen Shade (0/1, `{B}`: +1/+1) behind four Swamps dies
	# to Holy Light with every Swamp untapped. Three breaths would have
	# carried it, and the responder never gets that far — the intent is not
	# a creature-answering shape and the spell has no targets to walk.
	for knob in [true, false]:
		before_each()
		var ai := _ai(_pumps(knob))
		var shade := put_battlefield(0, "Frozen Shade")
		for _i in 4:
			put_battlefield(0, "Swamp")
		var light := give_hand(1, "Holy Light")
		assert_ok(g.pass_priority(0))
		add_mana(1, Mtg.ManaColor.W, 1)
		add_mana(1, Mtg.ManaColor.C, 2)
		assert_ok(g.cast_spell(1, light, []))
		var item: StackItem = g.stack.back()
		var intent := EffectIntent.read(item.effects, "Holy Light")
		assert_false(intent.answers_creatures(),
			"a shrink is not a creature-answering shape to the reader")
		assert_eq(item.targets.size(), 0,
			"and the target loop the save walks has nothing in it")
		assert_eq(ai._save_from_the_stack(g), "",
			"so nothing is offered, on either arm")
		_resolve_top()
		assert_eq(shade.zone, Mtg.Zone.GRAVEYARD, "the Shade died")
		assert_eq(_untapped_lands(0), 4, "with four Swamps on the table")


func test_a_permanent_shrink_is_postponed_by_a_breath_and_never_answered() -> void:
	# THE OTHER HALF OF THE RULING, and the reason widening the arm would
	# not help even if the reader could see these: Immolation is an AURA.
	# Four breaths — every Swamp the Shade has — make it a 6/3 that lives
	# the turn, and the cleanup (CR 514.2) takes the pump away and the
	# Shade with it. A breath postpones; it does not save.
	var ai := _ai(_pumps(true))
	var shade := put_battlefield(0, "Frozen Shade")
	for _i in 4:
		put_battlefield(0, "Swamp")
	var aura := give_hand(1, "Immolation")
	# Their main phase, where a sorcery-speed aura may be cast at all.
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 300:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(shade)]))
	assert_eq(ai._save_from_the_stack(g), "",
		"an aura on the stack is no creature-answering shape either")
	# The breaths the pilot COULD buy, granted here so the rules point is
	# the only thing under test.
	for _i in 4:
		g.continuous.add_until_eot_pump(shade.id, 1, 1)
	g.recalculate()
	_resolve_top()
	assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD, "it lives the turn")
	assert_eq(Vector2i(shade.cur_power, shade.cur_toughness), Vector2i(6, 3),
		"a 6/3 under a +2/-2")
	var turn := g.turn_number
	guard = 0
	while g.turn_number == turn and not g.game_over and guard < 300:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(shade.zone, Mtg.Zone.GRAVEYARD,
		"and the cleanup takes it anyway — the breath bought one turn")


# ================================ two: Rasputin's two uses, neither made --

func test_rasputin_is_never_a_mana_source_to_the_pilot() -> void:
	# The planner's own rule, on both arms of the knob: a mana ability with
	# a rider the plan cannot model is not a source. Rasputin's dream
	# counter is the comment's example in `engine/mana_planner.gd`.
	for knob in [true, false]:
		before_each()
		var ai := _ai(_counters(knob))
		var ras := put_battlefield(0, "Rasputin Dreamweaver")
		assert_eq(int(ras.counters.get("dream", 0)), 7, "seven on arrival")
		assert_eq(ras.cur_mana_abilities.size(), 1, "and one mana ability")
		var mana: ManaAbility = ras.cur_mana_abilities[0]
		assert_eq(mana.counter_cost_kind, "dream", "priced in dream counters")
		for row in ai._mana_sources(g):
			assert_ne(row[0], ras, "which the planner leaves out")


func test_rasputin_is_never_shielded_by_the_pilot_either() -> void:
	# The scorer's gap. The ability is AVAILABLE — the counter-cost pass
	# opened that gate — and then priced at nothing, because the card-local
	# effect is `unknown` to the reader. Seven counters, four moments, no
	# offer.
	for knob in [true, false]:
		before_each()
		var ai := _ai(_counters(knob))
		var ras := put_battlefield(0, "Rasputin Dreamweaver")
		assert_eq(ai._ability_available(g, ras, 0), knob,
			"the gate is the counter knob's and nothing else")
		for moment in [AiPlayer.Moment.MAIN, AiPlayer.Moment.UPKEEP,
				AiPlayer.Moment.SINK, AiPlayer.Moment.COMBAT]:
			assert_eq(ai._ability_option(g, ras, 0, moment), {},
				"and the scorer wants it at no moment")


func test_the_dream_shield_is_not_in_the_1997_window_either() -> void:
	# The window's whitelist (`Duel.hlp` §6.8): the effect must declare
	# itself a prevention effect AND be one of the two shapes the answer
	# builder knows how to target. Rasputin's is neither, so even a seat
	# that wants the window cannot reach the counter's second use.
	var ai := _ai(_counters(true))
	var ras := put_battlefield(0, "Rasputin Dreamweaver")
	var gun := put_battlefield(1, "Grizzly Bears")
	var packet := plant_damage_packet(gun, TargetRef.card(ras), 2)
	var ability: ActivatedAbility = ras.cur_activated_abilities[0]
	assert_false(ability.effects[0].is_damage_prevention,
		"the card's own effect does not declare itself one")
	assert_false(ai._effects_answer(g, ability.effects, packet, ras),
		"so the window's answer builder refuses it")
	assert_eq(ai._spend_on_packet(g, packet, 10.0), "",
		"and nothing is spent on a packet aimed at Rasputin")


func test_rasputin_dies_in_combat_with_every_counter_still_on_him() -> void:
	# The table's own reading of both fences at once, on both arms: a 4/1
	# with seven dream counters blocks a Hill Giant and dies holding all
	# seven. Whichever use one would prefer, the pilot makes neither.
	for knob in [true, false]:
		before_each()
		var ai := _ai(_counters(knob))
		var foe := _ai(AiProfile.wizard(), 1)
		var ras := put_battlefield(0, "Rasputin Dreamweaver")
		var guard := 0
		while (not g.awaiting_attackers or g.active_player != 1) \
				and not g.game_over and guard < 200:
			if g.awaiting_attackers:
				assert_ok(g.declare_attackers(g.active_player, []))
			elif g.awaiting_blockers:
				assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
			else:
				assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		var giant := put_battlefield(1, "Hill Giant")
		assert_ok(g.declare_attackers(1, [giant.id]))
		guard = 0
		while not g.awaiting_blockers and not g.game_over and guard < 60:
			if g.priority_player == 0:
				ai.act(g)
			else:
				assert_ok(g.pass_priority(1))
			guard += 1
		assert_string_contains(ai.act(g), "block(s)", "he blocks")
		guard = 0
		while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
				and guard < 120:
			var mine := ai.act(g)
			var theirs := foe.act(g)
			if mine == "" and theirs == "":
				break
			guard += 1
		assert_eq(ras.zone, Mtg.Zone.GRAVEYARD, "and dies to the 3/3")
		assert_eq(ras.prevention, 0, "having shielded himself none of it")


# ------------------------------------------------------------------------
# WHAT WOULD HAVE TO BE READ, the day both uses are reachable — written
# here so the question does not have to be had again from scratch.
#
# The counter is FUEL and worth zero to every reader until it is spent
# ([method AiPlayer._counter_cost_spendable]), so the trade is entirely
# the EFFECT, and the two effects are priced on different scales: a
# colourless mana is worth whatever the cast it completes is worth, and a
# point of prevention is worth the creature when the point is the one that
# kills it and nothing at all when it is not. Both numbers already exist
# in this file — [method AiPlayer._packet_worth] prices the point ("only
# when it would actually KILL it"), and the mana's worth is the difference
# between the best cast the planner can make with it and the best without.
# What is missing is neither price but the ORDER: the counter is spent one
# at a time and the two uses come up in different windows (the mana at a
# main phase, the shield in the middle of damage), so the pilot would have
# to know at the earlier window how many counters the later one will want
# — which is the damage that is COMING, not the damage that has landed.
# That is the same forward reading `counts_the_race` is named for (§5,
# wave 4), and it is the reason this stays ruled and not built.
