extends GameTest
## PLAYER REPORT 2026-11-26, the leftovers of the spell timing
## (engine/ai/spell_timing.gd):
##  1. a trick the reader has no model for ("Target creature gets +0/+X …",
##     "… it gets +4/-4 …") is aimed by its printed line — a gift at our own
##     creature — and, by a pilot that holds instants, held for the combat
##     and cast where the declared combat ends about a card better;
##  2. "… equal to the damage dealt to you this turn" is held while no
##     damage was dealt, and cast once it was;
##  3. an X of nothing but our own life is held at full life out of danger;
##  4. the Apprentice, which holds no instant, still casts a spell whose
##     only moment is a combat in that combat — and nothing else.

const TIMING := preload("res://engine/ai/spell_timing.gd")


func after_each() -> void:
	g = null


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


## Our main phase, until the pilot passes.
func _main(ai: AiPlayer) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var lines: Array = []
	for _i in 8:
		if g.game_over or g.priority_player != 0 or g.current_step() != Mtg.Step.MAIN1:
			break
		var line := ai.act(g)
		lines.append(line)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass": break
	return lines


## Their turn: [param attackers] attack, the pilot answers every priority
## it gets until the turn's end; [param blocks] is declared for it.
func _their_attack(ai: AiPlayer, attackers: Array, blocks: Dictionary = {},
		through := Mtg.Step.DECLARE_BLOCKERS) -> Array:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(1, ids))
	var lines: Array = []
	var guard := 0
	while not g.game_over and guard < 80 and g.active_player == 1 \
			and g.current_step() <= through:
		guard += 1
		if g.awaiting_blockers:
			var live := {}
			for blocker_id in blocks:
				var blocker := g.find_instance(blocker_id)
				var attacker := g.find_instance(blocks[blocker_id])
				if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD \
						and attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
					live[blocker_id] = blocks[blocker_id]
			assert_ok(g.declare_blockers(0, live))
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
		else:
			g.pass_priority(1)
	return lines


## Our turn: the pilot plays it all; they block as [param blocks] says
## (attacker id by blocker id), with what is still there.
func _our_turn(ai: AiPlayer, blocks: Dictionary = {}) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var lines: Array = []
	var guard := 0
	while not g.game_over and g.active_player == 0 and guard < 120:
		guard += 1
		if g.awaiting_blockers and g.block_chooser() == 1:
			var live := {}
			for blocker_id in blocks:
				if g.combat.attackers.has(blocks[blocker_id]):
					live[blocker_id] = blocks[blocker_id]
			assert_ok(g.declare_blockers(1, live))
		elif g.awaiting_attackers or g.priority_player == 0:
			var line := ai.act(g)
			if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
		else:
			g.pass_priority(1)
	return lines


# ------------------------------------------------ 1 the side of the table --

func test_a_printed_gift_is_never_aimed_across_the_table() -> void:
	# Great Defender on their Hill Giant; Blood Lust on their Craw Wurm.
	for profile in _rungs():
		for card_name in ["Great Defender", "Blood Lust"]:
			before_each()
			var ai := _ai(profile)
			for _i in 2: put_battlefield(0, "Plains")
			for _i in 2: put_battlefield(0, "Mountain")
			put_battlefield(0, "Grizzly Bears")
			var giant := put_battlefield(1, "Hill Giant")
			var wurm := put_battlefield(1, "Craw Wurm")
			var card := give_hand(0, card_name)
			advance_to_step(Mtg.Step.MAIN1)
			var lines: Array = []
			var aimed: Array = []
			var guard := 0
			# Our whole turn and theirs, with whatever attacks the pilot makes.
			while not g.game_over and guard < 200 and g.turn_number <= 2:
				guard += 1
				if g.awaiting_blockers:
					assert_ok(g.declare_blockers(g.block_chooser(), {}))
				elif g.awaiting_attackers and g.active_player == 1:
					assert_ok(g.declare_attackers(1, [giant.id, wurm.id]))
				elif g.awaiting_attackers or g.priority_player == 0:
					var line := ai.act(g)
					if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
					for item in g.stack:
						if item.card == card:
							for t in item.targets:
								aimed.append(g.find_instance(t.instance_id))
				else:
					g.pass_priority(1)
			for body in aimed:
				assert_eq(body.controller_id, 0, "%s, %s at %s: %s" % [profile.profile_name,
					card_name, body.data.card_name, lines])


