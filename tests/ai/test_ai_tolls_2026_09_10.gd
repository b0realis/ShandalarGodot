extends GameTest
## THE FOUR THINGS THE LIABILITY PASS LEFT OPEN (2026-09-10, [member
## AiProfile.prices_liabilities]). Two are RULED here and two are FIXED,
## and each is pinned on the arm that has the knob and the arm that does
## not.
##
##  * A TOLL WITH NO PRINTED ESCAPE — a Serendib Efreet's point a turn —
##    is RULED. The reader sees the stream perfectly well; what it cannot
##    do is multiply it, because the honest price of a stream is the
##    stream times a HORIZON and no reader in this engine estimates the
##    turns a game has left. [constant AiPlayer.PACE_HORIZON] is the
##    LIBRARY's clock under a knob of its own, [method
##    AiPlayer._face_damage_value] scales one hit by a share of a life
##    total, and [method Evaluator.position_score] is a snapshot. The one
##    horizon that could be derived — our life over the toll's rate —
##    prices the Efreet at 8.5 minus our whole life and puts every
##    drawback creature in the pool out of its own deck.
##  * A SYMMETRIC TOLL is RULED, and the census is the argument rather
##    than the symmetry: of the six cards the pool puts on the shape, five
##    are refused by rules that predate the question — Manabarbs fires
##    when a LAND IS TAPPED, which is no beat of the turn, and Karma, The
##    Rack, Storm World and Power Surge print a COUNT this reader will not
##    do. What is left is Copper Tablet, and pricing one card's shared
##    clock is `counts_the_race`'s work.
##  * THE UNTAP PRICE PRINTED ON AN AURA is FIXED. Paralyze locks the
##    creature's untap step and prints the {4} on the AURA, so the host's
##    own trigger list never sees it and a Serra Angel with four mana open
##    read as DEAD WEIGHT. The liability pass called that harmless because
##    [member AiProfile.spares_own]'s door needs a price BELOW zero — true
##    of that door and of no other caller: [method AiPlayer.answer_card]
##    gives up the LEAST valuable of ours, and zero is the least there is.
##  * THE ENEMY-SIDE HALF OF [member
##    EffectIntent.damage_to_target_controller] is FIXED. The field was
##    born with this knob and only its own-side half was charged, so a
##    Detonate that cost us X to our own face gained the same X against
##    theirs for nothing — and a Detonate on their Nevinyrral's Disk with
##    the opponent at four was a kill the pilot could not see.
##
## Nothing here names a card in the AI: the readings are printed lines
## ([method EffectIntent.toll_of_line]), live board fields ([member
## CardInstance.attachments], [member CardInstance.cur_skips_untap]) and
## the reader's own table.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_liabilities = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_liabilities = false
	return profile


func _mountains(pid: int, n: int) -> void:
	for _i in n:
		put_battlefield(pid, "Mountain")


## Our [param host], tapped and held down by a Paralyze [param aura_pid]
## controls, with [param mountains] of ours beside it.
func _paralysed(host_name: String, mountains: int, aura_pid := 1) -> CardInstance:
	_mountains(0, mountains)
	var host := put_battlefield(0, host_name)
	var aura := give_hand(aura_pid, "Paralyze")
	g.attach_aura_from_anywhere(aura, host, aura_pid)
	g.tap_permanent(host)
	g.recalculate()
	return host


## Act until the AI casts [param card_name] or has nothing to do.
func _act_for(ai: AiPlayer, card_name: String, rounds := 8) -> String:
	for _i in rounds:
		var did := ai.act(g)
		if did == "" or did.contains(card_name):
			return did
	return ""


# ============================================ 1. THE TOLL WITH NO ESCAPE --
#
# RULED 2026-09-10, not built.

func test_the_reader_sees_the_stream_and_the_price_refuses_it() -> void:
	# The silence is deliberate rather than a gap in the reader: the point
	# a turn is read off the printed line exactly as a Mana Vault's is.
	# What refuses is the PRICE, which has nothing to multiply by.
	var ai := _ai(_on())
	var efreet := put_battlefield(0, "Serendib Efreet")
	var toll := ai._own_toll(g, efreet)
	assert_eq(int(toll["damage"]), 1, "the point a turn is read")
	assert_eq(String(toll["escape"]), "", "and no printed price stops it")
	assert_almost_eq(ai._liability_price(g, efreet), 0.0, 0.001, "so nothing is charged")


