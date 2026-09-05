extends GameTest
## THE X A SPELL IS BEING CAST FOR, AND THE MANA THE PLANNER USED TO LEAK
## (the 2026-09-05 pass that closes class 4 of the 2026-09-04 dead-card
## sweep — docs/ROADMAP.md, "The AI block audit and dead-card sweep").
##
## THE BUG. `AiPlayer` taps its lands and THEN calls `MtgGame.cast_spell`.
## Every legality the planner does not mirror is therefore paid for before
## it is discovered, and the floating mana is gone at the next step
## boundary (CR 500.4). Three cards did it on EVERY attempt:
##
##   * Fire and Brimstone — "target player who attacked this turn" is a
##     TargetSpec.player_filter, and the picker handed the opponent over
##     without asking it.
##   * Detonate — "target artifact with mana value X" is a targeting
##     restriction (CR 115.4) whose filter reads the caster's X. In hand
##     that X was 0, so the picker found the one artifact that cost
##     nothing, sized X to every land it had, and offered the engine a
##     target its own X had just made illegal.
##   * Orcish Catapult — its targets are ROLLED by the game (CR 601.2c,
##     TargetSpec.at_random), so the caster supplies none; the planner
##     supplied one anyway.
##
## THE SEAM. `MtgGame.casting_x` is now the one place that answers "what X
## is this card being cast for?", and it answers for a PROPOSED X as well
## as an announced one — so a filter that reads the X gives the same answer
## to a planner as it will to the engine. `MtgGame.cast_refusal` is
## `cast_spell`'s whole validation half run as a dry run: same code, no
## payment, no roll, no question. `AiPlayer` asks it before it taps.


func _mana(pid: int) -> void:
	for land in ["Forest", "Island", "Mountain", "Plains", "Swamp"]:
		for _i in 4:
			put_battlefield(pid, land)


## Lands this seat still has untapped. A cast the engine refuses AFTER the
## taps makes this number smaller and buys nothing with it — and the
## floating mana it became empties at the next step boundary (CR 500.4),
## so the turn is really, measurably poorer.
func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


func _act_all(ai: AiPlayer, rounds := 6) -> void:
	for _i in rounds:
		if ai.act(g) == "":
			return


# ------------------------------------------------- the leak, card by card --

func test_fire_and_brimstone_does_not_leak_the_mana_it_taps() -> void:
	# {3}{W}{W}, and the opponent has not attacked, so there is no legal
	# player to point it at. The AI used to tap five lands to find out.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var bomb := give_hand(0, "Fire and Brimstone")
	advance_to_step(Mtg.Step.MAIN1)
	var before := _untapped_lands(0)
	_act_all(ai)
	assert_eq(bomb.zone, Mtg.Zone.HAND, "no player who attacked this turn")
	assert_eq(_untapped_lands(0), before, "nothing was paid to find that out")


func test_detonate_does_not_leak_the_mana_it_taps() -> void:
	# The only artifact on the table costs {3}; a Detonate for anything
	# else may not legally name it (CR 115.4).
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	put_battlefield(1, "Black Lotus")       # mana value 0
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	var before := _untapped_lands(0)
	ai.act(g)
	# X = 0 names the Lotus and is a perfectly legal cast; what must never
	# happen is a cast the engine refuses after the lands are tapped.
	if detonate.zone == Mtg.Zone.HAND:
		assert_eq(_untapped_lands(0), before, "nothing was paid to find that out")
	else:
		assert_eq(g.stack.back().x_value, 0, "sized to the Lotus, not to the lands")


func test_orcish_catapult_does_not_leak_the_mana_it_taps() -> void:
	# "Randomly distribute X -0/-1 counters among a random number of
	# random target creatures": the GAME rolls the targets, so the caster
	# supplies none and the planner must not.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Savannah Lions")
	var catapult := give_hand(0, "Orcish Catapult")
	advance_to_step(Mtg.Step.MAIN1)
	var before := _untapped_lands(0)
	_act_all(ai)
	assert_eq(catapult.zone, Mtg.Zone.HAND, "a rolled spell is not aimed")
	assert_eq(_untapped_lands(0), before, "nothing was paid to find that out")


