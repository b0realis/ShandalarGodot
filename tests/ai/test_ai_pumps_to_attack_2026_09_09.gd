extends GameTest
## THE FIREBREATHER THAT NEVER SWUNG (2026-09-09). The owner's playtest:
## *"i noticed during gameplay - when creatures can have greater power or
## defense by some action (like paying mana), the ai opponent does not use
## this before attack for example (even if opponent has free mana
## available). In other words: Opponent does not pump Carrion Ants :).
## Check this and implement this AI mechanic for all similar cards
## also!"*
##
## WHAT WAS ACTUALLY BROKEN, and it was only ever the DECLARATION. An
## unblocked attacker already breathed fire for the damage ([method
## AiPlayer._offensive_combat_response]) and a blocked one already pumped
## to win or survive its trade ([method AiPlayer._combat_self_pumps]) —
## both pinned below, on and off, because neither is this knob's. What no
## reader did was judge a body at the size its OPEN MANA can reach when
## the attack is declared: [method AiPlayer._choose_attack_cohort] drops a
## creature with no power before it prices anything, so a Carrion Ants
## with four Swamps untapped — a 4/5 for the asking — was a 0/1 that could
## never be worth sending, and the two routines above were never handed an
## attacker to work with. Frozen Shade, Killer Bees and Carrion Ants
## stayed home for the whole duel.
##
## Three readings under one knob, [member AiProfile.pumps_to_attack]: the
## declaration made under the journal with every candidate grown to its
## reach ([method AiPlayer._attack_choice_once_pumped]); the mana counted
## with what it is otherwise for kept whole ([method
## AiPlayer._pump_reserve] — the second main phase's cast, the held
## instant, the counterspell); and an ability with a per-turn cap counted
## at its cap and not at the mana ([method AiPlayer._activations_left] —
## the fuse). Each behaviour is pinned with the knob and without.
##
## THE KNOB GREW ON 2026-09-09, later the same day, and the second half
## has a file of its own: `test_ai_pumps_to_block_2026_09_09.gd` pins the
## BLOCK declaration read at reach size, the panic line taken inside the
## same probe, and the two card-local firebreathers the reader could not
## see. This file stays the ATTACK's and keeps every null it pinned.


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


## Walk priority from our first main phase to the attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


## Both seats act until the combat damage is behind us — the AI under
## test in seat 0, a Wizard answering in seat 1.
func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			break
		guard += 1


## The one candidate list the declaration works from, as a typed array.
func _candidates(ai: AiPlayer) -> Array[CardInstance]:
	return ai._attack_candidates(g, 1)


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


# ------------------------------------------- the owner's Carrion Ants --

func test_the_ants_are_sent_at_the_size_four_swamps_can_reach() -> void:
	# The report itself: a 0/1 with {1}: +1/+1 and four Swamps untapped is
	# a 4/5 for the asking, and nothing over there can block it.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(ants.id))
	_play_out_combat(ai, foe)
	assert_eq(ants.cur_power, 4, "four breaths bought with four Swamps")
	assert_eq(g.players[1].life, 16, "and every one of them landed")


func test_off_the_ants_stay_home_with_four_swamps_untapped() -> void:
	# The malfunction as the owner met it, pinned so the null is the pilot
	# as it was.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(g.combat.attackers.has(ants.id))
	_play_out_combat(ai, foe)
	assert_eq(g.players[1].life, 20, "nothing happened at all")
	assert_eq(_untapped_lands(0), 4, "and the mana was never for anything")


func test_the_ants_are_sent_into_a_blocker_the_breaths_beat() -> void:
	# Blocked is the other half, and it was already written: the body goes
	# in as a 0/1, the Grizzly Bears blocks it, and _combat_self_pumps
	# buys exactly the two breaths that win the trade — not the four the
	# mana would have paid for.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the blocker died")
	assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD, "and the swarm lived")
	assert_eq(ants.cur_power, 2, "two breaths, not four")


func test_off_the_ants_stay_home_in_front_of_the_blocker() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	_play_out_combat(ai, foe)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "nothing was traded")


func test_the_same_reading_sends_a_frozen_shade_and_killer_bees() -> void:
	# Nothing here is card-named: the shape is EffectIntent.pump_self, so
	# every firebreather in the pool that starts at zero is the same card
	# to the declaration.
	for card_name in ["Frozen Shade", "Killer Bees"]:
		before_each()
		var ai := _ai(_on())
		var body := put_battlefield(0, card_name)
		_lands(0, "Swamp" if card_name == "Frozen Shade" else "Forest", 3)
		advance_to_step(Mtg.Step.MAIN1)
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 1 attacker", card_name)
		assert_true(g.combat.attackers.has(body.id), card_name)