func test_a_toll_with_no_printed_escape_keeps_its_printed_worth() -> void:
	# Three of the four drawback bodies the liability pass named. Both
	# arms, because the ruling is that the knob changes nothing here.
	for profile in [_on(), _off()]:
		for name in ["Serendib Efreet", "Erg Raiders", "Yawgmoth Demon"]:
			before_each()
			var ai := _ai(profile)
			var inst := put_battlefield(0, name)
			assert_almost_eq(ai._own_value(g, inst), Evaluator.permanent_value(inst),
				0.001, "%s, %s" % [name, profile.profile_name])


func test_no_horizon_multiplies_the_stream_by_anything() -> void:
	# The ruling in one assertion: the Efreet's worth does not move with
	# our life total. A horizon would make it — at two life a point a turn
	# is half of everything we have left — and there is none to make it.
	var ai := _ai(_on())
	var efreet := put_battlefield(0, "Serendib Efreet")
	var printed := Evaluator.permanent_value(efreet)
	for life in [20, 12, 6, 2]:
		g.players[0].life = life
		assert_almost_eq(ai._own_value(g, efreet), printed, 0.001, "at %d life" % life)


func test_the_one_horizon_this_engine_owns_is_the_librarys() -> void:
	# [constant AiPlayer.PACE_HORIZON] is twenty DRAW STEPS of a library
	# race under [member AiProfile.paces_draws] — a decking clock, not a
	# game clock — and it does not reach this reading from either setting.
	assert_eq(AiPlayer.PACE_HORIZON, 20, "cards of our own library, not turns of a game")
	var worths: Array[float] = []
	for paces in [true, false]:
		before_each()
		var profile := _on()
		profile.paces_draws = paces
		var ai := _ai(profile)
		worths.append(ai._own_value(g, put_battlefield(0, "Serendib Efreet")))
	assert_almost_eq(worths[0], worths[1], 0.001, "the pace's horizon is not this one's")


func test_the_escape_that_is_printed_is_still_read() -> void:
	# The ruling narrows nothing that worked: a Mana Vault we cannot pay
	# {4} for is still a liability, which is the case the owner reported.
	var ai := _ai(_on())
	_mountains(0, 1)
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	assert_almost_eq(ai._own_value(g, vault), -1.5, 0.001,
		"three turns of mana from the {4}, one damage a turn, half a point a life")


# ================================================ 2. THE SYMMETRIC TOLL --
#
# RULED 2026-09-10, not built.

const SYMMETRIC := ["Copper Tablet", "Manabarbs", "Karma", "The Rack",
	"Storm World", "Power Surge"]


func test_every_symmetric_toll_keeps_its_printed_worth() -> void:
	for profile in [_on(), _off()]:
		for name in SYMMETRIC:
			before_each()
			var ai := _ai(profile)
			var inst := put_battlefield(0, name)
			assert_almost_eq(ai._own_value(g, inst), Evaluator.permanent_value(inst),
				0.001, "%s, %s" % [name, profile.profile_name])


func test_five_of_the_six_are_refused_for_a_reason_that_is_not_symmetry() -> void:
	# THE CENSUS THAT CLOSED THE ITEM. Manabarbs fires on a land being
	# tapped for mana, which [constant EffectIntent.TOLL_BEATS] excludes on
	# purpose — a price the seat AGREED to is not a toll. Karma, The Rack,
	# Storm World and Power Surge print a count this reader will not do,
	# which is [constant EffectIntent.TOLL_UNKNOWABLE]'s own ruling. Only
	# Copper Tablet is on a beat AND prints a bare number, so the whole
	# item is one card.
	var bare := RegEx.new()
	bare.compile("deals (\\d+) damage to that player")
	var live: Array[String] = []
	for name in SYMMETRIC:
		before_each()
		_ai(_on())
		var inst := put_battlefield(0, name)
		for trig in inst.cur_triggered_abilities:
			if not EffectIntent.TOLL_BEATS.has(trig.event_type):
				continue
			if bare.search(trig.text.to_lower()) == null:
				continue
			live.append(name)
	assert_eq(live.size(), 1, "one card of six, not six: %s" % str(live))
	assert_true(live.has("Copper Tablet"), "and it is the Tablet")