func test_the_leak_is_mana_the_turn_never_gets_back() -> void:
	# THE PLAYER-VISIBLE SYMPTOM, end to end: the planner taps, the engine
	# refuses, the floating mana empties at the step boundary (CR 500.4)
	# and the lands stay tapped for the rest of the turn. The seat spent
	# five lands and got nothing — with the card still in its hand.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	var bomb := give_hand(0, "Fire and Brimstone")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_untapped_lands(0), 20)
	for _i in 6:
		if ai.act(g) == "":
			break
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 0, "the pool emptied (CR 500.4)")
	assert_eq(bomb.zone, Mtg.Zone.HAND, "and the card is still in hand")
	# Two lands for the Bears the AI really did cast, and NOT a land more.
	assert_eq(_untapped_lands(0), 18, "only what the Bears cost")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_the_refusal_is_never_reached_from_the_planner() -> void:
	# The whole class in one reading: whatever the AI does with these
	# three, the engine never logs a refusal — because the planner asks
	# before it pays. This is the test that fails hardest on the old code.
	for card_name in ["Fire and Brimstone", "Detonate", "Orcish Catapult"]:
		before_each()
		var ai := AiPlayer.new(0, AiProfile.wizard())
		g.set_agent(0, ai)
		_mana(0)
		put_battlefield(1, "Black Lotus")
		put_battlefield(1, "Grizzly Bears")
		put_battlefield(0, "Savannah Lions")
		give_hand(0, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		_act_all(ai)
		for line in g.log_lines:
			assert_false(line.contains("refused"),
				"%s: the planner paid to learn the engine's answer (%s)"
					% [card_name, line])


# --------------------------------------------------- the seam it is built on --

func test_casting_x_answers_for_a_proposed_x() -> void:
	# The defect the seam names: the X used to reach a targeting filter
	# exactly one way, `cast_spell` stamping it on the way past.
	var detonate := give_hand(0, "Detonate")
	assert_eq(g.casting_x(detonate), 0, "nothing announced, nothing proposed")
	var lotus := put_battlefield(1, "Black Lotus")
	var ring := put_battlefield(1, "Sol Ring")
	var spec: TargetSpec = detonate.data.spell_effects[0].target_spec
	assert_true(g.target_legal_at(spec, TargetRef.card(lotus), detonate, 0),
		"a Detonate for 0 may name a {0} artifact")
	assert_false(g.target_legal_at(spec, TargetRef.card(lotus), detonate, 1),
		"...and a Detonate for 1 may not")
	assert_true(g.target_legal_at(spec, TargetRef.card(ring), detonate, 1),
		"a Detonate for 1 may name a {1} artifact")
	assert_eq(g.casting_x(detonate), 0, "the proposal left nothing behind")


func test_legal_targets_at_reads_the_proposed_x() -> void:
	var detonate := give_hand(0, "Detonate")
	put_battlefield(1, "Black Lotus")
	var ring := put_battlefield(1, "Sol Ring")
	var spec: TargetSpec = detonate.data.spell_effects[0].target_spec
	var at_one := g.legal_targets_at(spec, detonate, 1)
	assert_eq(at_one.size(), 1, "exactly the {1} artifact")
	assert_eq(at_one[0].instance_id, ring.id)


func test_cast_refusal_is_the_answer_cast_spell_would_give() -> void:
	# Same code, no payment: the dry run and the real cast agree.
	_mana(0)
	var lotus := put_battlefield(1, "Black Lotus")
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	var why := g.cast_refusal(0, detonate, [TargetRef.card(lotus)], 3)
	assert_string_contains(why, "Illegal target")
	add_mana(0, Mtg.ManaColor.R, 1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, detonate, [TargetRef.card(lotus)], 3), "Illegal target")
	assert_eq(g.players[0].mana_pool.total(), 4, "the refused cast spent nothing")
	assert_false(detonate.memory.has("x_value"),
		"a refused announcement leaves everything as it was (CR 601.2h)")


func test_cast_refusal_passes_a_cast_that_is_only_short_of_mana() -> void:
	# "" means "nothing but the mana is left to find" — the planner then
	# taps for it, and the engine agrees.
	var ring := put_battlefield(1, "Sol Ring")
	var detonate := give_hand(0, "Detonate")
	_mana(0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.cast_refusal(0, detonate, [TargetRef.card(ring)], 1), "")
	add_mana(0, Mtg.ManaColor.R, 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, detonate, [TargetRef.card(ring)], 1))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------ what the seam makes newly castable --