func test_with_no_mana_open_the_body_is_the_body() -> void:
	# The reach is the mana, and there is none: the knob changes nothing.
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(g.combat.attackers.has(ants.id))


func test_one_pool_grows_one_shade() -> void:
	# Two Frozen Shades in front of four Swamps are not both a 4/5. The
	# mana a body is priced with comes off the table before the next body
	# is priced, so the second Shade is still a 0/1 and stays home.
	var ai := _ai(_on())
	put_battlefield(0, "Frozen Shade")
	put_battlefield(0, "Frozen Shade")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker",
		"one pool, one swarm")


# ------------------------------------- what the mana is otherwise for --

func test_the_counterspells_mana_is_not_pump_mana() -> void:
	# Two Islands and a Counterspell in hand: {1} for a breath and {U}{U}
	# for the counter do not both fit, so the breath is not counted and
	# the 0/1 stays home. A pump that spends the counter's mana on two
	# points of damage is a bad trade.
	var ai := _ai(_on())
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Island", 2)
	give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")


func test_without_the_counterspell_the_same_two_islands_send_it() -> void:
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(ants.id))


func test_a_counterspell_that_cannot_be_paid_for_reserves_nothing() -> void:
	# _held_reserve books a Counterspell's {U}{U} from the moment the card
	# is in hand, Islands or no Islands. Four Swamps cannot pay it, so it
	# books nothing and the swarm swings.
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	give_hand(0, "Counterspell")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(ants.id))


func test_the_second_main_phases_cast_is_kept_whole() -> void:
	# A Hypnotic Specter in hand and four Swamps: one breath fits beside
	# it and three do not, so the Ants is read as a 1/2 — and a 1/2 does
	# not walk into a Grizzly Bears. The same reserve the firebreathing
	# itself keeps (AiPlayer._main2_reserve), asked one phase earlier.
	var ai := _ai(_on())
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")


func test_with_the_hand_empty_the_same_board_sends_it() -> void:
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(ants.id))


# ---------------------------------------------------------- the fuse --

func test_a_capped_breath_is_counted_at_its_cap() -> void:
	# A Fire Drake with five Mountains open is a 2/2, not a 6/2: its
	# breath is "{R}: +1/+0" ONCE a turn. Counted in mana alone the
	# reading promises five.
	var ai := _ai(_on())
	var drake := put_battlefield(0, "Fire Drake")
	_lands(0, "Mountain", 5)
	advance_to_step(Mtg.Step.MAIN1)
	var mine: Array[CardInstance] = [drake]
	var bonuses := ai._reachable_pumps(g, mine)
	assert_eq(bonuses.get(drake.id, Vector2i.ZERO), Vector2i(1, 0),
		"once a turn, whatever the mana says")
	assert_eq(ai._activations_left(g, drake, 0), 1)


func test_off_the_cap_is_not_read_at_all() -> void:
	var ai := _ai(_off())
	var drake := put_battlefield(0, "Fire Drake")
	_lands(0, "Mountain", 5)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._activations_left(g, drake, 0), -1, "the null counts mana only")
	var ability: ActivatedAbility = drake.cur_activated_abilities[0]
	assert_eq(ai._pumps_in_reach(g, drake, ability, ai._mana_sources(g)), 5,
		"five Mountains, five breaths it may not have")


