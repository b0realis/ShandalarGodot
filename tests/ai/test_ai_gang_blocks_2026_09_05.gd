extends GameTest
## THE GANG BLOCK (2026-09-05) — [CombatSearch] read with more than one
## body on an attacker.
##
## WHAT WAS SIMPLIFIED. Every model of a combat this AI ran assigned at
## most ONE blocker to an attacker: `_cohort_value` and
## `_damage_through_blocks` for the forward attack, and both defensive
## plies of the crack-back search. The ENGINE has always implemented gang
## blocks fully — it is the AI's reading of them that was flat — and the
## measurement that kept the shortcut there was that the defender gang-
## blocks in 46 of 1,022 logged combats (4.5%).
##
## WHAT THIS FILE PINS, in two halves:
##
## 1. **The arithmetic is the engine's, not a second rules model.**
##    [method CombatSearch.resolve_block] resolves one attacker against a
##    whole gang — CR 509.2's damage order, CR 510.1c's lethal-first walk
##    down it, CR 702.19b's trample spill, CR 510.4's first strike — and
##    for a gang of ONE it must give the same answer as
##    `AiPlayer._dies_to`, which is the predicate the rest of the combat
##    maths shares. That is checked pair by pair over a board built to
##    contain the awkward cases: first strike, protection, a regenerator,
##    a trampler, a wall.
## 2. **The boards, not the win rate** — the shape the attack audit's own
##    file uses. Two 2/2s really do kill a 4/4 and lose one of them; the
##    damage order really is the one `AiPlayer.order_blockers` announces;
##    and the search, which now knows we can gang-block their counter-
##    swing, keeps an attacker home in the position where the flat model
##    thought we were dead and holds one back in the position where we
##    genuinely are.

const OURS := 0
const THEIRS := 1


func _ai(pid: int) -> AiPlayer:
	var ai := AiPlayer.new(pid, AiProfile.wizard())
	g.agents[pid] = ai
	return ai


## Build the flat model the search runs over, from the live board.
func _model(ai: AiPlayer, mine: Array[CardInstance],
		theirs: Array[CardInstance]) -> CombatSearch:
	return ai._build_combat_model(g, mine, theirs, mine, THEIRS)


func _mine() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[OURS].battlefield:
		if inst.is_creature():
			out.append(inst)
	return out


func _theirs() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[THEIRS].battlefield:
		if inst.is_creature():
			out.append(inst)
	return out


# ------------------------------------- 1. the arithmetic is the engine's --

func test_a_gang_of_one_answers_exactly_what_dies_to_answers() -> void:
	# THE PIN that keeps this from being a second rules model. Every
	# awkward shape in one board: first strike both ways, protection from
	# a colour, a regenerator with its mana open, a trampler, a wall
	# nothing can kill, and a plain body.
	put_battlefield(OURS, "White Knight")        # 2/2 first strike, pro-black
	put_battlefield(OURS, "Craw Wurm")           # 6/4
	put_battlefield(OURS, "Drudge Skeletons")    # 1/1 regenerator
	put_battlefield(OURS, "Swamp")               # ...and the mana for it
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(THEIRS, "Erg Raiders")       # 2/2 black
	put_battlefield(THEIRS, "Wall of Stone")     # 0/8
	put_battlefield(THEIRS, "Hill Giant")
	put_battlefield(THEIRS, "White Knight")
	var ai := _ai(OURS)
	var mine := _mine()
	var theirs := _theirs()
	var m := _model(ai, mine, theirs)
	var checked := 0
	for a in mine.size():
		for d in theirs.size():
			var solo: Array[int] = [d]
			var ours_attacking := m.resolve_block(a, solo, true)
			assert_eq(bool(ours_attacking[0]),
				m.they_kill[a * theirs.size() + d] != 0,
				"our %s attacking into their %s: attacker's fate" % [
					mine[a].data.card_name, theirs[d].data.card_name])
			assert_eq((int(ours_attacking[1]) & (1 << d)) != 0,
				m.we_kill[a * theirs.size() + d] != 0,
				"our %s attacking into their %s: blocker's fate" % [
					mine[a].data.card_name, theirs[d].data.card_name])
			var solo_ours: Array[int] = [a]
			var theirs_attacking := m.resolve_block(d, solo_ours, false)
			assert_eq(bool(theirs_attacking[0]),
				m.we_kill[a * theirs.size() + d] != 0,
				"their %s attacking into our %s: attacker's fate" % [
					theirs[d].data.card_name, mine[a].data.card_name])
			assert_eq((int(theirs_attacking[1]) & (1 << a)) != 0,
				m.they_kill[a * theirs.size() + d] != 0,
				"their %s attacking into our %s: blocker's fate" % [
					theirs[d].data.card_name, mine[a].data.card_name])
			checked += 1
	assert_eq(checked, mine.size() * theirs.size(), "every pair was asked")


