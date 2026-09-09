extends GameTest
## THE SHADE THAT DIED WITH FOUR SWAMPS UP (2026-09-09, [member
## AiProfile.pumps_to_attack]'s fourth reading).
##
## [method AiPlayer._save_from_the_stack] is the arm that answers a removal
## spell of theirs aimed at one of ours — a regeneration shield, a bounce
## to save the card, or a pump that lifts toughness past a burn spell's
## damage. Against BURN it knew exactly one answer: a pump INSTANT in hand
## ([method AiPlayer._find_pump_instant]). So a Frozen Shade with four
## Swamps untapped — a 4/5 for the asking, and three of those Swamps enough
## to walk out of a Lightning Bolt — died to the Bolt with the mana still
## on the table, and so did every firebreather in the pool with a toughness
## line.
##
## Nothing here is new pricing. [method AiPlayer._self_pump_of], [method
## AiPlayer._pumps_in_reach], [method AiPlayer._activations_left] and
## [method AiPlayer._pump_reserve] were all built by the pump passes
## earlier the same day; the save path simply never asked them. [method
## AiPlayer._pump_out_of_reach] asks, and keeps all three of the things
## those passes learned the hard way — the mana may be spoken for, the
## per-turn cap is not the mana, and an ability whose cost is a body or a
## counter is somebody else's ruling. Every one of them is pinned below on
## the arm that has the knob and the arm that does not.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _untapped(seat: int, land_name: String) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.data.card_name == land_name and not inst.tapped:
			n += 1
	return n


## Put [param spell_name] of THEIRS on the stack aimed at [param victim],
## with the mana handed over rather than tapped for (the opponent's lands
## are not what any of this is about).
func _their_spell_at(spell_name: String, victim: CardInstance) -> CardInstance:
	var spell := give_hand(1, spell_name)
	if g.priority_player != 1:
		g.pass_priority(g.priority_player)
	for color in spell.data.cost.colored:
		add_mana(1, int(color), int(spell.data.cost.colored[color]))
	if spell.data.cost.generic > 0:
		add_mana(1, Mtg.ManaColor.C, spell.data.cost.generic)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(victim)]))
	if g.priority_player != 0:
		g.pass_priority(g.priority_player)   # the caster keeps priority (CR 117.3c)
	return spell


# ------------------------------------------------------- the report itself --

func test_the_shade_grows_out_of_the_bolt() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var shade := put_battlefield(0, "Frozen Shade")
		_lands(0, "Swamp", 4)
		_their_spell_at("Lightning Bolt", shade)
		assert_eq(shade.cur_toughness, 1, "a 0/1 while the Bolt is on the stack")
		var did := ai._save_from_the_stack(g)
		if knob:
			assert_eq(did, "pumps Frozen Shade out of the burn",
				"one breath bought, one activation per call")
			assert_eq(_untapped(0, "Swamp"), 3, "and one Swamp spent for it")
		else:
			assert_eq(did, "", "the null has no answer at all")
			assert_eq(_untapped(0, "Swamp"), 4, "and spends nothing")


func test_the_shade_lives_through_the_whole_exchange() -> void:
	# End to end through [method AiPlayer.act], one action at a time, with
	# our own object on top of the stack waited out each time — three
	# breaths, one Swamp left over, and a Shade still on the battlefield.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var shade := put_battlefield(0, "Frozen Shade")
		_lands(0, "Swamp", 4)
		_their_spell_at("Lightning Bolt", shade)
		for _i in 12:
			if g.stack.is_empty():
				break
			if g.priority_player != 0:
				g.pass_priority(g.priority_player)
				continue
			if ai.act(g) == "":
				break
		if knob:
			assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD, "the Shade lives")
			assert_eq(shade.cur_toughness, 4, "a 3/4 that shrugged off three")
			assert_eq(_untapped(0, "Swamp"), 1, "three Swamps, not four")
		else:
			assert_eq(shade.zone, Mtg.Zone.GRAVEYARD,
				"the Shade dies with four Swamps untapped")
			assert_eq(_untapped(0, "Swamp"), 4)


func test_the_gargoyle_the_attack_reader_refuses_is_the_one_this_wants() -> void:
	# Granite Gargoyle's `{R}: +0/+1` buys no attack, so [method
	# AiPlayer._self_pump_of] refuses it by default and always has. The
	# burn on the stack is answered with TOUGHNESS, so the save path asks
	# the same reader the other way round.
	var ai := _ai(_on())
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	_lands(0, "Mountain", 2)
	assert_true(ai._self_pump_of(g, gargoyle).is_empty(),
		"no power: not an attacker's breath")
	assert_false(ai._self_pump_of(g, gargoyle, true).is_empty(),
		"but it is exactly the breath that answers a Bolt")