func test_the_bats_are_counted_at_two() -> void:
	var ai := _ai(_on())
	var bats := put_battlefield(0, "Vampire Bats")
	_lands(0, "Swamp", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var mine: Array[CardInstance] = [bats]
	assert_eq(ai._reachable_pumps(g, mine).get(bats.id, Vector2i.ZERO),
		Vector2i(2, 0), "twice a turn")


func test_the_lethal_probe_reads_the_cap_too() -> void:
	# The one place the reach was asked without a cap and could not be
	# refused afterwards: "would breathing everything finish them?"
	var ai := _ai(_on())
	var drake := put_battlefield(0, "Fire Drake")
	_lands(0, "Mountain", 5)
	advance_to_step(Mtg.Step.MAIN1)
	var ability: ActivatedAbility = drake.cur_activated_abilities[0]
	g.players[1].life = 3
	assert_false(ai._pumps_are_lethal(g, drake, ability, ai._mana_sources(g), 1),
		"one breath and a 1/2 is two damage, not six")
	var null_ai := _ai(_off(), 0)
	assert_true(null_ai._pumps_are_lethal(g, drake, ability,
		null_ai._mana_sources(g), 1), "the null still counts the mana")


func test_off_the_dragon_whelps_fuse_is_never_lit_because_it_is_never_read() -> void:
	# WHAT THIS TEST USED TO PIN, and what changed on 2026-09-09.
	#
	# It ran on BOTH arms and pinned the Whelp as unreadable on both:
	# its breath is a card-local effect (WhelpBreathEffect — the fourth
	# activation dooms the body at the next end step), not a PumpEffect,
	# and EffectIntent reads pump_self off PumpEffect alone, so no pump
	# path in the pilot had ever seen it and the fuse could not be lit.
	# The open item it named ("the reader row that would change it") was
	# then built: EffectIntent.CARD_LOCAL_PUMPS, gated on this same knob,
	# carrying the cap the fuse implies.
	#
	# So the ON arm moved out, into
	# tests/ai/test_ai_pumps_to_block_2026_09_09.gd, where the Whelp now
	# breathes three times and stops. What is left here is the OFF arm,
	# unchanged in every assertion — because the null must still be the
	# pilot exactly as it was, and the reading is gated for that reason
	# and no other.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var ability: ActivatedAbility = whelp.cur_activated_abilities[0]
	var intent := EffectIntent.read(ability.effects, whelp.data.card_name)
	assert_false(intent.pump_self, "the reader does not see a pump")
	assert_true(ai._self_pump_of(g, whelp).is_empty(), "so neither does the null")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker",
		"it swings on its printed 2 power, as it always did")
	_play_out_combat(ai, foe)
	assert_eq(g.players[1].life, 18, "two damage, no breath")
	assert_eq(int(whelp.memory.get("breaths", 0)), 0, "the fuse was never lit")
	assert_eq(whelp.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- the traps --

func test_a_wall_is_never_sent_however_big_it_could_get() -> void:
	# Wall of Fire is a 0/5 with {R}: +1/+0 and DEFENDER: the declaration
	# never sees it, because _attack_candidates asks the engine's own
	# attack legality first.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var wall := put_battlefield(0, "Wall of Fire")
		_lands(0, "Mountain", 4)
		advance_to_step(Mtg.Step.MAIN1)
		assert_false(_candidates(ai).has(wall), "a Defender is no candidate")
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 0 attacker")
		assert_eq(wall.cur_power, 0, "and it was never grown for nothing")


func test_a_summoning_sick_firebreather_is_never_sent() -> void:
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants", true)
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_candidates(ai).has(ants), "it may not attack this turn")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")


func test_the_opponents_firebreather_is_not_ours_to_pump() -> void:
	# The candidate list is our own battlefield and nothing else.
	var ai := _ai(_on())
	var theirs := put_battlefield(1, "Frozen Shade")
	var mine := put_battlefield(0, "Grizzly Bears")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	var candidates := _candidates(ai)
	assert_false(candidates.has(theirs), "not a candidate of ours")
	assert_true(candidates.has(mine))
	assert_false(ai._reachable_pumps(g, candidates).has(theirs.id),
		"and never grown by us")
	assert_eq(theirs.cur_power, 0)


func test_a_pump_priced_in_counters_it_cannot_pay_stays_invisible() -> void:
	# Osai Vultures pays two carrion counters for its +1/+1, and a bird
	# that has eaten nothing has none to pay with — refused here on both
	# arms of this knob and both arms of the other one.
	#
	# UNTIL 2026-09-09 the refusal was flat: _ability_available turned
	# away EVERY counter cost, fed or not, because the planner had no
	# model for one. What a FED bird may do is
	# [member AiProfile.spends_counters]'s ruling now, and it has a file
	# of its own (`test_ai_spends_counters_2026_09_09.gd`).
	var ai := _ai(_on())
	var vultures := put_battlefield(0, "Osai Vultures")
	_lands(0, "Plains", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(int(vultures.counters.get("carrion", 0)), 0, "nothing has died")
	assert_true(ai._self_pump_of(g, vultures).is_empty())
	var starved := _off()
	starved.spends_counters = false
	assert_true(_ai(starved, 1)._self_pump_of(g, vultures).is_empty(),
		"and with the counter ruling off as well")


func test_a_pump_priced_in_a_body_stays_invisible() -> void:
	# Atog eats an artifact for +2/+2. A pump whose price is a BODY is
	# refused to every path but the one that prices the body
	# (_try_activate, under pays_sacrifices), or it eats the board one
	# Serra at a time.
	var ai := _ai(_on())
	var atog := put_battlefield(0, "Atog")
	put_battlefield(0, "Mana Vault")
	_lands(0, "Mountain", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._self_pump_of(g, atog).is_empty())


func test_an_ability_the_reader_cannot_price_whole_is_not_firebreathing() -> void:
	# Electric Eel's {R}{R} is +2/+0 AND a damage to its controller, which
	# EffectIntent reads as `unknown` beside the pump. An attack sized on
	# the pump alone would be bought with life nobody counted.
	var ai := _ai(_on())
	var eel := put_battlefield(0, "Electric Eel")
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._self_pump_of(g, eel).is_empty())
	var mine: Array[CardInstance] = [eel]
	assert_false(ai._reachable_pumps(g, mine).has(eel.id))


