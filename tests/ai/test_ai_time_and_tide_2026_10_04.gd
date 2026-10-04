extends GameTest
## TIME AND TIDE, COUNTED FOR WHAT IT CHANGES (0.50.13 playtest, 2026-10-04;
## [member AiProfile.forecasts_tactics]). "Simultaneously, all phased-out
## creatures phase in and all creatures with phasing phase out."
##
## The finding: the Wizard cast Time and Tide twice in one game to bring
## back its OWN phased-out creatures — Merfolk Raiders and a Rainbow Efreet
## wearing Cloak of Invisibility, both of which had attacked and so phased
## out TAPPED at its untap step. They came back tapped (no blocks), and at
## its next untap step they phased out again: the card bought nothing, and
## worse, the two bodies that would have come back untapped at that step
## were gone for another cycle. The old price (mirage_tactics.gd
## `phase_swap_value`) added every returning body's whole worth.
##
## The honest count ([method MirageTactics.phase_swap_value]): this turn's
## combat read on the board the swap leaves (run under the search journal
## and put back), and each body that changes counted over the next three
## combats — present AND untapped, with its controller's untap steps
## phasing it out or in again — before against after. These pins:
##  * the playtest board is refused (and the Pack 8 duel audit's own case:
##    our tapped phaser in, our untapped attacker out, their phaser out);
##  * their phasing blockers phased out before our lethal attack is still
##    cast, and the attack then wins;
##  * their lethal phasing attack is answered in their declare-attackers
##    step ([method MirageTactics.phase_swap_response]) — and the same
##    attack at twenty life is not: a Fog that hands them their next
##    attack back is no trade;
##  * hidden information (their hand, both libraries) moves nothing.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


