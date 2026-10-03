extends GameTest
## THE FAIR AI READS FLANKING (Pack 8 engine package E2; CR 702.25,
## [member AiProfile.reads_gaze] — the knob that already carries rampage,
## the other combat trigger the numbers used to miss).
##
## A blocker WITHOUT flanking meets an attacker with N instances as a body
## N smaller in power and toughness, and one that shrinks to 0 toughness
## is gone before damage (CR 704.5f) — the attacker still blocked. Every
## kill the pilot predicts goes through [method AiPlayer._dies_to], so the
## reading lives there (and in the gang rung that sums damage itself, and
## in the crack-back model's own resolution, [method
## CombatSearch.resolve_block]). Pinned ON and OFF: the OFF arm is the
## pilot as it was. Flanking is public — the keyword on the board — so
## there is nothing hidden for these reads to look at.


static func _knight(name := "Test Knight", power := 2, toughness := 2,
		extra: Array = []) -> CardData:
	var keywords: Array = [Mtg.Keyword.FLANKING]
	keywords.append_array(extra)
	return CardData.new(name, "{2}{W}", Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_gaze = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_gaze = false
	return profile


## Hand the turn to seat 1 and declare [param ids] as its attackers.
func _they_attack(ids: Array) -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != 1) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ------------------------------------------------------------- the pair --

func test_our_flanker_kills_a_bear_and_lives() -> void:
	var ai := _ai(_on())
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(ai._dies_to(g, bear, knight), "the 1/1 it becomes takes 2")
	assert_false(ai._dies_to(g, knight, bear), "and lands only 1 back")


func test_off_the_pair_is_a_trade() -> void:
	var ai := _ai(_off())
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(ai._dies_to(g, bear, knight))
	assert_true(ai._dies_to(g, knight, bear), "2/2 into 2/2, as it always read")


func test_a_one_toughness_blocker_dies_before_it_strikes() -> void:
	# A 0-power flanker still kills a 1/1 blocker (704.5f, no shield helps),
	# and the 1/1 deals it nothing.
	var ai := _ai(_on())
	var knight := put_synthetic(0, _knight("Test Squire", 0, 1))
	var elves := put_battlefield(1, "Llanowar Elves")
	assert_true(ai._dies_to(g, elves, knight), "toughness 0 before any damage")
	assert_false(ai._dies_to(g, knight, elves), "dead before damage: it deals none")
	assert_eq(ai._damage_from(elves, knight, Vector2i(-1, -1)), 0)


func test_a_blocker_with_flanking_is_not_read_as_shrunk() -> void:
	var ai := _ai(_on())
	var knight := put_synthetic(0, _knight())
	var other := put_synthetic(1, _knight("Other Knight"))
	assert_true(ai._dies_to(g, knight, other), "two flankers trade evenly")
	assert_true(ai._dies_to(g, other, knight))


func test_the_attacker_is_whoever_s_turn_it_is() -> void:
	# On their turn THEIR flanker is the attacker: our flanker-less bear is
	# the one that shrinks, and our own flanking (none here) never applies
	# to a creature of ours that only blocks.
	var ai := _ai(_on())
	var knight := put_synthetic(1, _knight())
	var bear := put_battlefield(0, "Grizzly Bears")
	_they_attack([knight.id])
	assert_true(ai._dies_to(g, bear, knight), "our blocker shrinks")
	assert_false(ai._dies_to(g, knight, bear))


# ------------------------------------------------------------ the blocks --

func test_we_do_not_trade_a_bear_into_a_flanker() -> void:
	var ai := _ai(_on())
	var knight := put_synthetic(1, _knight())
	var bear := put_battlefield(0, "Grizzly Bears")
	_they_attack([knight.id])
	var free: Array[CardInstance] = [bear]
	assert_eq(ai._best_block_for(g, knight, free, [], false), [] as Array[int],
		"the 'trade' kills only our bear")


