extends GameTest
## THE MIRAGE BUG PASS, THE FAIR AI (2026-10-04). One pin per AI finding of
## the read-only hunt over Pack 8, each beside the gate's null arm
## ([member AiProfile.forecasts_tactics] off: the pilot as it was) or an
## unaffected control:
##  * H2-01 Final Fortune is "an extra turn, then lose": the Last Chance
##    role (`extra_turn_then_lose`, portal_tactics.gd) at every rung, and
##    their own Final Fortune is not countered unless the turn kills us.
##  * H2-02 Infernal Contract is Cruel Bargain (`draw_four_half_life`).
##  * H2-03 Reign of Terror prices the 2 life per death and its hint never
##    names the colour that would kill its caster.
##  * H2-07 Waiting in the Weeds counts the Forests left after paying.
##  * H2-08 Tidal Wave's doomed Wall is a surprise blocker, never a
##    main-phase cast; Phyrexian Dreadnought and Zombie Mob are not cast to
##    die on arrival.
##  * H7-F2 the held Spinning Darkness books the row it can pay, or nothing.
##  * H7-F4 Three Wishes is cast in our own main phase, not at their end
##    step where its cards expire unplayed.
##  * H7-F5 an Aura's own -1 toughness is not hung on a 1-toughness body.
##  * H7-F6 Torrent of Lava's X beats the {T} shield it grants.
##  * H7-F7 a modal instant's combat-trick mode never overrides the card's
##    own pick in the main phase.

const M := preload("res://engine/ai/mirage_tactics.gd")
const PT := preload("res://engine/ai/portal_tactics.gd")


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


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


## Let [param ai] act in our main phase until it passes or does nothing.
func _drive(ai: AiPlayer, n := 6) -> Array:
	var acted := []
	for _i in n:
		var line := ai.act(g)
		acted.append(line)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break
	return acted


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## Seat 1 attacks with [param ids]; seat 0 holds priority in declare attackers.
func _they_attack(ids: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)


## Seat 0 casts [param card_name] in its main phase and passes to seat 1.
func _seat0_casts(card_name: String) -> CardInstance:
	var spell := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	var cost := spell.data.cost
	for colour in cost.colored:
		add_mana(0, int(colour), int(cost.colored[colour]))
	if cost.generic > 0:
		add_mana(0, Mtg.ManaColor.C, cost.generic)
	assert_ok(g.cast_spell(0, spell, []))
	assert_ok(g.pass_priority(0))
	return spell


func _count_named(pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name: n += 1
	return n


# ================================================ H2-01 Final Fortune --

func _final_fortune_in_main(profile: AiProfile) -> CardInstance:
	var ai := _ai(profile)
	_lands(0, "Mountain", 2)
	put_battlefield(0, "Grizzly Bears")
	var ff := give_hand(0, "Final Fortune")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	return ff


func test_final_fortune_is_not_a_time_walk_at_any_rung() -> void:
	var presets: Array[AiProfile] = [AiProfile.apprentice(), AiProfile.magician(),
		AiProfile.sorcerer(), AiProfile.wizard()]
	for profile in presets:
		before_each()
		var name := profile.profile_name
		var ff := _final_fortune_in_main(profile)
		assert_eq(ff.zone, Mtg.Zone.HAND,
			"%s: a 2/2 against 20 life buys a turn and then the loss" % name)
		assert_false(g.game_over, name)


func test_final_fortune_waits_at_their_end_step_too() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(0, "Grizzly Bears")
	var ff := give_hand(0, "Final Fortune")
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	assert_eq(ff.zone, Mtg.Zone.HAND)


func test_final_fortune_is_cast_when_the_extra_turn_wins() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	put_battlefield(0, "Grizzly Bears")
	var ff := give_hand(0, "Final Fortune")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	var choice: Variant = PT.spell_choice(g, ai, ff)
	assert_true(choice is Dictionary and not choice.is_empty(),
		"an unblockable 2/2 against 2 life: the extra turn is the game")
	if choice is Dictionary and not choice.is_empty():
		assert_gte(float(choice["value"]), AiPlayer.LETHAL_WORTH * 0.5)


func test_their_final_fortune_is_left_to_lose_them_the_game() -> void:
	for lethal in [false, true]:
		before_each()
		var ai := _ai(AiProfile.wizard(), 1)
		_lands(1, "Island", 8)
		give_hand(1, "Counterspell")
		put_battlefield(0, "Grizzly Bears")
		if lethal:
			g.players[1].life = 2
		_seat0_casts("Final Fortune")
		if lethal:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"their extra turn kills us: countered")
		else:
			assert_eq(ai._try_counter(g), "",
				"their Final Fortune ends in their own loss: a counter would save them")


