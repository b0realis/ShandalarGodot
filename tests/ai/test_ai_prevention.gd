extends GameTest
## THE AI IN THE 1997 DAMAGE WINDOWS — `docs/duel-todo.md` §6.8, the half
## `docs/ROADMAP.md` carried as *"The AI declines every damage-prevention
## window"*.
##
## Until this landed the fork was a one-sided buff: `RulesOptions
## .damage_prevention_window` gave the human a whole tactical layer and the
## opponent answered every window with "no". These tests pin the four
## decisions the AI now makes — whether to use the window at all, which
## packet to answer, which effect to spend, and when to regenerate — and
## pin them to [AiProfile], which is the only place difficulty is allowed
## to live.


## Arm BOTH gates: the rules fork, and an AI seat that asks for the window.
func _arm(seat: int, profile: AiProfile = null) -> AiPlayer:
	g.rules.damage_prevention_window = true
	var ai := AiPlayer.new(seat, profile if profile != null else AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Run one combat with [param ai] DRIVING its own seat, and report what it
## said inside the windows. [method GameTest.run_combat] cannot serve: it
## passes priority for both seats, so it walks straight through an open
## window and the AI never gets a turn in it.
func _combat_with_ai(ai: AiPlayer, attackers: Array,
		blocks: Dictionary = {}) -> PackedStringArray:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	return _play_the_window(ai)


## Let [param ai] act until the windows are shut, and report what it did.
func _play_the_window(ai: AiPlayer) -> PackedStringArray:
	var said := PackedStringArray()
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration) and guard < 12:
		guard += 1
		if g.priority_player != ai.pid:
			assert_ok(g.pass_priority(g.priority_player))
			continue
		var did := ai.act(g)
		if did != "":
			said.append(did)
	assert_lt(guard, 12, "the window did not close")
	return said


# ------------------------------------------------------- who opens one --

func test_the_apprentice_never_uses_the_window() -> void:
	# Phase-1, my-turn-only Magic is that profile's whole feel — the same
	# `holds_instants` that keeps it off counterspells keeps it out of a
	# priority round in the middle of damage. It is a weakness, not a
	# different set of rules: the damage still lands, through the modern
	# automatic prevention order.
	var ai := AiPlayer.new(1, AiProfile.apprentice())
	assert_false(ai.wants_damage_prevention_window())
	g.rules.damage_prevention_window = true
	g.set_agent(1, ai)
	g.players[1].life = 4
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	run_combat([giant.id])
	assert_false(g.awaiting_damage_prevention, "no seat asked for one")
	assert_eq(g.players[1].life, 1, "the damage simply landed")


func test_every_reactive_profile_asks_for_the_window() -> void:
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_true(AiPlayer.new(0, profile).wants_damage_prevention_window(),
			profile.profile_name)
		assert_true(profile.holds_instants,
			"%s: the window IS the reactive game" % profile.profile_name)


# --------------------------------------------------- which packet, if any --

func test_the_ai_circles_the_damage_that_would_kill_it() -> void:
	var ai := _arm(1)
	g.players[1].life = 3
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")     # 3/3 red
	var said := _combat_with_ai(ai, [giant.id])
	assert_true(str(said).contains("Circle of Protection: Red"), str(said))
	assert_eq(g.players[1].life, 3, "the Circle answered the packet")
	assert_false(g.awaiting_damage_prevention, "and the window is shut")