func test_manabarbs_is_a_price_the_seat_agreed_to() -> void:
	_ai(_on())
	var barbs := put_battlefield(0, "Manabarbs")
	for trig in barbs.cur_triggered_abilities:
		assert_false(EffectIntent.TOLL_BEATS.has(trig.event_type),
			"tapping a land is a choice, not a beat of the turn")


func test_a_count_the_reader_will_not_do_is_still_not_done() -> void:
	# The four that print an X: the line reader answers zero for each,
	# whatever words it is handed.
	for name in ["Karma", "The Rack", "Storm World", "Power Surge"]:
		before_each()
		_ai(_on())
		var inst := put_battlefield(0, name)
		for trig in inst.cur_triggered_abilities:
			assert_eq(int(EffectIntent.toll_of_line(trig.text)["damage"]), 0,
				"%s: %s" % [name, trig.text])


# =============================== 3. THE UNTAP PRICE PRINTED ON THE AURA --
#
# FIXED 2026-09-10.

func test_a_creature_under_a_paralyze_we_can_pay_for_is_no_dead_weight() -> void:
	# FOUR MOUNTAINS reach the {4} the Paralyze itself prints, so the
	# Angel comes back at our upkeep and is worth every point of its ten.
	var ai := _ai(_on())
	var angel := _paralysed("Serra Angel", 4)
	assert_false(ai._dead_weight(g, angel), "the escape is on the aura, and we can pay it")
	assert_almost_eq(ai._own_value(g, angel), Evaluator.permanent_value(angel), 0.001)


func test_it_is_dead_weight_again_when_the_four_is_out_of_reach() -> void:
	var ai := _ai(_on())
	var angel := _paralysed("Serra Angel", 3)
	assert_true(ai._dead_weight(g, angel), "three mountains do not pay {4}")
	assert_almost_eq(ai._own_value(g, angel), 0.0, 0.001)


func test_the_escape_is_read_whoever_controls_the_aura() -> void:
	# The printed line says "that player may pay {4}", and that player is
	# the CREATURE's controller. An enemy Paralyze is the copy of the card
	# this pool actually plays.
	for aura_pid in [0, 1]:
		before_each()
		var ai := _ai(_on())
		var angel := _paralysed("Serra Angel", 4, aura_pid)
		assert_false(ai._dead_weight(g, angel), "Paralyze controlled by P%d" % aura_pid)


func test_the_tribute_no_longer_gives_away_the_angel_it_could_free() -> void:
	# THE MALFUNCTION THE ITEM WAS OPENED ON. Asked which of its own to
	# give up ([member AiProfile.feeds_worst]), the seat answered with the
	# Serra Angel — worth zero as dead weight — while a Grizzly Bears
	# stood beside it and four Mountains were open.
	var ai := _ai(_on())
	var angel := _paralysed("Serra Angel", 4)
	var bears := put_battlefield(0, "Grizzly Bears")
	var fodder: Array[CardInstance] = [angel, bears]
	assert_eq(ai.answer_card(g, 0, fodder, "Sacrifice a creature to Lord of the Pit"),
		bears, "the Bears go, not the Angel we can untap for {4}")


func test_and_it_does_give_it_away_when_the_four_is_out_of_reach() -> void:
	# The other side of the same reading, so the fix is a READING and not
	# a preference for Angels: with three Mountains the Angel really is
	# doing nothing for us, and it is the right answer.
	var ai := _ai(_on())
	var angel := _paralysed("Serra Angel", 3)
	put_battlefield(0, "Grizzly Bears")
	var fodder: Array[CardInstance] = [angel, g.players[0].battlefield[-1]]
	assert_eq(ai.answer_card(g, 0, fodder, "Sacrifice a creature to Lord of the Pit"),
		angel)


func test_the_null_never_saw_a_paralysed_angel_as_anything_but_an_angel() -> void:
	# With the knob off there is no dead-weight reading at all, so the
	# Angel is worth ten at any number of Mountains — which is what
	# shipped before 2026-09-09 and what the Deck Lab's null still plays.
	for mountains in [3, 4]:
		before_each()
		var ai := _ai(_off())
		var angel := _paralysed("Serra Angel", mountains)
		assert_almost_eq(ai._own_value(g, angel), Evaluator.permanent_value(angel),
			0.001, "%d mountains" % mountains)