func test_the_last_turn_read_ignores_their_hidden_cards() -> void:
	# The same public board — a face-down 2/2 — over two different hidden
	# printed cards, and their hand permuted: the counter cannot move.
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(AiProfile.wizard(), 1)
		_lands(1, "Island", 8)
		give_hand(1, "Counterspell")
		var hidden := put_battlefield(0, "Llanowar Elves" if variant == 0 else "Craw Wurm")
		g.turn_face_down(hidden)
		g.players[1].life = 4
		give_hand(0, "Giant Growth" if variant == 0 else "Lightning Bolt")
		_seat0_casts("Final Fortune")
		answers.append(ai._try_counter(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
	assert_string_contains(answers[0], "Counterspell", "a 2/2 twice is our four life")


func test_null_arm_counters_their_final_fortune_as_before() -> void:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	var ai := _ai(p, 1)
	_lands(1, "Island", 8)
	give_hand(1, "Counterspell")
	_seat0_casts("Final Fortune")
	assert_string_contains(ai._try_counter(g), "Counterspell", "the pilot as it was")


func test_a_plain_extra_turn_is_still_countered() -> void:
	var ai := _ai(AiProfile.wizard(), 1)
	_lands(1, "Island", 8)
	give_hand(1, "Counterspell")
	_seat0_casts("Time Walk")
	assert_string_contains(ai._try_counter(g), "Counterspell", "unaffected control")


# ============================================= H2-02 Infernal Contract --

func test_infernal_contract_is_not_cast_into_its_own_life_loss() -> void:
	for life in [1, 4, 9]:
		before_each()
		var ai := _ai()
		_lands(0, "Swamp", 3)
		g.players[0].life = life
		var contract := give_hand(0, "Infernal Contract")
		advance_to_step(Mtg.Step.MAIN1)
		_drive(ai)
		assert_eq(contract.zone, Mtg.Zone.HAND, "at %d life it costs %d" % [life, ceili(life / 2.0)])
		assert_false(g.game_over)


func test_infernal_contract_is_cast_with_life_to_spare() -> void:
	var ai := _ai(AiProfile.magician())
	_lands(0, "Swamp", 3)
	var contract := give_hand(0, "Infernal Contract")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(contract.zone, Mtg.Zone.GRAVEYARD, "four cards for ten of twenty life: Cruel Bargain's rule")
	assert_eq(g.players[0].life, 10)


# ============================================== H2-03 Reign of Terror --

func test_reign_of_terror_is_not_cast_into_its_own_death() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	g.players[0].life = 3
	_lands(1, "Plains", 1)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var reign := give_hand(0, "Reign of Terror")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(reign.zone, Mtg.Zone.HAND, "two deaths cost four of our three life")
	assert_false(g.game_over)


func test_reign_of_terror_names_the_colour_that_does_not_kill_us() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	g.players[0].life = 4
	var bears_a := put_battlefield(1, "Grizzly Bears")
	var bears_b := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var reign := give_hand(0, "Reign of Terror")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(reign.zone, Mtg.Zone.GRAVEYARD, "the Angel is worth the two life")
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears_a.zone, Mtg.Zone.BATTLEFIELD, "green would have been four life: our last")
	assert_eq(bears_b.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 2)
	assert_false(g.game_over)


func test_reign_of_terror_still_sweeps_with_life_to_spare() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 5)
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	var reign := give_hand(0, "Reign of Terror")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(reign.zone, Mtg.Zone.GRAVEYARD, "unaffected control: the sweep is still cast")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 16)


# ========================================== H2-07 Waiting in the Weeds --