func test_the_ai_does_not_spend_a_circle_on_a_scratch() -> void:
	# 20 life against 3 damage is not the profile's panic line, and a
	# Circle is worth more next turn than three points are now.
	var ai := _arm(1)
	put_battlefield(1, "Circle of Protection: Red")
	var mountain := put_battlefield(1, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	_combat_with_ai(ai, [giant.id])
	assert_eq(g.players[1].life, 17, "it took the hit")
	assert_false(mountain.tapped, "and spent nothing")


func test_the_ai_answers_the_biggest_packet_it_can_actually_reach() -> void:
	# Worst first, then DOWN the list: the biggest packet here is green and
	# a Circle of Protection: Red cannot name it, so the AI takes the red
	# one rather than giving up on the window.
	var ai := _arm(1)
	g.players[1].life = 4
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Mountain")
	var wurm := put_battlefield(0, "Craw Wurm")       # 6/4 green
	var giant := put_battlefield(0, "Hill Giant")     # 3/3 red
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id, giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the window opened")
	var said := _play_the_window(ai)
	assert_true(str(said).contains("Hill Giant"), str(said))
	assert_eq(g.players[1].life, -2,
		"the Wurm still landed; the Giant did not")


func test_a_circle_is_not_a_creature_saver() -> void:
	# Every Circle reads "would deal damage TO YOU". The 1997 targeted form
	# used to accept any packet of the right colour, so the AI's
	# cheapest-effect search would have spent one saving a creature the
	# card never mentions (found building this heuristic, 2026-09-01).
	var ai := _arm(1)
	var circle := put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")   # 2/2
	var giant := put_battlefield(0, "Hill Giant")
	plant_damage_packet(giant, TargetRef.card(bear), 3)
	var spec: TargetSpec = circle.cur_activated_abilities[0].effects[0].target_spec
	assert_eq(spec.legal_targets(g, circle).size(), 0,
		"a packet aimed at a creature is not damage to YOU")
	# ...and the AI does not try: nothing it holds can answer that packet.
	g.awaiting_damage_prevention = true
	g.priority_player = 1
	assert_eq(ai.act(g), "ends damage prevention")


# --------------------------------------------------------- which effect --

func test_the_ai_spends_the_cheapest_effect_that_covers_the_packet() -> void:
	# Two ways to answer the same three points: a {1} Circle activation,
	# which costs no card, and a {W} Healing Salve out of hand, which does.
	# The roadmap row's own proposal is the cheapest that covers it.
	var ai := _arm(1)
	g.players[1].life = 3
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Mountain")
	give_hand(1, "Healing Salve")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id])
	assert_true(str(said).contains("Circle of Protection: Red"), str(said))
	assert_eq(g.players[1].life, 3)
	assert_eq(g.players[1].hand.size(), 1, "the card stayed in hand")


func test_the_ai_buys_one_answer_and_waits_for_it() -> void:
	# An answer on the chain has not resolved: the packet still reads its
	# full remaining and the creature still has no shield. Without a guard
	# the AI reads the same emergency again and buys the same Circle until
	# the mana runs out — legal (*"you may use the Circle on the same
	# damage more than once"*) and pure waste.
	var ai := _arm(1)
	g.players[1].life = 3
	put_battlefield(1, "Circle of Protection: Red")
	var first := put_battlefield(1, "Mountain")
	var second := put_battlefield(1, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id])
	var bought := 0
	for line in said:
		if line.contains("Circle of Protection: Red"):
			bought += 1
	assert_eq(bought, 1, str(said))
	assert_eq(g.players[1].life, 3, "and one was enough")
	var paid := int(first.tapped) + int(second.tapped)
	assert_eq(paid, 1, "one Mountain paid for it")


func test_a_fog_is_never_spent_inside_the_window() -> void:
	# `PreventCombatDamageEffect` raises `MtgGame.combat_damage_prevented`,
	# which the damage STEP reads before each wave — so a Fog cast in the
	# window stops the wave that has not happened yet and does nothing at
	# all to the packets already on the table. The window still OPENS for
	# it (that is the engine's auto-skip talking, and it is right: a Fog in
	# the FIRST-STRIKE window really does stop the normal wave), but
	# spending one here would throw the card away.
	var ai := _arm(1)
	g.players[1].life = 3
	put_battlefield(1, "Forest")
	give_hand(1, "Fog")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id])
	assert_eq(str(said), str(PackedStringArray(["ends damage prevention"])),
		"it looked at the window and left it")
	assert_eq(g.players[1].hand.size(), 1, "the Fog is still in hand")
	assert_eq(g.players[1].life, 0, "and the damage landed")


# -------------------------------------------------------- regeneration --

