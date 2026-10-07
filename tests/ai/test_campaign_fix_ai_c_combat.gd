extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-c — combat prices (engine/ai/ai_player.gd;
## [member AiProfile.forecasts_tactics]):
##  * w6-7 a blocker that pays for blocking at all ([member
##    CardData.combat_price]: Time Elemental is sacrificed and deals five to
##    us) blocks only when the block is what keeps us alive;
##  * w2-4 a granted FIRST STRIKE is priced like a pump: the Knight of
##    Stromgald's {B} turns a Bears trade into a free kill;
##  * w1-7 a body a table static makes a 0/x the moment it attacks
##    (Weakstone's "Attacking creatures get -1/-0.") is no attacker — the
##    Prodigal Sorcerer pings instead.
## Each with a positive control, a null arm (the gate off) and a
## hidden-information permutation.

var _packs: Array = []


func after_each() -> void:
	g = null
	for id in _packs:
		CardPacks.set_enabled(id, false)
	_packs = []


func _with_packs(ids: Array) -> void:
	for id in ids:
		CardPacks.set_enabled(id, true)
		_packs.append(id)
	before_each()


func _profile(base: AiProfile, on := true) -> AiProfile:
	base.mistake_chance = 0.0
	base.forecasts_tactics = on
	return base


func _ai(seat: int, p: AiProfile) -> AiPlayer:
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


# --------------------------------------------- w6-7: the Time Elemental --

## Seat 0 attacks with [param attacker_ids]; seat 1 ([param ai]) is asked
## for its blocks. Returns whether [param blocker] blocked.
func _block_with(ai: AiPlayer, attacker_ids: Array, blocker: CardInstance) -> bool:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_blockers)
	ai.act(g)
	return g.combat.blocks.has(blocker.id)


func test_no_time_elemental_block_for_one_point() -> void:
	for base in [AiProfile.wizard(), AiProfile.apprentice()]:
		before_each()
		var ai := _ai(1, _profile(base))
		var elemental := put_battlefield(1, "Time Elemental")
		var elves := put_battlefield(0, "Llanowar Elves")
		assert_false(_block_with(ai, [elves.id], elemental),
			"%s: the Elemental and five life for one point" % base.profile_name)


func test_the_time_elemental_blocks_when_it_is_the_only_way_to_live() -> void:
	# Six coming at six life: unblocked it is the game; blocked, five from
	# the Elemental leaves one.
	var ai := _ai(1, _profile(AiProfile.wizard()))
	g.players[1].life = 6
	var elemental := put_battlefield(1, "Time Elemental")
	var wurm := put_battlefield(0, "Craw Wurm")
	assert_true(_block_with(ai, [wurm.id], elemental))


func test_no_time_elemental_block_that_dies_to_the_price_anyway() -> void:
	# At four, six through kills us and the block's five kills us too.
	var ai := _ai(1, _profile(AiProfile.wizard()))
	g.players[1].life = 4
	var elemental := put_battlefield(1, "Time Elemental")
	var wurm := put_battlefield(0, "Craw Wurm")
	assert_false(_block_with(ai, [wurm.id], elemental))


func test_the_price_is_declared_on_the_card() -> void:
	var data := CardRegistry.get_card("Time Elemental")
	assert_eq(data.combat_price, {"sacrifice": true, "life": 5})
	assert_true(CardRegistry.get_card("Grizzly Bears").combat_price.is_empty())


func test_null_arm_blocks_the_one_point() -> void:
	var ai := _ai(1, _profile(AiProfile.wizard(), false))
	var elemental := put_battlefield(1, "Time Elemental")
	var elves := put_battlefield(0, "Llanowar Elves")
	assert_true(_block_with(ai, [elves.id], elemental), "gate off: the old free absorb")


func test_the_elemental_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(1, _profile(AiProfile.wizard()))
		var elemental := put_battlefield(1, "Time Elemental")
		var elves := put_battlefield(0, "Llanowar Elves")
		give_hand(0, "Giant Growth" if variant == 0 else "Lightning Bolt")
		if variant == 1: g.players[0].library.reverse()
		answers.append(_block_with(ai, [elves.id], elemental))
	assert_eq(answers[0], answers[1])


# -------------------------------------------- w2-4: the bought first strike --