func test_waiting_in_the_weeds_is_not_cast_to_feed_them() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	_lands(1, "Forest", 6)
	var weeds := give_hand(0, "Waiting in the Weeds")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(weeds.zone, Mtg.Zone.HAND, "our three Forests pay for it: no cats for us, six for them")


func test_waiting_in_the_weeds_counts_the_forests_left_after_paying() -> void:
	var ai := _ai()
	_lands(0, "Forest", 6)
	_lands(0, "Mountain", 1)
	var weeds := give_hand(0, "Waiting in the Weeds")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(weeds.zone, Mtg.Zone.GRAVEYARD, "Forests to spare and none across the table")
	assert_gte(_count_named(0, "Cat"), 3)
	assert_eq(_count_named(1, "Cat"), 0)


func test_null_arm_casts_waiting_in_the_weeds_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Forest", 3)
	_lands(1, "Forest", 6)
	var weeds := give_hand(0, "Waiting in the Weeds")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(weeds.zone, Mtg.Zone.GRAVEYARD, "the pilot as it was")


# ======================= H2-08 Tidal Wave, Phyrexian Dreadnought, Zombie Mob --

func test_tidal_wave_is_not_cast_in_our_own_main_phase() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wave := give_hand(0, "Tidal Wave")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(wave.zone, Mtg.Zone.HAND, "a Wall that cannot attack and is gone at our end step")


func test_tidal_wave_is_a_surprise_blocker() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wave := give_hand(0, "Tidal Wave")
	var giant := put_battlefield(1, "Hill Giant")
	_they_attack([giant.id])
	assert_string_contains(ai.act(g), "Tidal Wave")
	resolve_stack()
	assert_eq(_count_named(0, "Wall"), 1, "in time to block")
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		if g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	ai.act(g)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the 5/5 Wall blocked and killed the Giant")
	assert_eq(g.players[0].life, 20)


func test_the_wave_ambush_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_lands(0, "Island", 3)
		give_hand(0, "Tidal Wave")
		var giant := put_battlefield(1, "Hill Giant")
		give_hand(1, "Giant Growth" if variant == 0 else "Terror")
		g.players[1].library.reverse()
		_they_attack([giant.id])
		answers.append(ai.act(g).contains("Tidal Wave"))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
	assert_true(answers[0])


func test_tidal_wave_waits_when_no_attack_is_worth_blocking() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wave := give_hand(0, "Tidal Wave")
	var elves := put_battlefield(1, "Llanowar Elves")
	_they_attack([elves.id])
	ai.act(g)
	assert_eq(wave.zone, Mtg.Zone.HAND, "a card for a 1/1 is not worth the Wall")


func test_phyrexian_dreadnought_is_not_cast_to_be_sacrificed() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	var dread := give_hand(0, "Phyrexian Dreadnought")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(dread.zone, Mtg.Zone.HAND, "two power cannot keep it")


func test_zombie_mob_is_not_cast_into_an_empty_graveyard() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	var mob := give_hand(0, "Zombie Mob")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(mob.zone, Mtg.Zone.HAND, "a 2/0 with nothing to count")


func test_zombie_mob_is_cast_onto_its_counters() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	_in_graveyard(0, "Grizzly Bears")
	_in_graveyard(0, "Hill Giant")
	var mob := give_hand(0, "Zombie Mob")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(mob.zone, Mtg.Zone.BATTLEFIELD, "unaffected control: two creature cards make it a 4/2")
	assert_eq(mob.cur_toughness, 2)


func test_arrival_reading_is_card_name_free() -> void:
	var ai := _ai()
	put_battlefield(0, "Grizzly Bears")
	var dread := give_hand(0, "Phyrexian Dreadnought")
	var mob := give_hand(0, "Zombie Mob")
	var bears := give_hand(0, "Grizzly Bears")
	assert_true(M.dies_on_arrival(g, ai, dread))
	assert_true(M.dies_on_arrival(g, ai, mob))
	assert_false(M.dies_on_arrival(g, ai, bears))
	for n in 2: put_battlefield(0, "Craw Wurm")   # 6 + 6 power to give
	assert_false(M.dies_on_arrival(g, ai, dread), "twelve power: the sacrifice is made")
	_in_graveyard(0, "Grizzly Bears")
	assert_false(M.dies_on_arrival(g, ai, mob))