## Pass (declaring nothing) until [param seat]'s [param step].
func _to(seat: int, step: int) -> void:
	var guard := 0
	while not (g.active_player == seat and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Let [param ai] act in our main phase until it passes or does nothing.
func _drive(ai: AiPlayer, n := 8) -> Array:
	var acted := []
	for _i in n:
		var line := ai.act(g)
		acted.append(line)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break
	return acted


## Play the rest of this turn: [param ai] acts whenever it is its moment,
## the other seat passes and declares nothing.
func _play_turn(ai: AiPlayer) -> void:
	var turn := g.turn_number
	var guard := 0
	while not g.game_over and g.turn_number == turn and guard < 300:
		guard += 1
		if ai.act(g) == "":
			_advance_once()
	assert_lt(guard, 300)


func _cast(acted: Array) -> bool:
	for line in acted:
		if String(line).contains("Time and Tide"):
			return true
	return false


## THE PLAYTEST BOARD. Our Merfolk Raiders and our Cloaked Rainbow Efreet
## attacked last turn; at our untap step they phased out still TAPPED.
## Our first main phase, Time and Tide in hand with the mana for it.
func _wasted_board(variant := 0) -> Dictionary:
	_to(1, Mtg.Step.MAIN1)
	var raiders := put_battlefield(0, "Merfolk Raiders")
	var efreet := put_battlefield(0, "Rainbow Efreet")
	g.attach_aura_from_anywhere(give_hand(0, "Cloak of Invisibility"), efreet, 0)
	g.tap_permanent(raiders)
	g.tap_permanent(efreet)
	put_battlefield(1, "Hill Giant")
	give_hand(1, "Giant Growth" if variant == 0 else "Terror")
	if variant == 1:
		g.players[0].library.reverse()
		g.players[1].library.reverse()
	_to(0, Mtg.Step.MAIN1)
	assert_true(raiders.phased_out and raiders.tapped, "phased out tapped at our untap step")
	assert_true(efreet.phased_out and efreet.tapped, "the Cloak's phasing took it out tapped")
	for _i in 4: put_battlefield(0, "Island")
	var tide := give_hand(0, "Time and Tide")
	return {"tide": tide, "raiders": raiders, "efreet": efreet}


func test_the_playtest_rescue_is_refused() -> void:
	var ai := _ai()
	var board := _wasted_board()
	var acted := _drive(ai)
	assert_false(_cast(acted), "tapped phasers phased in only to phase out again: %s" % [acted])
	assert_eq((board["tide"] as CardInstance).zone, Mtg.Zone.HAND)
	assert_true((board["raiders"] as CardInstance).phased_out,
		"they come back UNTAPPED at our next untap step on their own")
	assert_lt(M.phase_swap_value(g, ai), 0.0, "the swap loses them a whole cycle")


## The Pack 8 duel audit's own cast (seed 87000, fifth edition, turn 18):
## our Merfolk Raiders phased out tapped, our untapped Tolarian Drake about
## to attack, their Bloodrock-sized phaser present. The swap took the
## Drake's attack, brought the Raiders back tapped and gave them their
## phaser for their next attack.
func test_the_audit_case_is_refused() -> void:
	var ai := _ai()
	_to(1, Mtg.Step.MAIN1)
	var raiders := put_battlefield(0, "Merfolk Raiders")
	g.tap_permanent(raiders)
	_to(0, Mtg.Step.MAIN1)
	assert_true(raiders.phased_out and raiders.tapped)
	var drake := put_battlefield(0, "Tolarian Drake")
	var theirs := put_battlefield(1, "Hill Giant")
	g.attach_aura_from_anywhere(give_hand(1, "Cloak of Invisibility"), theirs, 1)
	put_battlefield(1, "Grizzly Bears")
	for _i in 4: put_battlefield(0, "Island")
	var tide := give_hand(0, "Time and Tide")
	var acted := _drive(ai)
	assert_false(_cast(acted), "%s" % [acted])
	assert_eq(tide.zone, Mtg.Zone.HAND)
	assert_false(drake.phased_out)


## THE GOOD CASE: their two phasing blockers are all that stands between
## our attack and their last five life. Phased out, the attack is lethal.
func _lethal_board(variant := 0, their_life := 5, tapped := false) -> Dictionary:
	_to(1, Mtg.Step.MAIN1)
	_to(0, Mtg.Step.MAIN1)
	put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Merfolk Raiders")
	var b := put_battlefield(1, "Merfolk Raiders")
	if tapped:
		g.tap_permanent(a)
		g.tap_permanent(b)
	g.players[1].life = their_life
	give_hand(1, "Giant Growth" if variant == 0 else "Terror")
	if variant == 1:
		g.players[0].library.reverse()
		g.players[1].library.reverse()
	for _i in 2: put_battlefield(0, "Island")
	var tide := give_hand(0, "Time and Tide")
	return {"tide": tide, "blockers": [a, b]}


func test_their_phasing_blockers_go_before_our_lethal_attack() -> void:
	var ai := _ai()
	var board := _lethal_board()
	assert_gt(M.phase_swap_value(g, ai), 100.0, "the attack it opens is the game")
	var acted := _drive(ai)
	assert_true(_cast(acted), "%s" % [acted])
	for blocker in board["blockers"]:
		assert_true((blocker as CardInstance).phased_out)
	_play_turn(ai)
	assert_true(g.game_over, "the attack went through")
	assert_eq(g.winner, 0)


func test_tapped_blockers_are_not_phased_out_for_nothing() -> void:
	# The public control: the same board with their Raiders already tapped.
	# The attack is lethal without the card, and phasing them out would
	# only bring them back untapped at their own untap step.
	var ai := _ai()
	var board := _lethal_board(0, 5, true)
	var acted := _drive(ai)
	assert_false(_cast(acted), "%s" % [acted])
	assert_eq((board["tide"] as CardInstance).zone, Mtg.Zone.HAND)


## Their two Merfolk Raiders attack; islandwalk makes them unblockable,
## since we control Islands. Seat 0 holds priority before blocks.
func _their_phasing_attack(our_life: int) -> Dictionary:
	var ai := _ai()
	for _i in 2: put_battlefield(0, "Island")
	var tide := give_hand(0, "Time and Tide")
	_to(1, Mtg.Step.UPKEEP)
	var a := put_battlefield(1, "Merfolk Raiders")
	var b := put_battlefield(1, "Merfolk Raiders")
	g.players[0].life = our_life
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [a.id, b.id]))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	return {"ai": ai, "tide": tide, "attackers": [a, b]}


func test_their_lethal_phasing_attack_is_answered() -> void:
	var board := _their_phasing_attack(4)
	var line: String = (board["ai"] as AiPlayer).act(g)
	assert_string_contains(line, "Time and Tide")
	resolve_stack()
	for attacker in board["attackers"]:
		assert_true((attacker as CardInstance).phased_out, "removed from the combat")
	while g.turn_number == 2 and not g.game_over:
		_advance_once()
	assert_false(g.game_over)
	assert_eq(g.players[0].life, 4)


func test_a_survivable_phasing_attack_is_not_fogged() -> void:
	# Four damage at twenty life: phased out now, the Raiders come back
	# untapped at their next untap step and attack then, where they would
	# have phased out — the damage is moved, not stopped.
	var board := _their_phasing_attack(20)
	var line: String = (board["ai"] as AiPlayer).act(g)
	assert_false(line.contains("Time and Tide"), line)
	assert_eq((board["tide"] as CardInstance).zone, Mtg.Zone.HAND)


func test_hidden_information_moves_nothing() -> void:
	# Their hand substituted and both libraries reversed, on the refused
	# board and on the lethal one: the same decision each time.
	var wasted: Array = []
	var lethal: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_wasted_board(variant)
		wasted.append(_cast(_drive(ai)))
		before_each()
		ai = _ai()
		_lethal_board(variant)
		lethal.append(_cast(_drive(ai)))
	assert_eq(wasted[0], wasted[1], "hidden cards changed the refusal")
	assert_eq(lethal[0], lethal[1], "hidden cards changed the cast")
	assert_false(wasted[0])
	assert_true(lethal[0])
