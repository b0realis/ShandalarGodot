extends GameTest
## THEIR PUMPS ARE PUBLIC (2026-09-10, [member AiProfile.reads_pumps];
## `docs/forge/combat.md` P2).
##
## [method AiPlayer._shieldable] has counted their open mana against their
## cheapest regeneration shield since the block audit, so a Drudge
## Skeletons with {B} up is a wall to every kill this pilot predicts. The
## other printed line their mana buys was read by nobody: a Shivan Dragon
## with three Mountains was a 5/5 and a Frozen Shade with four Swamps was
## a 0/1. Reproduced before a line was written, on the owner's own board:
##
##     _dies_to(Bears, Shade)  = false   _dies_to(Shade, Bears) = true
##     _attack_risk(Bears)     = 0.00
##     declared 1 attacker(s)
##     after combat: Bears GRAVEYARD, Shade BATTLEFIELD, their life 20
##
## — a 2/2 sent into a 0/1 behind four untapped Swamps, "we kill it and
## live", and the body in the graveyard with nothing to show for it.
##
## THE READING IS ASYMMETRIC and the Lab is what put it that way rather
## than the design. Their pump deciding whether THEIR body dies is read
## everywhere, at [method AiPlayer._dies_to]'s own seam. Their pump
## deciding whether OURS dies is read only where we are choosing to SEND a
## body into it — [method AiPlayer._attack_risk] and [method
## AiPlayer._cohort_value], the two halves of the attack declaration — and
## not where we are choosing to put one in FRONT of it, because read there
## it took whole block declarations away (three Carrion Ants behind six
## Swamps walked past three Hill Giants for six a turn) and measured -2.4
## +-2.8 against Vampire Lord on the deck that half hurts most.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_pumps = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_pumps = false
	return profile


func _blockers(seat: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[seat].battlefield:
		if inst.is_creature() and not inst.tapped:
			out.append(inst)
	return out


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Walk priority from our first main phase to OUR attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


## Hand the turn to seat 1 and walk it to its declare-attackers.
func _their_turn() -> void:
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
	assert_true(g.awaiting_attackers, "reached their declaration")


func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_END \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ------------------------------------------------ the board the owner met --

func test_the_bears_does_not_walk_into_a_frozen_shade() -> void:
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 4)
	assert_eq(ai._pump_reach(g, shade), Vector2i(2, 2),
		"four Swamps, and the Bears is what caps it at two")
	assert_almost_eq(ai._attack_risk(g, bears, _blockers(1), 1), 4.00, 0.01,
		"a pure loss, not a free swing")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	_play_out_combat(ai, foe)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the body is still ours")
	assert_eq(g.players[1].life, 20)


func test_off_the_bears_walks_into_it() -> void:
	# The malfunction as the owner met it, so the null is the pilot as it
	# was: "the pilot pumps its own creatures ... but it will still attack
	# a 0/1 Frozen Shade with four Swamps up."
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 4)
	assert_eq(ai._pump_reach(g, shade), Vector2i.ZERO, "nothing is read at all")
	assert_almost_eq(ai._attack_risk(g, bears, _blockers(1), 1), 0.00, 0.01,
		"we kill it and live")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "and the Bears is gone")
	assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD, "with the Shade still standing")
	assert_eq(g.players[1].life, 20, "and nothing landed")


func test_the_group_half_of_the_declaration_pays_it_too() -> void:
	# [method AiPlayer._cohort_value] is the GROUP half of what
	# [method AiPlayer._attack_risk] asks per creature, and it has to be
	# paid there too or the cohort re-adds the body the per-creature
	# filter refused — the same place the executioner had to be paid.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var bears := put_battlefield(0, "Grizzly Bears")
		put_battlefield(1, "Frozen Shade")
		_lands(1, "Swamp", 4)
		var group: Array[CardInstance] = [bears]
		assert_almost_eq(ai._cohort_value(g, group, _blockers(1), 1),
			-4.00 if on else 1.00, 0.01,
			"the group is worth losing a Grizzly Bears" if on
				else "and the null reads it as a gain")


# -------------------------------------------------------------- the reach --

func test_one_swamp_buys_one_activation() -> void:
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	put_battlefield(0, "Grizzly Bears")
	_lands(1, "Swamp", 1)
	assert_eq(ai._pump_reach(g, shade), Vector2i(1, 1))


func test_the_cap_is_what_the_board_can_ask() -> void:
	# Ten Swamps and a 2/2 across the table: +3/+3 and +10/+10 answer
	# every question on that board the same way, so the reading is +2/+2
	# and no reader downstream inherits a number it could believe.
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	put_battlefield(0, "Grizzly Bears")
	_lands(1, "Swamp", 10)
	assert_eq(ai._pump_reach(g, shade), Vector2i(2, 2))