func test_null_arm_casts_the_zombie_mob_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Swamp", 4)
	var mob := give_hand(0, "Zombie Mob")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_ne(mob.zone, Mtg.Zone.HAND, "the pilot as it was: cast...")
	assert_ne(mob.zone, Mtg.Zone.BATTLEFIELD, "...and a 2/0 dies (its own trigger exiles it)")


# ======================================= H7-F2 Spinning Darkness's reserve --

func _darkness_board(tactics := true, with_darkness := true) -> Array:
	var p := AiProfile.wizard()
	p.forecasts_tactics = tactics
	var ai := _ai(p)
	_lands(0, "Swamp", 2)
	_lands(0, "Mountain", 2)
	var python := give_hand(0, "Python")
	if with_darkness: give_hand(0, "Spinning Darkness")
	put_battlefield(1, "Phantom Monster")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	return [ai, python]


func test_an_unpayable_held_darkness_books_nothing() -> void:
	var r := _darkness_board()
	var ai: AiPlayer = r[0]
	assert_true(ai._held_reserve(g).is_empty(),
		"neither {4}{B}{B} from four lands nor three black cards from an empty graveyard")
	assert_string_contains(ai.act(g), "Python")


func test_the_graveyard_row_books_what_it_costs() -> void:
	var r := _darkness_board()
	var ai: AiPlayer = r[0]
	for n in 3: _in_graveyard(0, "Python")
	var reserve := ai._held_reserve(g)
	assert_false(reserve.is_empty(), "the removal still has a job tonight")
	assert_true(ManaPlanner.cost_is_free(reserve["cost"]), "the row costs no mana")
	assert_string_contains(ai.act(g), "Python")


func test_a_payable_printed_row_is_still_booked() -> void:
	var p := AiProfile.wizard()
	var ai := _ai(p)
	_lands(0, "Swamp", 6)
	give_hand(0, "Spinning Darkness")
	put_battlefield(1, "Phantom Monster")
	advance_to_step(Mtg.Step.MAIN1)
	var reserve := ai._held_reserve(g)
	assert_false(reserve.is_empty(), "unaffected control")
	if not reserve.is_empty():
		assert_eq((reserve["cost"] as ManaCost).mana_value(), 6, "the printed {4}{B}{B}")


func test_darkness_controls_cast_the_python() -> void:
	var r := _darkness_board(true, false)
	assert_string_contains((r[0] as AiPlayer).act(g), "Python", "no Darkness in hand")
	before_each()
	r = _darkness_board(false)
	assert_string_contains((r[0] as AiPlayer).act(g), "Python", "null arm: modal, never held")


# ============================================== H7-F4 Three Wishes --

func test_three_wishes_is_not_fired_at_their_end_step() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wishes := give_hand(0, "Three Wishes")
	_their_turn_at(Mtg.Step.END)
	ai.act(g)
	assert_eq(wishes.zone, Mtg.Zone.HAND, "its cards would expire at our upkeep unplayed")
	assert_true(ai._held_reserve(g).is_empty(), "and it books no mana in our turn either")


func test_three_wishes_is_cast_in_our_main_phase_and_played_from() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var wishes := give_hand(0, "Three Wishes")
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	assert_eq(wishes.zone, Mtg.Zone.GRAVEYARD, "cast where its cards can be played")
	assert_eq(_count_named(0, "Forest"), 1, "and the land drop taken from among them")


func test_three_wishes_waits_with_nothing_to_play_them_with() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var island := give_hand(0, "Island")
	var wishes := give_hand(0, "Three Wishes")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, island))
	# Three of four Islands pay for it; one mana and no land drop are left.
	_drive(ai)
	assert_eq(wishes.zone, Mtg.Zone.HAND, "no land drop and one mana left: the cards would expire")


func test_null_arm_holds_three_wishes_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Island", 3)
	var wishes := give_hand(0, "Three Wishes")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Three Wishes", "the pilot as it was")