func test_two_small_bodies_kill_a_big_one_and_only_one_of_them_dies() -> void:
	# The whole point of a gang block, and the thing the flat model could
	# not see: a 3/3 that eats either 2/2 on its own dies to both, and its
	# three damage is only lethal to one of them.
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(THEIRS, "Hill Giant")        # 3/3
	var ai := _ai(OURS)
	var mine := _mine()
	var theirs := _theirs()
	var m := _model(ai, mine, theirs)
	var pair: Array[int] = [0, 1]
	var outcome := m.resolve_block(0, pair, false)   # their giant, our two bears
	assert_true(bool(outcome[0]), "two bears kill the 3/3")
	var dead: int = outcome[1]
	assert_eq(dead & 1, 1, "the first bear in the damage order dies")
	assert_eq(dead & 2, 0, "the second one does not — 3 power kills one 2/2")
	assert_eq(int(outcome[2]), 0, "no trample, nothing to the face")


func test_the_damage_order_is_the_one_order_blockers_announces() -> void:
	# CR 509.2: the ATTACKING player announces the order, and
	# `AiPlayer.order_blockers` picks the max-worth subset that fits inside
	# the damage on offer. Three power against a 1/1 and a 2/2 kills the
	# 2/2 — the worthier body — not the pair.
	put_battlefield(OURS, "Drudge Skeletons")    # 1/1, and NO mana to regenerate
	put_battlefield(OURS, "Hypnotic Specter")    # 2/2
	put_battlefield(THEIRS, "Erg Raiders")       # 2/2 — two power, three to spend on
	var ai := _ai(OURS)
	var mine := _mine()
	var theirs := _theirs()
	var m := _model(ai, mine, theirs)
	var gang: Array[int] = [0, 1]
	var outcome := m.resolve_block(0, gang, false)
	var dead: int = outcome[1]
	assert_eq(dead & 2, 2, "the Specter is what the two damage is spent on")
	assert_eq(dead & 1, 0, "the Skeletons survive — the order is not declaration order")


func test_a_trampler_gets_less_past_two_blockers_than_past_one() -> void:
	# CR 702.19b: the spill is what is left after EVERY blocker has been
	# assigned lethal damage, so a second body soaks its own toughness.
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(THEIRS, "Craw Wurm")
	var tramples: Array[int] = [Mtg.Keyword.TRAMPLE]
	g.continuous.add_until_eot_pump(
		g.find_on_battlefield(THEIRS, "Craw Wurm").id, 0, 0, tramples)
	g.recalculate()
	var ai := _ai(OURS)
	var mine := _mine()
	var theirs := _theirs()
	var m := _model(ai, mine, theirs)
	var one: Array[int] = [0]
	var two: Array[int] = [0, 1]
	assert_eq(int(m.resolve_block(0, one, false)[2]), 4,
		"6 power past one 2/2 is 4 to the face")
	assert_eq(int(m.resolve_block(0, two, false)[2]), 2,
		"past two of them it is 2")