func test_a_board_with_nothing_of_ours_on_it_asks_nothing() -> void:
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 6)
	assert_eq(ai._pump_reach(g, shade), Vector2i.ZERO,
		"no body of ours, no kill answer to change")


func test_the_printed_per_turn_cap_is_read() -> void:
	# A Fire Drake's breath is once each turn and a Vampire Bats' twice,
	# so the mana is not the whole of the reading — the same fact
	# [method AiPlayer._activations_left] keeps for our own breath.
	var ai := _ai(_on())
	put_battlefield(0, "Craw Wurm")
	var drake := put_battlefield(1, "Fire Drake")
	_lands(1, "Mountain", 5)
	assert_eq(ai._pump_reach(g, drake), Vector2i(1, 0), "five Mountains, one breath")
	before_each()
	var ai2 := _ai(_on())
	put_battlefield(0, "Craw Wurm")
	var bats := put_battlefield(1, "Vampire Bats")
	_lands(1, "Swamp", 6)
	assert_eq(ai2._pump_reach(g, bats), Vector2i(2, 0), "six Swamps, two breaths")


func test_one_pool_is_shared_among_the_bodies_that_want_it() -> void:
	# Their mana is spent ONCE. Read whole for each of them, three Carrion
	# Ants behind six Swamps were three 6/7s and the ladder declared no
	# block at all.
	var ai := _ai(_on())
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Hill Giant")
	var first := put_battlefield(1, "Carrion Ants")
	_lands(1, "Swamp", 6)
	assert_eq(ai._pump_claimants(g, first), 1, "one body, the whole pool")
	assert_eq(ai._pump_reach(g, first), Vector2i(6, 6))
	put_battlefield(1, "Carrion Ants")
	put_battlefield(1, "Carrion Ants")
	assert_eq(ai._pump_claimants(g, first), 3, "three bodies, one pool")
	assert_eq(ai._pump_reach(g, first), Vector2i(2, 2))


# ------------------------------------------------------- the over-read pins --

func test_mana_they_cannot_spend_is_not_read() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	for _i in 4:
		var swamp := put_battlefield(1, "Swamp")
		swamp.tapped = true
	assert_eq(ai._pump_reach(g, shade), Vector2i.ZERO,
		"four Swamps already spent are four Swamps")


func test_a_source_that_cannot_be_tapped_yet_is_not_read() -> void:
	# Their mana is counted the way [method AiPlayer._shieldable] counts
	# it, and a summoning-sick Llanowar Elves is no source this turn. The
	# board is deliberately one Swamp short of the cap, so counting the
	# Elf would show as +2/+2 and not counting it as +1/+1.
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 1)
	put_battlefield(1, "Llanowar Elves", true)
	assert_eq(ai._pump_reach(g, shade), Vector2i(1, 1))