func test_the_shape_is_read_off_the_printed_line() -> void:
	var rows := {"Great Defender": 1, "Blood Lust": 2, "Giant Growth": 0, "Lightning Bolt": 0,
		"Howl from Beyond": 0, "Sandstorm": 0, "Simulacrum": 0, "Righteousness": 0}
	for card_name in rows:
		assert_eq(TIMING.trick_of(CardRegistry.get_card(card_name)), rows[card_name], card_name)
	assert_eq(TIMING._read_trick(TIMING.plain("Target creature gets -2/-0 until end of turn.")), 0)
	assert_eq(TIMING._read_trick(TIMING.plain("Target creature gets -1/+2 until end of turn.")), 0)
	assert_eq(TIMING._read_trick(TIMING.plain("Target green creature gets +x/+x until end of turn, where x is its power.")), 1)
	assert_eq(TIMING._read_trick(TIMING.plain("Destroy target creature. Its controller gets +1/+1.")), 0)


func test_a_held_trick_waits_for_the_combat() -> void:
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		for card_name in ["Great Defender", "Blood Lust"]:
			before_each()
			var ai := _ai(profile)
			for _i in 2: put_battlefield(0, "Plains")
			for _i in 2: put_battlefield(0, "Mountain")
			put_battlefield(0, "Wall of Stone")
			put_battlefield(1, "Craw Wurm")
			var card := give_hand(0, card_name)
			var lines := _main(ai)
			assert_eq(card.zone, Mtg.Zone.HAND, "%s, %s: %s" % [profile.profile_name, card_name, lines])


func test_great_defender_saves_our_blocker() -> void:
	# Our Hill Giant (mana value 4) blocks their Hill Giant: 3/7 lives.
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		var ai := _ai(profile)
		put_battlefield(0, "Plains")
		var ours := put_battlefield(0, "Hill Giant")
		var theirs := put_battlefield(1, "Hill Giant")
		var card := give_hand(0, "Great Defender")
		var lines := _their_attack(ai, [theirs], {ours.id: theirs.id}, Mtg.Step.END)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)
		assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, profile.profile_name)


func test_great_defender_waits_when_it_saves_nothing() -> void:
	# Bears (mana value 2) under a Craw Wurm die at 2/4 all the same; an
	# unblocked attack is no business of a toughness boost.
	var ai := _ai()
	put_battlefield(0, "Plains")
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var card := give_hand(0, "Great Defender")
	var lines := _their_attack(ai, [wurm], {bears.id: wurm.id}, Mtg.Step.END)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))
	before_each()
	ai = _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Grizzly Bears")
	wurm = put_battlefield(1, "Craw Wurm")
	card = give_hand(0, "Great Defender")
	lines = _their_attack(ai, [wurm], {}, Mtg.Step.END)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))


func test_blood_lust_goes_on_our_unblocked_attacker() -> void:
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	var card := give_hand(0, "Blood Lust")
	var lines := _our_turn(ai)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, str(lines))
	assert_eq(g.players[1].life, 13, "3 and 4: %s" % [lines])
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_blood_lust_makes_their_attacker_die_to_our_blocker() -> void:
	# Their Craw Wurm attacks, our Bears block: at 10/1 the Wurm dies to
	# the Bears — the one creature of theirs the printed line is aimed at.
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Mountain")
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var card := give_hand(0, "Blood Lust")
	var lines := _their_attack(ai, [wurm], {bears.id: wurm.id}, Mtg.Step.END)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, str(lines))
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, str(lines))


func test_blood_lust_is_not_thrown_at_an_unblocked_attacker_of_theirs() -> void:
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var card := give_hand(0, "Blood Lust")
	var lines := _their_attack(ai, [wurm], {}, Mtg.Step.END)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))
	assert_eq(g.players[0].life, 14)