func test_detonate_is_sized_to_the_artifact_it_wants() -> void:
	# The card the sweep found dead: it now picks the artifact worth
	# killing and pays exactly that artifact's mana value.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	_mana(0)
	put_battlefield(1, "Black Lotus")
	var jar := put_battlefield(1, "Howling Mine")
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	var acted := ""
	for _i in 4:                       # the land drop comes first
		acted = ai.act(g)
		if acted.contains("Detonate"):
			break
	assert_string_contains(acted, "Detonate")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 2, "Howling Mine's mana value")
	assert_eq(item.targets[0].instance_id, jar.id)
	resolve_stack()
	assert_eq(jar.zone, Mtg.Zone.GRAVEYARD)


func test_spell_blast_is_sized_to_the_spell_it_answers() -> void:
	# {X}{U}, "counter target spell with mana value X". It was recognised
	# as a counterspell by the 2026-09-04 pass and then correctly declined
	# to fire, because nothing could try an X on without stamping it.
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	give_hand(1, "Spell Blast")
	for _i in 7:
		put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "Spell Blast")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 6, "the Dragon's mana value, not the mana we had")
	resolve_stack()
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD, "the dragon never landed")


func test_spell_blast_is_not_fired_when_no_x_can_reach_the_spell() -> void:
	# Two Islands cannot make a Blast for 6; the card waits instead of
	# being thrown at a spell it may not legally name.
	var ai := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(1, ai)
	var blast := give_hand(1, "Spell Blast")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "no affordable X names that spell")
	assert_eq(blast.zone, Mtg.Zone.HAND)
	assert_eq(_untapped_lands(1), 2, "and nothing was paid to find out")
	assert_eq(g.players[1].mana_pool.total(), 0, "nothing floating either")


# ----------------------------------------------- the ladder is untouched --

func test_the_apprentice_still_never_counters() -> void:
	# Spell Blast reaches the table through `_try_counter`, which lives
	# behind `AiProfile.holds_instants` — false for the Apprentice, which
	# plays sorcery-speed Magic and must keep doing so.
	var ai := AiPlayer.new(1, AiProfile.apprentice())
	g.set_agent(1, ai)
	var blast := give_hand(1, "Spell Blast")
	for _i in 7:
		put_battlefield(1, "Island")
	var shivan := give_hand(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, shivan, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "the Apprentice holds nothing")
	assert_eq(blast.zone, Mtg.Zone.HAND)


# ------------------------------------------------- the +X/+0 finisher --

func test_howl_from_beyond_finishes_the_game() -> void:
	# {X}{B}, +X/+0: 12 deck files, never fired in a logged game. It is
	# offered only for the KILL — a pump with no toughness buys no block
	# and no board — and X is the shortfall exactly.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	g.set_agent(1, DecisionAgent.new())
	for _i in 6:
		put_battlefield(0, "Swamp")
	var ogre := put_battlefield(0, "Gray Ogre")          # 2/2
	var howl := give_hand(0, "Howl from Beyond")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogre.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var acted := ""
	for _i in 4:
		acted = ai.act(g)
		if acted.contains("Howl"):
			break
	assert_string_contains(acted, "Howl")
	assert_eq(g.stack.back().x_value, 3, "the shortfall, not the mana we had")
	resolve_stack()
	assert_eq(ogre.cur_power, 5)
	assert_eq(howl.zone, Mtg.Zone.GRAVEYARD)


func test_howl_from_beyond_is_not_spent_on_a_swing_that_is_not_lethal() -> void:
	# The other half of the policy, and the reason it is gated so tightly:
	# +X/+0 that does not end the game is a card for nothing.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	g.set_agent(1, DecisionAgent.new())
	for _i in 6:
		put_battlefield(0, "Swamp")
	var ogre := put_battlefield(0, "Gray Ogre")
	var howl := give_hand(0, "Howl from Beyond")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)   # they are on 20
	assert_ok(g.declare_attackers(0, [ogre.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	for _i in 4:
		if ai.act(g) == "":
			break
	assert_eq(howl.zone, Mtg.Zone.HAND, "held: the swing was not lethal")
