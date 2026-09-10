extends GameTest
## A SUB-LETHAL CRACK-BACK GATE (2026-09-10, [member
## AiProfile.crack_back_margin]; `docs/forge/combat.md` P8).
##
## [method AiPlayer._search_hold_back] ran only when `reach >= life`, so
## the crack-back search was asked exactly one question — *does this
## attack LOSE THE GAME to the counter-swing?* — and never the other one:
## does it cost us twelve life for four points of damage. Reproduced
## before a line was written, our Air Elemental against two Craw Wurms at
## 14 life (their reach 12, one short of the old gate):
##
##     null      -> attacks ["Air Elemental"]
##     margin 6  -> attacks []
##
## The null sends a 4/4 they cannot block, takes twelve back with nothing
## left untapped to block with, and ends the turn at 2 life; holding it
## home blocks a Craw Wurm, kills it, and ends the turn at 8.
##
## The change is THE GATE AND NOTHING ELSE — the search that runs is the
## same search, and it has priced life since it was built ([method
## CombatSearch._fdv]).
##
## AND THE LAB REFUSED THE RUNG P8 ASKED FOR, which is why every preset
## ships 0 (`docs/ai-difficulty.md` §4): twenty arms at 0/6/10, seed 11,
## control PASS byte-identical in all of them, not one delta clear of its
## interval, the flips a coin — and the one systematic movement is a green
## deck that stops attacking into a deck it cannot block. The field stays
## so the question is one Deck Lab command, the way [member
## AiProfile.w_hand] stayed. The tests below therefore pin the MECHANISM
## at 6 and the SHIPPED value at 0.