func test_blood_lust_kills_the_attacker_our_wall_holds() -> void:
	# Wall of Stone (0/8) blocks a Hill Giant: at 4/4 the Wall kills it and
	# lives.
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Mountain")
	var wall := put_battlefield(0, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	var card := give_hand(0, "Blood Lust")
	var lines := _their_attack(ai, [giant], {wall.id: giant.id}, Mtg.Step.END)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, str(lines))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, str(lines))
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)


func test_null_arm_aims_it_as_before() -> void:
	var ai := _ai(_null())
	put_battlefield(0, "Plains")
	put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var card := give_hand(0, "Great Defender")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_false(g.stack.is_empty(), "the gate off is the pilot as it was")
	if not g.stack.is_empty():
		assert_eq(g.stack.back().targets[0].instance_id, giant.id)
	assert_ne(card.zone, Mtg.Zone.HAND)


# ---------------------------------------------- 2 the damage of this turn --

func _tally_board(card_name: String) -> CardInstance:
	for _i in 2: put_battlefield(0, "Swamp")
	for _i in 2: put_battlefield(0, "Plains")
	put_battlefield(0, "Wall of Stone")
	return give_hand(0, card_name)


func test_the_tally_spells_wait_for_damage() -> void:
	for profile in _rungs():
		for card_name in ["Simulacrum", "Reverse Polarity"]:
			before_each()
			var ai := _ai(profile)
			var card := _tally_board(card_name)
			advance_to_step(Mtg.Step.MAIN1)
			assert_ne(ai._cast_gate(g, card), "", "%s: no damage yet" % card_name)
			var lines := _main(ai)
			assert_eq(card.zone, Mtg.Zone.HAND, "%s, %s: %s" % [profile.profile_name, card_name, lines])


func test_reverse_polarity_reads_artifact_damage_only() -> void:
	var ai := _ai()
	var card := _tally_board("Reverse Polarity")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.deal_damage(bears, TargetRef.player(0), 2)
	assert_ne(ai._cast_gate(g, card), "", "a creature's damage is not an artifact's")
	var rod := put_battlefield(1, "Rod of Ruin")
	g.deal_damage(rod, TargetRef.player(0), 1)
	assert_eq(ai._cast_gate(g, card), "")


func test_simulacrum_is_cast_once_damage_was_dealt() -> void:
	# A Craw Wurm gets through for six: at their end step the six come back
	# and the Wall of Stone takes them.
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		var ai := _ai(profile)
		var card := _tally_board("Simulacrum")
		var wurm := put_battlefield(1, "Craw Wurm")
		var lines := _their_attack(ai, [wurm], {}, Mtg.Step.END)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(g.players[0].life, 20, profile.profile_name)


func test_reverse_polarity_is_cast_once_an_artifact_hit_us() -> void:
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		var ai := _ai(profile)
		var card := _tally_board("Reverse Polarity")
		var jug := put_battlefield(1, "Juggernaut")
		var lines := _their_attack(ai, [jug], {}, Mtg.Step.END)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(g.players[0].life, 25, profile.profile_name)


func test_the_tally_is_cast_in_our_own_main_phase_too() -> void:
	# The Apprentice's way: damage taken on its own turn.
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		var card := _tally_board("Simulacrum")
		var bears := put_battlefield(1, "Grizzly Bears")
		advance_to_step(Mtg.Step.MAIN1)
		g.deal_damage(bears, TargetRef.player(0), 6)
		var lines := _main(ai)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])


func test_null_arm_casts_the_tally_for_nothing() -> void:
	var ai := _ai(_null())
	var card := _tally_board("Simulacrum")
	_main(ai)
	assert_ne(card.zone, Mtg.Zone.HAND, "the gate off is the pilot as it was")


# ------------------------------------------------- 3 the life not needed --

