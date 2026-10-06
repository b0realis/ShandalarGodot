extends GameTest
## VOLRATH'S CURSE AND THE HOSTILE LICIDS, PRICED (Pack 9 study fixes,
## 2026-10-06; CR 303.4, 116.2c-d; [member AiProfile.forecasts_tactics];
## engine/ai/mirage_tactics.gd `lock_choice`, engine/ai/tempest_tactics.gd
## `hostile_gain`).
##
## The Deck Lab study found two Auras the fair AI never put down:
##  * VOLRATH'S CURSE was read as a table lock (Null Rod's shape: its
##    activation ban) and a ban that reaches only the creature it enchants
##    stops nothing from the hand — a swing of 0.0 under the lock's bar,
##    so it was never cast. An Aura's ban is not a lock: the Curse falls
##    through to the hostile-Aura reading and goes on their best creature.
##  * A HOSTILE LICID's "can't attack" was one turn of the damage their
##    attack puts through our blocks at our life's price, less half the
##    licid's body: a Calming Licid on a Serra Angel at 20 life priced at
##    exactly 0.0, and a Craw Wurm our Llanowar Elves could only chump
##    read as no threat at all. What the Aura denies is priced now — their
##    attack's worth (the mirror of our own attack reading) and our
##    attack's gain, over the turns the Aura stays — against the body.
## The null arm (gate off) is as it was; the opponent's hidden hand and
## library do not move a decision.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


## Seat 0's AI acts until it passes or [param cap] actions; the lines.
func _turn(ai: AiPlayer, cap := 8) -> Array:
	var lines: Array = []
	for _i in cap:
		var line := ai.act(g)
		lines.append(line)
		if line == "pass" or line == "":
			break
		resolve_stack()
	return lines


# ------------------------------------------------------ Volrath's Curse --

func test_volraths_curse_is_cast_on_their_best_creature() -> void:
	var ai := _ai()
	_lands("Island", 2)
	var curse := give_hand(0, "Volrath's Curse")
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _turn(ai)
	assert_true(lines.has("cast Volrath's Curse"), str(lines))
	assert_eq(curse.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(curse.attached_to, angel.id, "the Curse holds their best creature")


func test_an_auras_ban_is_not_a_table_lock() -> void:
	var ai := _ai()
	var curse := give_hand(0, "Volrath's Curse")
	var lock := give_hand(0, "Hand to Hand")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(M.lock_choice(g, ai, curse), "the host-only ban falls through")
	assert_not_null(M.lock_choice(g, ai, lock), "a table-wide ban is still read as a lock")


func test_the_null_arm_reads_the_curse_as_before() -> void:
	var ai := _ai(false)
	_lands("Island", 2)
	var curse := give_hand(0, "Volrath's Curse")
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(M.spell_choice(g, ai, curse, 0), "the gate keeps the module out")
	_turn(ai)
	assert_eq(curse.zone, Mtg.Zone.BATTLEFIELD, "the shared planner casts it, as it always did")


func test_the_curse_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_lands("Island", 2)
		give_hand(0, "Volrath's Curse")
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Grizzly Bears")
		give_hand(1, "Disenchant" if variant == 0 else "Terror")
		g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(str(_turn(ai)))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")


# ------------------------------------------------------- hostile licids --

## The study's probe board: a Calming Licid beside Grizzly Bears, three
## Plains, their Serra Angel, 20 life each.
func test_calming_licid_grounds_their_angel_at_a_healthy_life() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Grizzly Bears")
	_lands("Plains", 3)
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Calming Licid")
	resolve_stack()
	assert_eq(licid.attached_to, angel.id, "their flier can't attack")


## A Craw Wurm our Llanowar Elves could only chump is a threat all the
## same: the chump is a body, and the Wurm swings every turn.
func test_calming_licid_holds_the_wurm_our_elves_would_chump() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Llanowar Elves")
	_lands("Plains", 3)
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Calming Licid")
	resolve_stack()
	assert_eq(licid.attached_to, wurm.id)


## An even board: their Grizzly Bears is no threat our Bears does not
## answer, and the licid's body is worth more than the Aura.
func test_calming_licid_stays_a_creature_on_an_even_board() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Grizzly Bears")
	_lands("Plains", 3)
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ne(ai.act(g), "activated Calming Licid")
	assert_false(g.is_licid_aura(licid))


func test_the_null_arm_never_hangs_a_hostile_licid() -> void:
	var ai := _ai(false)
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Grizzly Bears")
	_lands("Plains", 3)
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	_turn(ai)
	assert_false(g.is_licid_aura(licid))


func test_the_hostile_licid_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Calming Licid")
		put_battlefield(0, "Grizzly Bears")
		_lands("Plains", 3)
		put_battlefield(1, "Serra Angel")
		give_hand(1, "Disenchant" if variant == 0 else "Giant Growth")
		g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