func test_the_ai_regenerates_a_creature_that_is_actually_dying() -> void:
	var ai := _arm(1)
	var skeleton := put_battlefield(1, "Drudge Skeletons")   # 1/1, {B}: regen
	put_battlefield(1, "Swamp")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id], {skeleton.id: giant.id})
	assert_true(str(said).contains("regenerates Drudge Skeletons"), str(said))
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD, "it lived")
	assert_true(skeleton.tapped, "regeneration taps it (CR 701.15)")


func test_the_ai_does_not_regenerate_speculatively() -> void:
	# `Duel.hlp`, **Regeneration**: *"You can use regeneration ONLY at the
	# time when a creature is about to go to the graveyard."* A 1/1 that
	# took nothing is not about to go anywhere, and the mana stays unspent.
	var ai := _arm(1)
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	var swamp := put_battlefield(1, "Swamp")
	# A bear of ours IS dying, so the window really opens and the AI really
	# looks at it; the skeleton beside it is untouched and stays that way.
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id], {bear.id: giant.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the bear died")
	assert_eq(str(said), str(PackedStringArray(["ends damage prevention"])),
		str(said))
	assert_eq(skeleton.regeneration_shields, 0, "no shield was bought")
	assert_false(swamp.tapped, "and no mana was spent")


func test_the_most_valuable_doomed_creature_is_saved_first() -> void:
	# One black mana, two dying regenerators: the bigger body wins, and it
	# is [Evaluator] that says which is bigger — the same measure the rest
	# of this file's decisions use.
	var ai := _arm(1)
	var skeleton := put_battlefield(1, "Drudge Skeletons")   # 1/1
	var troll := put_battlefield(1, "Sedge Troll")           # 2/2, {B}: regen
	put_battlefield(1, "Swamp")
	plant_damage_packet(put_battlefield(0, "Hill Giant"),
		TargetRef.card(skeleton), 4)
	plant_damage_packet(put_battlefield(0, "Craw Wurm"),
		TargetRef.card(troll), 4)
	# Land the damage and open the regeneration window over both bodies.
	g._land_pending_damage()
	assert_true(g.awaiting_regeneration, "both are about to die")
	var said := _play_the_window(ai)
	assert_true(str(said).contains("Sedge Troll"), str(said))
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "the troll lived")
	assert_eq(skeleton.zone, Mtg.Zone.GRAVEYARD,
		"there was only mana for one")


# ---------------------------------------------------------- determinism --

func test_a_fumbled_window_is_a_declined_window() -> void:
	# Mistake injection reaches the window like it reaches every other
	# decision, and it is rolled on `game.rng` — a seeded duel replays its
	# windows line for line. A profile that always fumbles never acts.
	var always_wrong := AiProfile.new("Butterfingers", 1.0, 0.5, 9, true)
	var ai := _arm(1, always_wrong)
	g.players[1].life = 3
	put_battlefield(1, "Circle of Protection: Red")
	put_battlefield(1, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	var said := _combat_with_ai(ai, [giant.id])
	assert_eq(str(said), str(PackedStringArray(["ends damage prevention"])),
		str(said))
	assert_eq(g.players[1].life, 0, "every window was fumbled")


func test_two_seeded_duels_take_the_same_windows() -> void:
	# The Deck Lab's whole determinism check rests on this.
	var lines: Array[String] = []
	for _run in 2:
		var duel := MtgGame.new()
		duel.rules.damage_prevention_window = true
		var deck := StarterDecks.WHITE_KNIGHTS
		duel.setup(deck, StarterDecks.BLACK_RED_RAIDERS, "A", "B", 1, 1, 99)
		var ai0 := AiPlayer.new(0, AiProfile.wizard())
		var ai1 := AiPlayer.new(1, AiProfile.wizard())
		duel.set_agent(0, ai0)
		duel.set_agent(1, ai1)
		duel.deal_opening_hands(7)
		duel.start_duel(0)
		AiPlayer.play_out(duel, ai0, ai1)
		lines.append("\n".join(duel.log_lines))
	assert_eq(lines[0].length(), lines[1].length(), "same length")
	assert_true(lines[0] == lines[1], "the same duel, line for line")