func test_the_gargoyle_shrugs_off_the_bolt() -> void:
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var gargoyle := put_battlefield(0, "Granite Gargoyle")
		_lands(0, "Mountain", 2)
		_their_spell_at("Lightning Bolt", gargoyle)
		var did := ai._save_from_the_stack(g)
		if knob:
			assert_eq(did, "pumps Granite Gargoyle out of the burn",
				"the first of the two breaths a 2/2 needs to live through three")
			assert_eq(_untapped(0, "Mountain"), 1)
		else:
			assert_eq(did, "")
			assert_eq(_untapped(0, "Mountain"), 2)


# -------------------------------------------------------------- the traps --

func test_the_save_path_does_not_steal_the_second_mains_cast() -> void:
	# THE MANA MAY BE SPOKEN FOR. On our own turn [method
	# AiPlayer._pump_reserve] books the best sorcery-speed cast in hand,
	# and a Hypnotic Specter's {1}{B}{B} is three of the four Swamps. One
	# breath is all that is left, a 0/2 still dies to a Bolt, and the right
	# answer is to spend NOTHING rather than a Swamp for nothing.
	var ai := _ai(_on())
	var shade := put_battlefield(0, "Frozen Shade")
	_lands(0, "Swamp", 4)
	give_hand(0, "Hypnotic Specter")
	assert_eq(g.active_player, 0, "our own turn, so main 2 is still to come")
	_their_spell_at("Lightning Bolt", shade)
	assert_eq(ai._save_from_the_stack(g), "",
		"the Specter's mana is not three points of toughness")
	assert_eq(_untapped(0, "Swamp"), 4, "and not one Swamp was wasted trying")


func test_the_reserve_is_kept_and_the_save_still_happens_when_it_can() -> void:
	# The same board with two more Swamps: the Specter keeps its three and
	# the Shade still reaches four toughness out of what is left.
	var ai := _ai(_on())
	var shade := put_battlefield(0, "Frozen Shade")
	_lands(0, "Swamp", 6)
	give_hand(0, "Hypnotic Specter")
	_their_spell_at("Lightning Bolt", shade)
	for _i in 12:
		if g.stack.is_empty():
			break
		if g.priority_player != 0:
			g.pass_priority(g.priority_player)
			continue
		if ai.act(g) == "":
			break
	assert_eq(shade.zone, Mtg.Zone.BATTLEFIELD, "the Shade lives")
	assert_eq(_untapped(0, "Swamp"), 3, "and the Specter's three are still open")


## A body whose breath is printed "only once each turn", so the mana is not
## the bound — [member ActivatedAbility.max_per_turn] is.
func _capped_body() -> CardData:
	return CardData.new("Test Capped Breather", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 2) \
		.activated(ActivatedAbility.new("{B}", false,
			[PumpEffect.new(1, 1).self_buff()],
			"{B}: This creature gets +1/+1 until end of turn. Activate only once each turn.") \
			.per_turn(1)) \
		.oracle("")


func test_the_cap_is_read_and_the_mana_is_not_thrown_after_it() -> void:
	# THE FUSE. Four Swamps say four breaths and the card says one. A
	# 0/2 that can only ever be a 1/3 dies to a Bolt whatever it pays, so
	# the reading that counts mana alone would tap a Swamp for a pump it
	# cannot follow — and the creature dies anyway, a Swamp poorer.
	var ai := _ai(_on())
	var capped := put_synthetic(0, _capped_body())
	_lands(0, "Swamp", 4)
	var index := 0
	var ability: ActivatedAbility = capped.cur_activated_abilities[index]
	var sources := ai._mana_sources(g)
	assert_eq(ai._pumps_in_reach(g, capped, ability, sources, null,
		ai._activations_left(g, capped, index)), 1, "one breath, not four")
	_their_spell_at("Lightning Bolt", capped)
	assert_eq(ai._save_from_the_stack(g), "",
		"one breath still leaves it dead, so nothing is bought")
	assert_eq(_untapped(0, "Swamp"), 4, "and nothing is spent")


func test_a_pump_whose_price_is_a_body_stays_invisible() -> void:
	# The gate this path inherits: [method AiPlayer._ability_available]
	# refuses a pump priced in BODIES for every reader that prices the
	# effect and not the cost, and this is one of them. An Atog with a
	# board to eat does not eat it to survive a Bolt.
	var ai := _ai(_on())
	var atog := put_battlefield(0, "Atog")
	put_battlefield(0, "Mox Ruby")
	put_battlefield(0, "Mox Jet")
	_their_spell_at("Lightning Bolt", atog)
	assert_eq(ai._save_from_the_stack(g), "", "no artifact is eaten for a save")