func test_a_lock_that_prints_no_escape_is_unchanged() -> void:
	# Meekstone and Arena of the Ancients hold a creature down and offer
	# NOTHING for its release, so the reading is the one it always was
	# however much mana is open.
	for lock in ["Meekstone", "Arena of the Ancients"]:
		before_each()
		var ai := _ai(_on())
		_mountains(0, 6)
		var body := put_battlefield(0, "Sengir Vampire" if lock == "Meekstone" \
			else "Angus Mackenzie")
		put_battlefield(0, lock)
		g.recalculate()
		g.tap_permanent(body)
		g.recalculate()
		assert_true(body.cur_skips_untap, "%s holds it down" % lock)
		assert_true(ai._dead_weight(g, body), "%s prints no way out" % lock)


func test_a_price_with_no_structural_link_is_still_not_read() -> void:
	# THE DOCUMENTED UNDERSTATEMENT that remains. Magnetic Mountain offers
	# "{4} for each tapped blue creature" from an enchantment attached to
	# nothing, and tying that offer to THIS creature means reading the
	# card's own filter. It still reads as dead weight, which is the safe
	# direction: zero, not below zero.
	var ai := _ai(_on())
	_mountains(0, 6)
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	put_battlefield(0, "Magnetic Mountain")
	g.recalculate()
	g.tap_permanent(tim)
	g.recalculate()
	assert_true(tim.cur_skips_untap, "the Mountain holds a blue creature down")
	assert_true(ai._dead_weight(g, tim), "and its ransom has no link this reader can follow")


func test_the_permanents_own_printed_price_is_still_the_first_one_read() -> void:
	# Brass Man prints its {1} on ITSELF, which is the case the pass
	# shipped; the aura reading is added beside it, not in front of it.
	for mana in [0, 1]:
		before_each()
		var ai := _ai(_on())
		_mountains(0, mana)
		var man := put_battlefield(0, "Brass Man")
		g.tap_permanent(man)
		assert_eq(ai._dead_weight(g, man), mana < 1, "%d Mountains" % mana)


# ================== 4. THE ENEMY-SIDE HALF OF damage_to_target_controller --
#
# FIXED 2026-09-10.

func _their_artifacts() -> Array[CardInstance]:
	var ring := put_battlefield(1, "Sol Ring")
	var disk := put_battlefield(1, "Nevinyrral's Disk")
	return [ring, disk]


func test_an_enemy_detonate_now_counts_the_damage_it_deals_them() -> void:
	var ai := _ai(_on())
	_mountains(0, 6)
	var theirs := _their_artifacts()
	var det := give_hand(0, "Detonate")
	var ring_worth := ai._cast_value(g, det, [TargetRef.card(theirs[0])], 1)
	var disk_worth := ai._cast_value(g, det, [TargetRef.card(theirs[1])], 4)
	# Their life on the AI's own clock: one point at twenty is 1.05, four
	# is 4.8 ([method AiPlayer._face_damage_value]).
	assert_almost_eq(ring_worth, 4.05, 0.001, "the Ring, and one damage with it")
	assert_almost_eq(disk_worth, 12.4, 0.001, "the Disk, and four damage with it")


func test_the_null_counts_none_of_it() -> void:
	var ai := _ai(_off())
	_mountains(0, 6)
	var theirs := _their_artifacts()
	var det := give_hand(0, "Detonate")
	assert_almost_eq(ai._cast_value(g, det, [TargetRef.card(theirs[0])], 1), 3.0, 0.001)
	assert_almost_eq(ai._cast_value(g, det, [TargetRef.card(theirs[1])], 4), 7.6, 0.001)


func test_a_lethal_sting_is_worth_the_game() -> void:
	var ai := _ai(_on())
	_mountains(0, 6)
	var theirs := _their_artifacts()
	g.players[1].life = 4
	var det := give_hand(0, "Detonate")
	assert_gt(ai._cast_value(g, det, [TargetRef.card(theirs[1])], 4), 100.0,
		"four damage at four life ends the duel")