func _stream(forests: int, life: int, across: String, extra_hand := 0, profile: AiProfile = null) -> Dictionary:
	before_each()
	var ai := _ai(profile)
	g.players[0].life = life
	for _i in forests: put_battlefield(0, "Forest")
	if across != "": put_battlefield(1, across)
	var stream := give_hand(0, "Stream of Life")
	for _i in extra_hand: give_hand(0, "Shivan Dragon")
	var lines := _main(ai)
	return {"cast": stream.zone != Mtg.Zone.HAND, "life": g.players[0].life, "lines": lines}


func test_stream_of_life_is_held_at_full_life() -> void:
	for profile in _rungs():
		var full := _stream(9, 20, "Grizzly Bears", 0, profile)
		assert_false(bool(full["cast"]), "%s, eight life at twenty: %s" % [profile.profile_name, full["lines"]])
	var above := _stream(9, 26, "Hill Giant")
	assert_false(bool(above["cast"]), str(above["lines"]))


func test_stream_of_life_is_cast_below_full_life() -> void:
	var hurt := _stream(9, 13, "Grizzly Bears")
	assert_true(bool(hurt["cast"]), str(hurt["lines"]))
	assert_eq(int(hurt["life"]), 21)


func test_stream_of_life_at_full_life_goes_before_it_is_discarded() -> void:
	var full := _stream(9, 20, "Grizzly Bears", 7)
	assert_true(bool(full["cast"]), "eight cards in hand: %s" % [full["lines"]])


func test_stream_of_life_at_full_life_is_cast_under_a_lethal_board() -> void:
	before_each()
	var ai := _ai()
	for _i in 9: put_battlefield(0, "Forest")
	for _i in 4: put_battlefield(1, "Craw Wurm")
	var stream := give_hand(0, "Stream of Life")
	assert_true(ai._in_danger(g), "twenty-four power across")
	var lines := _main(ai)
	assert_ne(stream.zone, Mtg.Zone.HAND, str(lines))


func test_null_arm_streams_at_full_life() -> void:
	var p := _null()
	var full := _stream(9, 20, "Grizzly Bears", 0, p)
	assert_true(bool(full["cast"]), "the gate off is the pilot as it was")


# ---------------------------------------------- 4 the Apprentice's combat --

func test_the_apprentice_casts_sandstorm_in_their_combat() -> void:
	var ai := _ai(AiProfile.apprentice())
	put_battlefield(0, "Forest")
	var lions := [put_battlefield(1, "Savannah Lions"), put_battlefield(1, "Savannah Lions")]
	var storm := give_hand(0, "Sandstorm")
	var lines := _their_attack(ai, lions)
	assert_eq(storm.zone, Mtg.Zone.GRAVEYARD, str(lines))
	assert_eq(lions[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


func test_the_apprentice_holds_it_when_nothing_would_die() -> void:
	var ai := _ai(AiProfile.apprentice())
	put_battlefield(0, "Forest")
	var giant := put_battlefield(1, "Hill Giant")
	var storm := give_hand(0, "Sandstorm")
	var lines := _their_attack(ai, [giant], {}, Mtg.Step.END)
	assert_eq(storm.zone, Mtg.Zone.HAND, str(lines))


func test_the_apprentice_still_holds_no_other_instant() -> void:
	# A Bolt, a Giant Growth, a Fog, a Counterspell, a Great Defender: their
	# combat, and their turn, pass untouched.
	var ai := _ai(AiProfile.apprentice())
	for land in ["Forest", "Mountain", "Island", "Plains"]:
		for _i in 2: put_battlefield(0, land)
	var bears := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	var hand: Array = []
	for card_name in ["Lightning Bolt", "Giant Growth", "Fog", "Counterspell", "Great Defender"]:
		hand.append(give_hand(0, card_name))
	var state := 0
	advance_to_next_turn()
	state = g.rng.state
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [lions.id]))
	var lines: Array = []
	var guard := 0
	while not g.game_over and guard < 80 and g.active_player == 1:
		guard += 1
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(0, {bears.id: lions.id}))
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line != "pass": lines.append(line)
		else:
			g.pass_priority(1)
	assert_eq(lines, [])
	for card in hand:
		assert_eq(card.zone, Mtg.Zone.HAND, card.data.card_name)
	assert_eq(g.rng.state, state, "and no die was rolled for it")