func test_a_shrinking_pump_is_not_firebreathing() -> void:
	# Wall of Wonder's {2}{U}{U} is +4/-4. A bonus that takes toughness
	# away is a different card, and the declaration is not the place to
	# read it.
	var ai := _ai(_on())
	var wall := put_battlefield(0, "Wall of Wonder")
	_lands(0, "Island", 8)
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._self_pump_of(g, wall).is_empty())


func test_the_probe_leaves_the_game_as_it_found_it() -> void:
	# The pumps are tried under the journal and unmade: no journal stays
	# open, no bonus stays registered, no mana is tapped for a reading, no
	# log line is written and the random stream has not moved. Nothing is
	# paid for until the pump is actually bought, one activation at a
	# time, by the routines that buy it.
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	var state_before := g.rng.state
	var lines_before := g.log_lines.size()
	var chosen := ai._attack_choice_once_pumped(g, _candidates(ai), 1)
	assert_true(chosen.has(ants.id), "the swarm is sent at its reach size")
	assert_eq(g.rng.state, state_before, "no random number was drawn")
	assert_eq(g.log_lines.size(), lines_before, "the probe wrote no log line")
	assert_null(g.undo_log, "the journal was handed back")
	assert_null(g.continuous.journal)
	assert_eq(ants.cur_power, 0, "the body is the body again")
	assert_eq(ants.cur_toughness, 1)
	assert_eq(_untapped_lands(0), 4, "and not one Swamp was tapped for a reading")


func test_the_probe_keeps_a_search_already_in_progress() -> void:
	# A caller that has a journal open keeps it: the probe nests a mark
	# and unmakes to it, and does not end the outer search.
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	var mark := g.make_mark()
	assert_true(ai._attack_choice_once_pumped(g, _candidates(ai), 1).has(ants.id))
	assert_not_null(g.undo_log, "the outer journal is still open")
	g.unmake_to(mark)
	g.end_search()
	assert_null(g.undo_log)
	assert_eq(ants.cur_power, 0)


func test_the_breaths_are_paid_for_and_nothing_is_left_floating() -> void:
	# Mana burn is the 1997 "fifth" ruleset's own rule and the reason a
	# plan is never bigger than the cost: four Swamps buy four breaths,
	# the pool is empty afterwards and no life was lost to it.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(_untapped_lands(0), 0, "every Swamp bought a breath")
	assert_eq(g.players[0].mana_pool.total(), 0, "and nothing was left floating")
	assert_eq(g.players[0].life, 20, "so nothing burned")


# ------------------------------- the half that already worked, pinned --

func test_an_unblocked_shivan_still_burns_them_out() -> void:
	# Not this knob's: the firebreathing on an attacker that got through
	# hangs off holds_instants and has since the capabilities pass. Both
	# arms, so the knob's null is provably the pilot as it was.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		put_battlefield(0, "Shivan Dragon")
		_lands(0, "Mountain", 3)
		g.players[1].life = 4
		advance_to_step(Mtg.Step.MAIN1)
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 1 attacker")
		_play_out_combat(ai, foe)
		assert_true(g.players[1].life <= 0, "eight damage from a 5/5")


func test_a_toughness_only_pump_buys_no_attack() -> void:
	# A Granite Gargoyle's {R}: +0/+1 makes no attack that was not there
	# already — the reach reading wants a POWER bonus and refuses this one
	# outright, so four Mountains do not talk a 2/2 into a Serra Angel.
	# (Blocked, the same ability still saves it: that is
	# _combat_self_pumps, and it is not this knob's.)
	var ai := _ai(_on())
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	_lands(0, "Mountain", 4)
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._self_pump_of(g, gargoyle).is_empty(), "+0/+1 is no attack")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")


# --------------------------------------------------------- the ladder --

func test_the_ladder() -> void:
	assert_false(AiProfile.apprentice().pumps_to_attack)
	assert_false(AiProfile.magician().pumps_to_attack)
	assert_true(AiProfile.sorcerer().pumps_to_attack)
	assert_true(AiProfile.wizard().pumps_to_attack)


func test_the_override() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("pumps_to_attack=off"), "")
	assert_false(profile.pumps_to_attack)
	assert_eq(profile.apply_overrides("pumps_to_attack=on"), "")
	assert_true(profile.pumps_to_attack)
