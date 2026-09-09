extends GameTest
## THE FALLOUT (2026-09-09, [member AiProfile.prices_fallout]).
##
## Volcanic Eruption — "destroy X target Mountains, then deal that many
## damage to each creature and each player" — is the pool's one spell
## whose targeted half points across the table and whose untargeted half
## lands on ours as hard as on theirs. The reader had nothing to test the
## card-local `EruptEffect` against, so the whole thing read as `unknown`
## (removal-shaped), and [method AiPlayer._cast_value] priced the
## Mountains it took and charged NOTHING for the blast.
##
## THE CENSUS THAT NAMED IT WAS RIGHT FOR THE WRONG REASON. "Volcanic
## Eruption resolved no cast in sixty games either way (0/0)"
## (docs/ROADMAP.md, the Detonate pass) is not a planner fault at all: the
## card is in the SIDEBOARD of all three decks that hold it — Conjurer,
## Mind Stealer and Thought Invoker, the 1997 files' `.vRed` sections —
## so a free-play census, which never sideboards, could not draw it. Put
## it in a hand and the pilot casts it every time. What it does then is
## what this file is about, on the arm that has the knob and the arm that
## does not.
##
## Nothing here names a card in the AI. The shape is the card's own row in
## [constant EffectIntent.BLASTS] — a table of its own, so the reading the
## word `unknown` gates is untouched — and everything priced off it is the
## sweeper's own arithmetic ([method AiPlayer._sweep_value]) and the panic
## line the profile already carries ([member AiProfile.chump_threshold]).


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_fallout = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_fallout = false
	return profile


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, card_name)


## The planner's own answer for the Eruption in hand: `{}` to hold it,
## else `{x, targets, value}`.
func _sized(ai: AiPlayer, erupt: CardInstance) -> Dictionary:
	var data := erupt.data
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	var sources := ai._mana_sources(g)
	var max_x := ai._max_affordable_x(g, data.cost, g.spell_surcharge(0, data),
		sources, data.x_color, g.mana_usage_keys(data))
	return ai._size_and_aim(g, erupt, intent, max_x, 0)


## Act until the AI casts [param card_name] or has nothing to do.
func _act_for(ai: AiPlayer, card_name: String, rounds := 8) -> String:
	for _i in rounds:
		var did := ai.act(g)
		if did == "" or did.contains(card_name):
			return did
		resolve_stack()
	return ""


# ------------------------------------------------------------ the reader --

func test_the_blast_is_read_off_its_own_table_and_nowhere_else() -> void:
	var data := CardRegistry.get_card("Volcanic Eruption")
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	assert_true(intent.blasts, "the card says so in EffectIntent.BLASTS")
	# The table is a table of its own for the reason the window shapes and
	# the levellers are: a row in CARD_LOCAL would stop the effect being
	# `unknown`, and every reading that word gates has to keep what it had.
	assert_true(intent.unknown, "the effect is still one the reader cannot classify")
	assert_true(intent.is_harmful(), "and an unclassified targeted effect is removal-shaped")


func test_nothing_else_in_the_pool_reads_as_a_blast() -> void:
	for card_name in ["Earthquake", "Detonate", "Balance", "Fireball", "Twiddle"]:
		var data := CardRegistry.get_card(card_name)
		assert_false(EffectIntent.read(data.spell_effects, card_name).blasts,
			"%s is not a blast" % card_name)


# ------------------------------------------------------- what it is worth --

func test_the_blast_is_priced_on_the_sweepers_own_scale() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Serra Angel")      # 4/4 of ours
	put_battlefield(1, "Grizzly Bears")    # 2/2 of theirs
	# Two damage takes their Bears and leaves our Angel standing.
	assert_gt(ai._blast_price(g, 2), 0.0, "their board loses and ours does not")
	# Four takes both, and the Angel is worth more than the Bears.
	assert_lt(ai._blast_price(g, 4), ai._blast_price(g, 2),
		"a blast that burns our own Angel down is worth less")


func test_a_blast_lethal_to_us_is_never_worth_anything() -> void:
	var ai := _ai(_on())
	g.players[0].life = 4
	g.players[1].life = 18
	assert_lt(ai._blast_price(g, 4), -100.0, "the sweeper's own 'never'")


func test_a_blast_lethal_to_them_wins_the_game() -> void:
	var ai := _ai(_on())
	g.players[0].life = 18
	g.players[1].life = 3
	assert_gt(ai._blast_price(g, 3), 100.0)


# --------------------------------------------------------- the three boards --

## Nine Islands, six Mountains of theirs, us at five and them at eighteen.
func _suicide_board() -> CardInstance:
	_lands(0, "Island", 9)
	_lands(1, "Mountain", 6)
	g.players[0].life = 5
	g.players[1].life = 18
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	return erupt


func test_it_does_not_erupt_itself_to_death() -> void:
	var ai := _ai(_on())
	var erupt := _suicide_board()
	assert_true(_sized(ai, erupt).is_empty(), "no X is worth paying here")
	assert_eq(_act_for(ai, "Volcanic Eruption"), "",
		"the Eruption stays in hand")
	assert_eq(erupt.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 5, "and we are still alive")


func test_the_null_still_erupts_itself_to_death() -> void:
	# What shipped before 2026-09-09, kept honest: X=6 at five life, the
	# opponent walks away at twelve.
	var ai := _ai(_off())
	var erupt := _suicide_board()
	assert_eq(int(_sized(ai, erupt)["x"]), 6, "every point of mana it can pay")
	assert_string_contains(_act_for(ai, "Volcanic Eruption"), "Volcanic Eruption")
	resolve_stack()
	assert_true(g.game_over)
	assert_true(g.players[0].has_lost, "the caster")
	assert_eq(g.players[1].life, 12, "the opponent is merely bruised")