func test_the_planner_takes_the_kill() -> void:
	# THE PLAY THE PILOT COULD NOT SEE. Five Mountains, a Detonate in
	# hand, their Nevinyrral's Disk on the table and the opponent at four.
	var ai := _ai(_on())
	_mountains(0, 5)
	var theirs := _their_artifacts()
	g.players[1].life = 4
	give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Detonate"), "Detonate")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 4, "sized to the Disk")
	assert_eq(item.targets[0].instance_id, theirs[1].id, "at the Disk and not the Ring")
	resolve_stack()
	assert_eq(g.players[1].life, 0, "and they are dead")


func test_the_null_makes_the_same_cast_and_cannot_tell_it_is_a_kill() -> void:
	# THE HONEST SHAPE OF THE FIX. On this board both arms Detonate the
	# Disk, because the Disk is the better artifact to take whatever the
	# damage is worth; what moves is the PRICE the planner carries, and a
	# price is what competes with every other cast in the hand.
	var det: CardInstance = null
	var values: Array[float] = []
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_mountains(0, 5)
		put_battlefield(1, "Sol Ring")
		put_battlefield(1, "Nevinyrral's Disk")
		g.players[1].life = 4
		det = give_hand(0, "Detonate")
		var intent := EffectIntent.read(det.data.spell_effects, det.data.card_name)
		values.append(float(ai._size_and_aim(g, det, intent, 4, 0)["value"]))
	assert_gt(values[0], 100.0, "the arm that reads it plans a win")
	assert_almost_eq(values[1], 7.6, 0.001, "the null plans an ordinary Detonate")


func test_the_price_is_what_moves_a_decision() -> void:
	# WHERE THE TWO ARMS ACTUALLY PLAY DIFFERENTLY. Two Islands, two
	# Mountains, a Counterspell in hand and their Disrupting Scepter: the
	# main-phase gate holds a marginal cast (under 6.0) that would tap us
	# out from under a counter we are holding. The Detonate is worth 5.7
	# to the null and waits; the three damage it also deals takes it to
	# 9.15, and it goes.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		put_battlefield(0, "Island")
		put_battlefield(0, "Island")
		_mountains(0, 2)
		put_battlefield(1, "Disrupting Scepter")
		var det := give_hand(0, "Detonate")
		give_hand(0, "Counterspell")
		advance_to_step(Mtg.Step.MAIN1)
		var did := _act_for(ai, "Detonate")
		if profile.prices_liabilities:
			assert_string_contains(did, "Detonate", "the arm that prices the sting casts it")
		else:
			assert_eq(det.zone, Mtg.Zone.HAND, "the null keeps the counter's mana open")


func test_our_own_detonate_still_charges_us_the_sting() -> void:
	# The half that landed on 2026-09-09, unmoved: pointing the card at
	# one of our own is priced with the relief and charged for the X.
	# 2.5 is the card's own worth (the X of one buys less), the relief is
	# half of the 0.5 the Vault was costing us three Mountains from its
	# {4}, and the point of our own life is the reaper's half at twenty.
	var ai := _ai(_on())
	_mountains(0, 3)
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	var det := give_hand(0, "Detonate")
	assert_almost_eq(ai._own_value(g, vault), -0.5, 0.001, "one turn from the {4}")
	assert_almost_eq(ai._cast_value(g, det, [TargetRef.card(vault)], 1),
		2.5 + 0.25 - 0.5, 0.001)


func test_no_other_card_in_the_pool_moves() -> void:
	# The field is one row of the reader's table, so the change reaches
	# exactly one card. A Shatter on the same Sol Ring is priced today the
	# way it was yesterday, on both arms.
	var values: Array[float] = []
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_mountains(0, 6)
		var ring := put_battlefield(1, "Sol Ring")
		var shatter := give_hand(0, "Shatter")
		values.append(ai._cast_value(g, shatter, [TargetRef.card(ring)], 0))
	assert_almost_eq(values[0], values[1], 0.001, "Shatter deals nobody any damage")


# ------------------------------------------------------------ the ladder --

func test_every_rung_still_prices_liabilities() -> void:
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_true(profile.prices_liabilities, profile.profile_name)


func test_the_lab_can_still_run_the_null() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("prices_liabilities=off"), "")
	assert_false(profile.prices_liabilities)