func _knight_combat(ai: AiPlayer, blocker_name: String, swamps := 1) -> Array:
	var knight := put_battlefield(0, "Knight of Stromgald")
	var blocker := put_battlefield(1, blocker_name)
	for k in swamps:
		put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [knight.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: knight.id}))
	var guard := 0
	while g.current_step() == Mtg.Step.DECLARE_BLOCKERS and guard < 10:
		if g.priority_player == 0:
			if ai.act(g) == "":
				g.pass_priority(0)
		else:
			g.pass_priority(1)
		guard += 1
	advance_to_step(Mtg.Step.COMBAT_END)
	return [knight, blocker]


func test_the_knight_buys_first_strike_to_live() -> void:
	_with_packs(["pack-3"])
	var p := _profile(AiProfile.wizard())
	p.develops_late = false
	var ai := _ai(0, p)
	var pair := _knight_combat(ai, "Grizzly Bears")
	assert_eq(pair[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(pair[0].zone, Mtg.Zone.BATTLEFIELD, "{B}: first strike — the Bears die before they hit")


func test_no_first_strike_bought_against_a_first_striker() -> void:
	# Black Knight strikes first too: the {B} saves nothing, and the Swamp
	# is not spent on it.
	_with_packs(["pack-3"])
	var p := _profile(AiProfile.wizard())
	p.develops_late = false
	var ai := _ai(0, p)
	var swamp_count := 1
	_knight_combat(ai, "Black Knight", swamp_count)
	var swamp_tapped := false
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Swamp" and inst.tapped:
			swamp_tapped = true
	assert_false(swamp_tapped, "first strike against a first striker is no first strike")


func test_null_arm_trades_the_knight() -> void:
	_with_packs(["pack-3"])
	var p := _profile(AiProfile.wizard(), false)
	p.develops_late = false
	var ai := _ai(0, p)
	var pair := _knight_combat(ai, "Grizzly Bears")
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD, "gate off: P/T pumps only")


func test_the_first_strike_answer_ignores_their_hidden_cards() -> void:
	_with_packs(["pack-3"])
	var answers: Array = []
	for variant in 2:
		before_each()
		var p := _profile(AiProfile.wizard())
		p.develops_late = false
		var ai := _ai(0, p)
		give_hand(1, "Giant Growth" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		var pair := _knight_combat(ai, "Grizzly Bears")
		answers.append([pair[0].zone, pair[1].zone])
	assert_eq(answers[0], answers[1])


# ---------------------------------------------- w1-7: attacking for nothing --

func test_a_sorcerer_under_our_weakstone_pings_instead_of_attacking() -> void:
	var ai := _ai(1, _profile(AiProfile.wizard()))
	put_battlefield(1, "Weakstone")
	put_battlefield(1, "Prodigal Sorcerer")
	put_battlefield(1, "Island")
	put_battlefield(0, "Forest")
	var guard := 0
	while not g.game_over and guard < 800 and not (g.active_player == 1
			and g.turn_number > 1 and g.current_step() == Mtg.Step.END):
		if g.priority_player == 1 or (g.awaiting_attackers and g.active_player == 1):
			var did := ai.act(g)
			if did != "" and did != "pass":
				guard += 1
				continue
		_advance_once()
		guard += 1
	var attacked := false
	for line in g.log_lines:
		attacked = attacked or (line.contains("attacks with") and line.contains("Prodigal Sorcerer"))
	assert_false(attacked, "a 0/1 attacker deals nothing and gives up the ping")
	assert_eq(g.players[0].life, 19, "the Sorcerer's {T} dealt the 1")


func test_the_attacking_power_reading() -> void:
	var ai := _ai(0, _profile(AiProfile.wizard()))
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_false(ai._attacks_for_nothing(g, sorcerer), "no Weakstone: a 1/1 attacker")
	put_battlefield(1, "Weakstone")   # theirs: it shrinks every attacker
	g.recalculate()
	assert_eq(ai._attacking_power_shift(g, sorcerer), -1)
	assert_true(ai._attacks_for_nothing(g, sorcerer))
	assert_false(ai._attacks_for_nothing(g, bears), "a 2/2 still hits for one")


func test_null_arm_swings_the_sorcerer_for_nothing() -> void:
	var ai := _ai(0, _profile(AiProfile.wizard(), false))
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	put_battlefield(0, "Weakstone")
	g.recalculate()
	assert_false(ai._attacks_for_nothing(g, sorcerer), "gate off: the old reading")


func test_the_zero_attack_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(0, _profile(AiProfile.wizard()))
		var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
		put_battlefield(0, "Weakstone")
		give_hand(1, "Lightning Bolt" if variant == 0 else "Fog")
		if variant == 1: g.players[1].library.reverse()
		g.recalculate()
		answers.append(ai._attacks_for_nothing(g, sorcerer))
	assert_eq(answers[0], answers[1])