func _ai(margin: int, seat := 0) -> AiPlayer:
	var profile := AiProfile.wizard()
	profile.crack_back_margin = margin
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _bodies(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for n in names:
		out.append(put_battlefield(pid, n))
	return out


## The declaration [method AiPlayer._attack_choice] makes, as card names.
func _attacks(ai: AiPlayer, mine: Array[CardInstance]) -> Array:
	var names: Array = []
	for id in ai._attack_choice(g, mine, 1):
		names.append(g.find_instance(int(id)).data.card_name)
	names.sort()
	return names


## Their whole board's power, which is what the gate is read against.
func _reach() -> int:
	var reach := 0
	for inst in g.players[1].battlefield:
		if inst.is_creature() and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			reach += maxi(inst.cur_power, 0)
	return reach


# --------------------------------------------------- the reproduction --

func test_the_gate_opens_below_lethal() -> void:
	var ai := _ai(6)
	var mine := _bodies(0, ["Air Elemental"])
	_bodies(1, ["Craw Wurm", "Craw Wurm"])
	g.players[0].life = 14
	assert_eq(_reach(), 12, "one short of the old gate")
	assert_eq(_attacks(ai, mine), [],
		"twelve life for four damage is not a swing worth making")


func test_the_null_sends_it_anyway() -> void:
	var ai := _ai(0)
	var mine := _bodies(0, ["Air Elemental"])
	_bodies(1, ["Craw Wurm", "Craw Wurm"])
	g.players[0].life = 14
	assert_eq(_reach(), 12)
	assert_eq(_attacks(ai, mine), ["Air Elemental"],
		"the search is never asked, because the swing does not lose the game")


func test_above_the_margin_the_two_arms_agree() -> void:
	# Twenty life against a reach of twelve: `20 - 6` is still above it,
	# so the gate stays shut at the Wizard's own number too and the
	# declaration is the one the cohort made.
	for margin in [0, 6]:
		before_each()
		var ai := _ai(margin)
		var mine := _bodies(0, ["Air Elemental"])
		_bodies(1, ["Craw Wurm", "Craw Wurm"])
		assert_eq(g.players[0].life, 20)
		assert_eq(_reach(), 12)
		assert_eq(_attacks(ai, mine), ["Air Elemental"],
			"margin %d" % margin)


func test_at_lethal_reach_the_gate_was_always_open() -> void:
	# The exact gate still holds where it always held: both arms run the
	# same search on the same board and get the same answer.
	for margin in [0, 6]:
		before_each()
		var ai := _ai(margin)
		var mine := _bodies(0, ["Air Elemental"])
		_bodies(1, ["Craw Wurm", "Craw Wurm"])
		g.players[0].life = 12
		assert_true(_reach() >= g.players[0].life, "lethal on the table")
		assert_eq(_attacks(ai, mine), [], "margin %d" % margin)


func test_the_search_is_what_answers_and_it_can_still_say_attack() -> void:
	# The knob widens the QUESTION, it does not answer it. On a board
	# where the swing pays, the search opened by the margin sends the body
	# anyway — which is the difference from the two brakes this replaces.
	for margin in [0, 6]:
		before_each()
		var ai := _ai(margin)
		var mine := _bodies(0, ["Serra Angel", "Hill Giant"])
		_bodies(1, ["Craw Wurm", "Craw Wurm"])
		g.players[0].life = 12
		assert_eq(_attacks(ai, mine), ["Serra Angel"], "margin %d" % margin)


# ------------------------------------------------- the gate is the change --

func test_the_gate_is_the_only_line_that_moved() -> void:
	# A board with no creature of theirs at all: the reach is zero, the
	# gate is shut at every margin, and the search never runs.
	for margin in [0, 6, 10]:
		before_each()
		var ai := _ai(margin)
		var mine := _bodies(0, ["Grizzly Bears"])
		assert_eq(_reach(), 0)
		assert_eq(_attacks(ai, mine), ["Grizzly Bears"], "margin %d" % margin)


func test_below_the_sorcerer_the_number_is_inert() -> void:
	# [member AiProfile.combat_search_nodes] is 0 at the bottom two rungs,
	# so the search returns before the gate is read at all.
	for margin in [0, 6, 10]:
		before_each()
		var profile := AiProfile.magician()
		profile.mistake_chance = 0.0
		profile.crack_back_margin = margin
		var ai := AiPlayer.new(0, profile)
		g.set_agent(0, ai)
		var mine := _bodies(0, ["Air Elemental"])
		_bodies(1, ["Craw Wurm", "Craw Wurm"])
		g.players[0].life = 14
		assert_eq(_attacks(ai, mine), ["Air Elemental"], "margin %d" % margin)


# ---------------------------------------------------- the knob is a number --

func test_the_knob_is_an_int_and_reads_off_the_profile_by_name() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.crack_back_margin, 0, "the shipped gate")
	assert_eq(profile.apply_overrides("crack_back_margin=10"), "")
	assert_eq(profile.crack_back_margin, 10)
	assert_eq(profile.apply_overrides("crack_back_margin=6"), "")
	assert_eq(profile.crack_back_margin, 6)
	assert_eq(profile.apply_overrides("crack_back_margin=0"), "")
	assert_eq(profile.crack_back_margin, 0, "and 0 is today's gate")


func test_the_rungs_are_all_the_null() -> void:
	# `docs/forge/combat.md` P8 asked for the Wizard at
	# [member AiProfile.chump_threshold]'s 6, and the Lab refused it —
	# twenty arms, not one delta clear of its interval, and the flips a
	# coin (`docs/ai-difficulty.md` §4). So every preset ships today's
	# gate and the field stays for the sweep, the way
	# [member AiProfile.w_hand] did.
	assert_eq(AiProfile.apprentice().crack_back_margin, 0)
	assert_eq(AiProfile.magician().crack_back_margin, 0)
	assert_eq(AiProfile.sorcerer().crack_back_margin, 0)
	assert_eq(AiProfile.wizard().crack_back_margin, 0)


func test_the_shipped_pilot_is_the_pilot_that_was() -> void:
	# The null proved on the board the knob turns: at the shipped number
	# the reproduction reads exactly as it read before this landed.
	var ai := _ai(AiProfile.wizard().crack_back_margin)
	var mine := _bodies(0, ["Air Elemental"])
	_bodies(1, ["Craw Wurm", "Craw Wurm"])
	g.players[0].life = 14
	assert_eq(_attacks(ai, mine), ["Air Elemental"])