func test_first_strike_inside_a_gang_is_decided_by_the_assignment() -> void:
	# The reason `_damage_from` had to be split. A 3/3 first striker facing
	# two 2/2s kills ONE of them before it strikes and takes the other's
	# two damage — the pair predicate, which asks whether the attacker's
	# whole power reaches a blocker, cannot express that.
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	var ai := _ai(OURS)
	var mine := _mine()
	var attacker := put_battlefield(THEIRS, "Grizzly Bears")
	var strikes_first: Array[int] = [Mtg.Keyword.FIRST_STRIKE]
	g.continuous.add_until_eot_pump(attacker.id, 1, 1, strikes_first)
	g.recalculate()
	assert_eq(attacker.cur_power, 3)
	assert_true(attacker.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	var theirs: Array[CardInstance] = [attacker]
	var m := _model(ai, mine, theirs)
	var pair: Array[int] = [0, 1]
	var outcome := m.resolve_block(0, pair, false)
	assert_eq(int(outcome[1]), 1, "the first bear in the order dies to first strike")
	assert_false(bool(outcome[0]),
		"and only the surviving bear strikes back, which is 2 into a 3/3")


# ---------------------------------------- 2. what the search does with it --

func _search_for(chosen: Array) -> Array:
	var ai := _ai(OURS)
	var candidates: Array[CardInstance] = []
	for inst in g.players[OURS].battlefield:
		if inst.is_creature() and not inst.tapped and not inst.summoning_sick:
			candidates.append(inst)
	return ai._search_hold_back(g, candidates, chosen, THEIRS)


func test_the_search_knows_two_bodies_can_hold_the_counter_swing() -> void:
	# THE BOARD THE WIDENING IS FOR, and it is a board the flat model gets
	# exactly backwards. At 3 life, facing a TAPPED 6/4 trampler, we have
	# three 2/2s and nothing they control can block. One blocker leaves 4
	# trampling through, which is lethal — so under one-blocker-per-
	# attacker EVERY line loses the game, the search finds no move better
	# than any other, and its tie-break sends the whole team. TWO blockers
	# soak four of the six: hold two home and we live at 1 with their Wurm
	# dead, so exactly one bear may attack.
	g.players[OURS].life = 3
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	var wurm := put_battlefield(THEIRS, "Craw Wurm")
	var tramples: Array[int] = [Mtg.Keyword.TRAMPLE]
	g.continuous.add_until_eot_pump(wurm.id, 0, 0, tramples)
	g.recalculate()
	g.tap_permanent(wurm)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var all_three: Array = []
	for inst in _mine():
		all_three.append(inst.id)
	assert_eq(_search_for(all_three).size(), 1,
		"one attacks and two stay home to gang the Wurm")
	# ...and the BEFORE, stated on the same board and the same model.
	var ai := _ai(OURS)
	var mine := _mine()
	var flat := _model(ai, mine, _theirs())
	flat.budget = AiProfile.wizard().combat_search_nodes
	flat.gang_defence = false
	assert_eq(flat.best_attack(0b111), 0b111,
		"one blocker per attacker: every line loses, so the tie sends all three")


func test_the_search_still_holds_the_body_a_gang_cannot_save() -> void:
	# The gate the widening must not break: one 3/3 at 3 life against a
	# tapped Craw Wurm is the board the crack-back search was built for,
	# and there is no second body to gang with.
	g.players[OURS].life = 3
	put_battlefield(OURS, "Hill Giant")
	var wurm := put_battlefield(THEIRS, "Craw Wurm")
	g.tap_permanent(wurm)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var giant := g.find_on_battlefield(OURS, "Hill Giant")
	assert_eq(_search_for([giant.id]), [],
		"the one body stays home: nothing can block the Wurm if it goes")


func test_the_widening_is_a_field_so_the_before_can_still_be_stated() -> void:
	# `gang_defence` is what let the Deck Lab run a null arm of the SHIPPED
	# model against this one on the same seed, and what lets the test above
	# state the before and the after on one board.
	var ai := _ai(OURS)
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(OURS, "Grizzly Bears")
	put_battlefield(THEIRS, "Grizzly Bears")
	var m := _model(ai, _mine(), _theirs())
	assert_true(m.gang_defence, "our blocks gang by default")
	var legal: Array[int] = [0, 1]
	assert_eq(m._gangs_of(legal).size(), 3,
		"two bodies, three declarations: each alone and both together")
	m.gang_defence = false
	assert_eq(m._gangs_of(legal).size(), 2,
		"with the field off the move list is one blocker per attacker")


func test_the_forward_combat_is_still_one_blocker_per_attacker() -> void:
	# The half that was measured and NOT kept, stated where a reader can
	# see it: three untapped 2/2s could gang our 6/4 and kill it for one
	# body, and the AI sends it anyway, because its reading of THEIR
	# answer to OUR attack is still one blocker per attacker
	# (`_attack_risk` / `_cohort_value`, and ply 2 of the search). When
	# that half is lifted this test is what should fail.
	var ai := _ai(OURS)
	g.agents[THEIRS] = AiPlayer.new(THEIRS, AiProfile.wizard())
	put_battlefield(OURS, "Craw Wurm")
	for _i in 3:
		put_battlefield(THEIRS, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_eq(g.combat.attackers.size(), 1,
		"the Wurm swings into three bodies that could kill it between them")