# ===================================== H7-F5 an Aura's own toughness change --

func test_grave_servitude_is_not_hung_on_a_one_toughness_body() -> void:
	for aura_name in ["Grave Servitude", "Coils of the Medusa"]:
		before_each()
		var ai := _ai()
		_lands(0, "Swamp", 2)
		var elves := put_battlefield(0, "Llanowar Elves")
		var aura := give_hand(0, aura_name)
		put_battlefield(1, "Grizzly Bears")
		advance_to_step(Mtg.Step.MAIN1)
		var targets = ai._choose_targets(g, aura, 0)
		var on_elves := false
		if targets != null:
			for t in targets:
				if t is TargetRef and not t.is_player and t.instance_id == elves.id: on_elves = true
		assert_false(on_elves, "%s on our 1/1 kills it (CR 704.5f)" % aura_name)
		_drive(ai)
		assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, aura_name)


func test_grave_servitude_goes_on_a_body_that_survives_it() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 2)
	put_battlefield(0, "Llanowar Elves")
	var bears := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Grave Servitude")
	advance_to_step(Mtg.Step.MAIN1)
	var targets = ai._choose_targets(g, aura, 0)
	assert_not_null(targets)
	if targets != null:
		assert_eq(targets.size(), 1)
		assert_eq((targets[0] as TargetRef).instance_id, bears.id, "unaffected control: the 2/2 becomes a 5/1")


func test_null_arm_picks_the_aura_host_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Swamp", 2)
	var elves := put_battlefield(0, "Llanowar Elves")
	var aura := give_hand(0, "Grave Servitude")
	advance_to_step(Mtg.Step.MAIN1)
	var targets = ai._choose_targets(g, aura, 0)
	assert_not_null(targets, "the pilot as it was")
	if targets != null:
		assert_eq((targets[0] as TargetRef).instance_id, elves.id)


# ====================================== H7-F6 Torrent of Lava's own shield --

func test_torrent_x_beats_the_shield_it_grants() -> void:
	var ai := _ai()
	var them := _ai(AiProfile.wizard(), 1)
	_lands(0, "Mountain", 6)
	var torrent := give_hand(0, "Torrent of Lava")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	var c := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Torrent of Lava")
	assert_eq((g.stack.back() as StackItem).x_value, 3, "toughness plus the one point each {T} prevents")
	var guard := 0
	while not g.stack.is_empty() and guard < 40:
		var actor := g.priority_player
		(them if actor == 1 else ai).act(g)
		guard += 1
	for body in [a, b, c]:
		assert_eq(body.zone, Mtg.Zone.GRAVEYARD, "%s tapped for its shield and still died" % body.data.card_name)


func test_torrent_x_needs_no_margin_where_no_shield_can_be_tapped() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	give_hand(0, "Torrent of Lava")
	var a := put_battlefield(1, "Llanowar Elves")
	var b := put_battlefield(1, "Llanowar Elves")
	a.tapped = true
	b.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Torrent of Lava")
	assert_eq((g.stack.back() as StackItem).x_value, 1, "unaffected control: tapped bodies cannot pay the {T}")


func test_null_arm_sizes_the_torrent_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Mountain", 6)
	give_hand(0, "Torrent of Lava")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Torrent of Lava")
	assert_eq((g.stack.back() as StackItem).x_value, 2, "the pilot as it was")


# ============================================= H7-F7 Hope Charm's trick mode --

func test_a_trick_mode_does_not_override_the_card_s_pick() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	var lions := put_battlefield(0, "Savannah Lions")
	var charm := give_hand(0, "Hope Charm")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var choice := ai._plan_spell_choice(g, charm, 0)
	assert_true(choice.is_empty() or int(choice["mode"]) != 0,
		"first strike in our first main phase is a trick with no combat to win")
	_drive(ai)
	assert_false(lions.has_keyword(Mtg.Keyword.FIRST_STRIKE), "no first strike spent in main 1")


func test_null_arm_plans_the_trick_mode_as_before() -> void:
	var ai := _ai(_null())
	_lands(0, "Plains", 2)
	put_battlefield(0, "Savannah Lions")
	var charm := give_hand(0, "Hope Charm")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var choice := ai._plan_spell_choice(g, charm, 0)
	assert_false(choice.is_empty(), "the pilot as it was")
	if not choice.is_empty():
		assert_eq(int(choice["mode"]), 0)