func test_a_tap_cost_pump_is_not_read() -> void:
	# A body that taps to pump cannot also block, so a breath with {T} in
	# it is no reason to fear the body. Written as a synthetic permanent
	# because this pool prints no such creature — the reading is of the
	# SHAPE and not of a card.
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var data := CardData.new("Tapping Shade", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.activated(ActivatedAbility.new("{B}", true,
			[PumpEffect.new(1, 1).self_buff()], "{B}, {T}: This creature gets +1/+1."))
	var tapper := put_synthetic(1, data)
	_lands(1, "Swamp", 4)
	assert_eq(ai._pump_reach(g, tapper), Vector2i.ZERO)


func test_a_pump_whose_cost_is_a_board_is_not_read() -> void:
	# An Atog eats an artifact and a Fallen Angel a creature; what those
	# cost is a board, not a Swamp, and nothing here prices a board.
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var atog := put_battlefield(1, "Atog")
	_lands(1, "Mountain", 4)
	put_battlefield(1, "Mana Vault")
	assert_eq(ai._pump_reach(g, atog), Vector2i.ZERO)


func test_a_pump_on_a_creature_of_ours_is_not_this_reading() -> void:
	# [member AiProfile.pumps_to_attack] sizes our own body by our own
	# open mana, through the real planner with the second main phase and
	# the held instant booked out of the pool. Two readers for one side
	# would be two answers.
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var ours := put_battlefield(0, "Frozen Shade")
	_lands(0, "Swamp", 4)
	assert_eq(ai._pump_reach(g, ours), Vector2i.ZERO)


func test_a_creature_with_no_activated_ability_is_untouched() -> void:
	# The bail that keeps this off the cost of the crack-back matrix, and
	# it is nearly the whole pool.
	var ai := _ai(_on())
	put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	_lands(1, "Forest", 4)
	assert_eq(ai._pump_reach(g, wurm), Vector2i.ZERO)


func test_a_board_where_the_pump_changes_nothing_is_unchanged() -> void:
	# A Force of Nature reads the Shade at +4/+4 and answers every
	# question about it exactly as the null does: an 8/8 kills a 4/5 and
	# is not killed by one. A pump that does not change who dies is still
	# their mana to spend.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var force := put_battlefield(0, "Force of Nature")
		var shade := put_battlefield(1, "Frozen Shade")
		_lands(1, "Swamp", 4)
		var group: Array[CardInstance] = [force]
		assert_true(ai._dies_to(g, shade, force), "we kill it either way")
		assert_false(ai._dies_to(g, force, shade), "and it never kills us")
		assert_almost_eq(ai._attack_risk(g, force, _blockers(1), 1), 0.00, 0.01)
		assert_almost_eq(ai._cohort_value(g, group, _blockers(1), 1), 10.45, 0.01)


# ------------------------------------------------------------ the gang --

func test_the_gang_is_priced_against_the_body_it_will_meet() -> void:
	var ai := _ai(_on())
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var ants := put_battlefield(1, "Carrion Ants")
	_lands(1, "Swamp", 4)
	var band: Array[CardInstance] = [b1, b2]
	assert_eq(ai._pump_reach(g, ants), Vector2i(4, 4))
	assert_false(ai._band_kills(g, ants, band),
		"four damage against a toughness of five")
	var used: Array[int] = []
	assert_eq(ai._best_block_for(g, ants, band, used, false).size(), 0,
		"so neither the single block nor the gang is declared")


func test_off_the_gang_is_priced_at_the_printed_0_1() -> void:
	var ai := _ai(_off())
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var ants := put_battlefield(1, "Carrion Ants")
	_lands(1, "Swamp", 4)
	var band: Array[CardInstance] = [b1, b2]
	assert_true(ai._band_kills(g, ants, band), "four damage against a toughness of one")
	var used: Array[int] = []
	assert_eq(ai._best_block_for(g, ants, band, used, false).size(), 1,
		"and one Bears is sent to kill it and live")


# ------------------------------------------ the crack-back model and the gaze --

func test_the_crack_back_matrix_reads_the_body_it_cannot_kill() -> void:
	var ai := _ai(_on())
	var bears := put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 4)
	var mine: Array[CardInstance] = [bears]
	var theirs: Array[CardInstance] = [shade]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.we_kill[0], 0, "a 2/2 does not kill a Shade behind four Swamps")
	assert_eq(model.they_kill[0], 0,
		"and the other direction is the attack declaration's, not the model's")


func test_off_the_crack_back_matrix_reads_the_printed_0_1() -> void:
	var ai := _ai(_off())
	var bears := put_battlefield(0, "Grizzly Bears")
	var shade := put_battlefield(1, "Frozen Shade")
	_lands(1, "Swamp", 4)
	var mine: Array[CardInstance] = [bears]
	var theirs: Array[CardInstance] = [shade]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.we_kill[0], 1, "the null kills it on the printed numbers")
	assert_eq(model.they_kill[0], 0)


func test_the_gaze_outranks_the_pump() -> void:
	# A Thicket Basilisk destroys what it blocks or is blocked by whatever
	# the numbers say, so a Shade that grows out of reach of two damage
	# still dies — the pump clause sits AFTER the gaze on purpose.
	for on in [true, false]:
		before_each()
		var profile := _on() if on else _off()
		var ai := _ai(profile)
		var bas := put_battlefield(0, "Thicket Basilisk")
		var shade := put_battlefield(1, "Frozen Shade")
		_lands(1, "Swamp", 4)
		assert_true(ai._dies_to(g, shade, bas), "the gaze takes it either way")


func test_without_the_gaze_the_pump_is_the_whole_answer() -> void:
	# The same board with [member AiProfile.reads_gaze] off: now the
	# arithmetic is all there is, and the pump decides it. The two knobs
	# compose rather than fight.
	for on in [true, false]:
		before_each()
		var profile := _on() if on else _off()
		profile.reads_gaze = false
		var ai := _ai(profile)
		var bas := put_battlefield(0, "Thicket Basilisk")
		var shade := put_battlefield(1, "Frozen Shade")
		_lands(1, "Swamp", 4)
		assert_eq(ai._dies_to(g, shade, bas), not on,
			"a toughness of five with the reading, of one without it")


# --------------------------------------------------------------- the ladder --

func test_the_ladder_reads_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().reads_pumps)
	assert_false(AiProfile.magician().reads_pumps)
	assert_true(AiProfile.sorcerer().reads_pumps)
	assert_true(AiProfile.wizard().reads_pumps)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("reads_pumps=off"), "")
	assert_false(profile.reads_pumps)
	assert_eq(profile.apply_overrides("reads_pumps=on"), "")
	assert_true(profile.reads_pumps)