func test_off_we_trade_a_bear_into_a_flanker() -> void:
	var ai := _ai(_off())
	var knight := put_synthetic(1, _knight())
	var bear := put_battlefield(0, "Grizzly Bears")
	_they_attack([knight.id])
	var free: Array[CardInstance] = [bear]
	assert_eq(ai._best_block_for(g, knight, free, [], false), [bear.id] as Array[int])


func test_a_gang_counts_the_shrunk_damage() -> void:
	# Two 2/2s on a 3/4 flanker: 2+2 reads as lethal, but each lands only 1.
	var ai := _ai(_on())
	var knight := put_synthetic(1, _knight("Big Knight", 3, 4))
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	_they_attack([knight.id])
	var free: Array[CardInstance] = [b1, b2]
	assert_eq(ai._best_block_for(g, knight, free, [], false), [] as Array[int])
	var ai_off := _ai(_off())
	assert_eq(ai_off._best_block_for(g, knight, free, [], false).size(), 2,
		"the off arm gangs it")


# ------------------------------------------------------------ the attack --

func test_the_flanker_s_attack_is_read_as_safer() -> void:
	var knight := put_synthetic(0, _knight())
	put_battlefield(1, "Grizzly Bears")
	var blockers: Array[CardInstance] = []
	for inst in g.players[1].battlefield:
		blockers.append(inst)
	var on := _ai(_on())._attack_risk(g, knight, blockers, 1)
	var off := _ai(_off())._attack_risk(g, knight, blockers, 1)
	assert_lt(on, off, "a bear that blocks it dies alone")


# --------------------------------------------------- the crack-back model --

func test_the_crack_back_model_carries_the_flanking() -> void:
	var ai := _ai(_on())
	var bear := put_battlefield(0, "Grizzly Bears")
	var knight := put_synthetic(1, _knight())
	var mine: Array[CardInstance] = [bear]
	var theirs: Array[CardInstance] = [knight]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.d_flanking[0], 1, "the model carries the instance count")
	assert_eq(model.a_flanking[0], 0)
	var out := model.resolve_block(0, [0], false)
	assert_false(bool(out[0]), "their knight lives through our bear's block")
	assert_eq(int(out[1]), 1, "and our bear dies")


func test_the_crack_back_model_kills_a_flanked_chump_before_damage() -> void:
	var ai := _ai(_on())
	var elves := put_battlefield(0, "Llanowar Elves")
	var knight := put_synthetic(1, _knight("Trampling Knight", 3, 3, [Mtg.Keyword.TRAMPLE]))
	var mine: Array[CardInstance] = [elves]
	var theirs: Array[CardInstance] = [knight]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	var out := model.resolve_block(0, [0], false)
	assert_eq(int(out[1]), 1, "the elves are gone before damage")
	assert_eq(int(out[2]), 3, "and a trampler's whole power goes through (CR 702.19e)")


func test_a_shield_does_not_save_a_body_flanked_to_nothing() -> void:
	# Drudge Skeletons with {B} open is immune to damage in the model — but
	# a 1/1 flanked to 0/0 is put into the graveyard (CR 704.5f).
	var ai := _ai(_on())
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	put_battlefield(0, "Swamp")
	var knight := put_synthetic(1, _knight())
	var mine: Array[CardInstance] = [skeletons]
	var theirs: Array[CardInstance] = [knight]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.a_immune[0], 1, "the shield is in reach")
	var out := model.resolve_block(0, [0], false)
	assert_eq(int(out[1]), 1, "and still the skeletons are gone")
	assert_false(bool(out[0]))


func test_off_the_crack_back_model_carries_none() -> void:
	var ai := _ai(_off())
	var bear := put_battlefield(0, "Grizzly Bears")
	var knight := put_synthetic(1, _knight())
	var mine: Array[CardInstance] = [bear]
	var theirs: Array[CardInstance] = [knight]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.d_flanking[0], 0, "zero at the null, so the search is unmoved")
	var out := model.resolve_block(0, [0], false)
	assert_true(bool(out[0]), "the null model trades")


func test_flanking_is_worth_something_on_the_board() -> void:
	var knight := put_synthetic(0, _knight())
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_gt(Evaluator.permanent_value(knight), Evaluator.permanent_value(bear))