## A Mahamoti Djinn (4/5) and two Serra Angels (4/4) of ours against four
## Mountains and a 1/1.
func _our_board_is_better() -> CardInstance:
	_lands(0, "Island", 9)
	put_battlefield(0, "Mahamoti Djinn")
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Serra Angel")
	_lands(1, "Mountain", 4)
	put_battlefield(1, "Mons's Goblin Raiders")
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	return erupt


func test_it_sizes_the_blast_so_its_own_board_survives_it() -> void:
	var ai := _ai(_on())
	var erupt := _our_board_is_better()
	assert_eq(int(_sized(ai, erupt)["x"]), 3,
		"three lands and their 1/1, and a fourth point would take our Angels")
	assert_string_contains(_act_for(ai, "Volcanic Eruption"), "Volcanic Eruption")
	resolve_stack()
	assert_eq(g.players[0].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_creature()).size(), 3,
		"our Djinn and both Angels")
	assert_eq(g.players[1].battlefield.size(), 1, "one Mountain left of theirs")


func test_the_null_burns_its_own_angels_down() -> void:
	var ai := _ai(_off())
	var erupt := _our_board_is_better()
	assert_eq(int(_sized(ai, erupt)["x"]), 6, "every point of mana it can pay")
	assert_string_contains(_act_for(ai, "Volcanic Eruption"), "Volcanic Eruption")
	resolve_stack()
	assert_eq(g.players[0].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_creature()).size(), 1,
		"only the Djinn survives four damage")


## Two Mountains in front of nine Islands: the X buys TARGETS, and there
## are two.
func _the_overpay() -> CardInstance:
	_lands(0, "Island", 9)
	_lands(1, "Mountain", 2)
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	return erupt


func test_it_pays_for_the_mountains_that_are_there_and_no_more() -> void:
	var ai := _ai(_on())
	var erupt := _the_overpay()
	var sized := _sized(ai, erupt)
	assert_eq(int(sized["x"]), 2, "two Mountains, X=2")
	assert_eq((sized["targets"] as Array).size(), 2)


func test_the_null_pays_six_for_two() -> void:
	var ai := _ai(_off())
	var erupt := _the_overpay()
	var sized := _sized(ai, erupt)
	assert_eq(int(sized["x"]), 6, "four mana for nothing")
	assert_eq((sized["targets"] as Array).size(), 2)


# ----------------------------------------------------------- the panic line --

func test_the_panic_line_is_the_rung_and_not_a_number_of_its_own() -> void:
	# The same board, twice: a seat that panics at six holds the spell that
	# would put it at six, and a seat that panics at three casts it.
	for chump in [6, 3]:
		before_each()
		var profile := _on()
		profile.chump_threshold = chump
		var ai := _ai(profile)
		_lands(0, "Island", 6)          # {X}{U}{U}{U} pays X=3 at most
		_lands(1, "Mountain", 3)
		put_battlefield(1, "Hill Giant")   # 3/3: the blast at X=3 takes it
		g.players[0].life = 7
		g.players[1].life = 18
		var erupt := give_hand(0, "Volcanic Eruption")
		advance_to_step(Mtg.Step.MAIN1)
		var sized := _sized(ai, erupt)
		if chump == 6:
			assert_true(sized.is_empty(),
				"seven life is one point off the line, so no X clears it")
		else:
			assert_eq(int(sized["x"]), 3, "a lower rung walks closer to the edge")


func test_a_blast_that_wins_the_game_is_paid_for_at_any_life() -> void:
	# The one exemption: the line is about surviving, and a spell that ends
	# the game does not have to be survived past.
	var ai := _ai(_on())
	_lands(0, "Island", 6)
	_lands(1, "Mountain", 3)
	g.players[0].life = 8    # 8 - 3 = 5, under the Wizard's six
	g.players[1].life = 3
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(int(_sized(ai, erupt)["x"]), 3, "three Mountains, three damage, lethal")
	assert_string_contains(_act_for(ai, "Volcanic Eruption"), "Volcanic Eruption")
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


# ----------------------------------------------------------- the empty board --

func test_no_mountains_is_no_cast_on_either_arm() -> void:
	# The control the census would have hit: a blue mirror has nothing to
	# destroy, the picker finds no slot, and the spell waits in hand.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_lands(0, "Island", 9)
		_lands(1, "Island", 4)
		var erupt := give_hand(0, "Volcanic Eruption")
		advance_to_step(Mtg.Step.MAIN1)
		assert_true(_sized(ai, erupt).is_empty(),
			"nothing to point it at, %s" % profile.profile_name)
		assert_eq(erupt.zone, Mtg.Zone.HAND)


func test_every_rung_prices_the_fallout() -> void:
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_true(profile.prices_fallout, profile.profile_name)


func test_the_deck_lab_can_run_the_null() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("prices_fallout=off"), "")
	assert_false(profile.prices_fallout)


func test_it_never_names_a_mountain_of_our_own() -> void:
	# AiProfile.spares_own already says so for a harmful spell's slots; the
	# blast arm fills them through the same picker, so it inherits the rule.
	var ai := _ai(_on())
	_lands(0, "Island", 9)
	_lands(0, "Mountain", 3)
	_lands(1, "Mountain", 2)
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	var sized := _sized(ai, erupt)
	assert_eq(int(sized["x"]), 2, "their two, not our five")
	for ref in sized["targets"]:
		assert_eq(g.find_instance(ref.instance_id).controller_id, 1,
			"every Mountain named is theirs")