# ================================================ the H7 suspects, proved --

## Goblin Grenadiers unblocked with no creature of theirs to name: the
## creature slot named our own Serra Angel and the hint said yes.
func test_goblin_grenadiers_spare_our_own_creature() -> void:
	var ai := _ai()
	var them := _ai(AiProfile.wizard(), 1)
	var gren := put_battlefield(0, "Goblin Grenadiers")
	var angel := put_battlefield(0, "Serra Angel")
	var plains := put_battlefield(1, "Plains")
	var guard := 0
	while not g.awaiting_attackers and guard < 50:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(0, [gren.id]))
	guard = 0
	while g.current_step() != Mtg.Step.COMBAT_END and guard < 60 and not g.game_over:
		if g.awaiting_blockers: them.act(g)
		else: (them if g.priority_player == 1 else ai).act(g)
		guard += 1
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD, "never our own Serra Angel for their Plains")
	assert_eq(gren.zone, Mtg.Zone.GRAVEYARD, "the Grenadiers names itself, sacrificed anyway...")
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD, "...and takes the land")


func test_goblin_grenadiers_still_take_their_creature() -> void:
	var ai := _ai()
	var them := _ai(AiProfile.wizard(), 1)
	var gren := put_battlefield(0, "Goblin Grenadiers")
	put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(1, "Grizzly Bears")
	bears.tapped = true   # cannot block
	var forest := put_battlefield(1, "Forest")
	var guard := 0
	while not g.awaiting_attackers and guard < 50:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(0, [gren.id]))
	guard = 0
	while g.current_step() != Mtg.Step.COMBAT_END and guard < 60 and not g.game_over:
		if g.awaiting_blockers: them.act(g)
		else: (them if g.priority_player == 1 else ai).act(g)
		guard += 1
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "unaffected control")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


## Under mana burn a Karoo's {C}{U} for a one-mana spell leaves a mana to
## burn: at one life that is the game.
func _karoo_and_merfolk(life: int, burn: bool, profile: AiProfile = null) -> CardInstance:
	g.rules.mana_burn = burn
	var ai := _ai(profile)
	var island := put_battlefield(0, "Island")
	var atoll := put_battlefield(0, "Coral Atoll")
	resolve_stack()   # the Atoll returns the Island
	if island.zone == Mtg.Zone.HAND: g.discard_cards(0, [island])
	atoll.tapped = false
	var merfolk := give_hand(0, "Merfolk of the Pearl Trident")
	g.players[0].life = life
	advance_to_step(Mtg.Step.MAIN1)
	_drive(ai)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	return merfolk


func test_a_karoo_s_spare_mana_does_not_burn_our_last_life() -> void:
	var merfolk := _karoo_and_merfolk(1, true)
	assert_eq(merfolk.zone, Mtg.Zone.HAND, "the second mana would burn the last life")
	assert_false(g.game_over)


func test_karoo_controls_cast_the_merfolk() -> void:
	var merfolk := _karoo_and_merfolk(5, true)
	assert_eq(merfolk.zone, Mtg.Zone.BATTLEFIELD, "a point of burn at five life is a price, not the game")
	assert_eq(g.players[0].life, 4)
	before_each()
	merfolk = _karoo_and_merfolk(1, false)
	assert_eq(merfolk.zone, Mtg.Zone.BATTLEFIELD, "no mana burn: nothing to fear")
	before_each()
	merfolk = _karoo_and_merfolk(1, true, _null())
	assert_ne(merfolk.zone, Mtg.Zone.HAND, "null arm: the pilot as it was")


## Pillar Tombs of Aku at our upkeep with eight life and a Grizzly Bears.
func test_pillar_tombs_takes_a_bear_before_five_of_eight_life() -> void:
	_ai()
	put_battlefield(1, "Pillar Tombs of Aku")
	put_battlefield(1, "Llanowar Elves")   # their own upkeep's answer
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 8
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[0].life, 8)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