func test_a_counter_costed_breath_answers_the_burn_when_the_ruling_allows_it() -> void:
	# The two 2026-09-09 readings meet here: the save path asks [method
	# AiPlayer._self_pump_of], which asks [method
	# AiPlayer._ability_available], which is where [member
	# AiProfile.spends_counters] rules on a counter cost. Six carrion
	# counters are three +1/+1s, and a 1/4 walks away from a Bolt without
	# a land being tapped at all.
	for spends in [false, true]:
		before_each()
		var profile := _on()
		profile.spends_counters = spends
		var ai := _ai(profile)
		var birds := put_battlefield(0, "Osai Vultures")
		g.add_counters(birds, "carrion", 6)
		g.recalculate()
		_lands(0, "Plains", 3)
		_their_spell_at("Lightning Bolt", birds)
		for _i in 12:
			if g.stack.is_empty():
				break
			if g.priority_player != 0:
				g.pass_priority(g.priority_player)
				continue
			if ai.act(g) == "":
				break
		if spends:
			assert_eq(birds.zone, Mtg.Zone.BATTLEFIELD, "the bird lives")
			assert_eq(int(birds.counters.get("carrion", 0)), 0, "six counters spent")
			assert_eq(_untapped(0, "Plains"), 3, "and no land was needed")
		else:
			assert_eq(birds.zone, Mtg.Zone.GRAVEYARD,
				"with the counter ruling off it dies holding six of them")
			assert_eq(int(birds.counters.get("carrion", 0)), 0,
				"the zone change takes them, not the pilot")


func test_a_destroy_spell_is_not_a_burn_spell() -> void:
	# The arm is the burn arm and nothing else: toughness does not answer
	# "destroy target creature", and a Terror on a Gargoyle is met with the
	# reading the path already had (nothing here, on this board).
	var ai := _ai(_on())
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	_lands(0, "Mountain", 4)
	_their_spell_at("Terror", gargoyle)
	assert_eq(ai._save_from_the_stack(g), "", "no breath is bought against a Terror")
	assert_eq(_untapped(0, "Mountain"), 4)


func test_a_burn_it_cannot_outgrow_is_declined_whole() -> void:
	# All-or-nothing, the same rule [method AiPlayer._buy_prevention]
	# keeps: a Shade with two Swamps reaches 0/3 and a Fireball for four
	# still kills it, so the two Swamps stay untapped.
	var ai := _ai(_on())
	var shade := put_battlefield(0, "Frozen Shade")
	_lands(0, "Swamp", 2)
	var bolt := give_hand(1, "Lightning Bolt")
	_lands(1, "Mountain", 1)
	g.pass_priority(0)
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(shade)]))
	assert_eq(ai._save_from_the_stack(g), "",
		"two breaths reach 0/3 and three damage is still three damage")
	assert_eq(_untapped(0, "Swamp"), 2)


func test_it_buys_no_second_breath_for_a_job_the_first_has_done() -> void:
	# [method AiPlayer._pending_pumps]: a breath already on the stack counts
	# as if it had resolved, so the routine stops the moment what is in
	# flight carries the body past the damage. The breath is put there by
	# the test rather than by the pilot, because a burn spell UNDER one of
	# our own objects is not a board [method AiPlayer._respond_action] ever
	# looks at — it waits for its own object to resolve first.
	var ai := _ai(_on())
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	_lands(0, "Mountain", 4)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, gargoyle, 0, []))
	assert_ok(g.activate_ability(0, gargoyle, 0, []))
	_their_spell_at("Lightning Bolt", gargoyle)
	assert_eq(gargoyle.cur_toughness, 2, "neither +0/+1 has resolved yet")
	assert_eq(ai._save_from_the_stack(g), "",
		"the two breaths on the stack are already the whole answer")
	assert_eq(_untapped(0, "Mountain"), 4, "and no third Mountain follows them")


func test_only_our_own_creature_is_grown() -> void:
	# The path's own first gate, unchanged: a burn spell aimed at one of
	# THEIRS is none of our business.
	var ai := _ai(_on())
	var theirs := put_battlefield(1, "Frozen Shade")
	_lands(0, "Swamp", 4)
	var bolt := give_hand(1, "Lightning Bolt")
	g.pass_priority(0)
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(theirs)]))
	assert_eq(ai._save_from_the_stack(g), "")
	assert_eq(_untapped(0, "Swamp"), 4)
