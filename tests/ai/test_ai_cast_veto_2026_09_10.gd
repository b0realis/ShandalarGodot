extends GameTest
## THE ONE-PLY VETO (2026-09-10, [member AiProfile.checks_before_casting];
## `docs/forge/casting.md` P8, Forge's `OnePlaySafetyChecker`).
##
## [method AiPlayer._try_cast_best] prices a cast by what the card is
## worth and what its victim is worth, and never by the position it leaves
## us in. Reproduced before a line was written, on three boards; the third
## is the one that is not arguable:
##
##     BOARD C: a Savannah Lions into an untapped Prodigal Sorcerer
##       act: cast Savannah Lions
##
## A 2/1 cast in front of a 1/1 that taps for one damage at no cost at
## all: the card is gone before it blocks once, the board is where it was,
## and the pilot read the cast as a gain. (Boards A and B — a Llanowar
## Elves into a Rod of Ruin with {3} up, and the last card in hand at four
## life against two Serra Angels — are cast too; the second of those is
## right, which is why [method AiPlayer._in_danger] lifts the veto.)
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.checks_before_casting = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.checks_before_casting = false
	return profile


## Walk our own first main phase, letting the pilot take every action it
## wants, and answer with what it did.
func _play_main(ai: AiPlayer) -> Array:
	var said: Array = []
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			var line := ai.act(g)
			if line != "":
				said.append(line)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	return said


func _cast_names(said: Array) -> String:
	return " | ".join(said)


# ------------------------------------------------ the board that reproduced --

func test_the_lions_does_not_walk_into_a_prodigal_sorcerer() -> void:
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Prodigal Sorcerer")
	assert_true(ai._answered_on_arrival(g, lions.data),
		"a {T} for one damage, and the body is a 2/1")
	_play_main(ai)
	assert_eq(lions.zone, Mtg.Zone.HAND, "the card is still ours")


func test_off_the_lions_walks_into_it() -> void:
	# The malfunction as the probe found it, so the null is the pilot as
	# it was.
	var ai := _ai(_off())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Prodigal Sorcerer")
	assert_string_contains(_cast_names(_play_main(ai)), "cast Savannah Lions")
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD)


func test_a_body_the_pinger_cannot_kill_is_cast_on_both_arms() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var bears := give_hand(0, "Grizzly Bears")
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(1, "Prodigal Sorcerer")
		assert_false(ai._answered_on_arrival(g, bears.data),
			"one damage does not finish a 2/2")
		assert_string_contains(_cast_names(_play_main(ai)), "cast Grizzly Bears")


# ------------------------------------------------- what makes an answer real --

func test_a_tapped_pinger_is_no_answer() -> void:
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	tim.tapped = true
	assert_false(ai._answered_on_arrival(g, lions.data))
	assert_string_contains(_cast_names(_play_main(ai)), "cast Savannah Lions")


func test_a_summoning_sick_pinger_is_no_answer() -> void:
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	var tim := put_battlefield(1, "Prodigal Sorcerer", true)
	assert_true(tim.summoning_sick)
	assert_false(ai._answered_on_arrival(g, lions.data),
		"it cannot pay its own tap cost this turn")


func test_the_answer_has_to_be_payable() -> void:
	# A Rod of Ruin is {3}, {T}; with nothing untapped to make the {3} it
	# is a piece of furniture.
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Rod of Ruin")
	assert_false(ai._answered_on_arrival(g, lions.data), "no mana behind it")
	for _i in 3:
		put_battlefield(1, "Mountain")
	assert_true(ai._answered_on_arrival(g, lions.data), "three Mountains behind it")


## A pinger whose ping costs its own body — SYNTHETIC on purpose, because
## an [ActivatedAbility] object is shared with the [CardData] it was built
## on and a test that reaches into a real card's ability corrupts that
## card for every later test in the process.
static func _sacrificing_pinger() -> CardData:
	var ability := ActivatedAbility.new("", false,
		[DamageEffect.new(1).any_target()],
		"Sacrifice this creature: it deals 1 damage to any target.")
	ability.sacrifice_cost = true
	return CardData.new("Test Sacrificing Pinger", "{1}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.activated(ability)


func test_a_cost_that_is_not_mana_is_not_priced() -> void:
	# The answer [method AiPlayer._cheapest_pump_of] gives the same
	# question: what a sacrifice costs is a board, and nothing here
	# prices a board.
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	put_synthetic(1, _sacrificing_pinger())
	assert_false(ai._answered_on_arrival(g, lions.data))
	# ... and the same ability with a plain {T} cost IS an answer, so the
	# refusal above is the COST and nothing else about the shape.
	var plain := CardData.new("Test Tapping Pinger", "{1}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.activated(ActivatedAbility.new("", true,
			[DamageEffect.new(1).any_target()],
			"{T}: it deals 1 damage to any target."))
	put_synthetic(1, plain)
	assert_true(ai._answered_on_arrival(g, lions.data))


# ------------------------------------------------------------ the escapes --

func test_a_desperate_play_is_allowed_to_be_desperate() -> void:
	# Forge's own escape: a play that looks bad is fine when the next
	# combat was going to kill us anyway. [method AiPlayer._in_danger] is
	# the panic line read against the damage their board would land.
	var ai := _ai(_on())
	var lions := give_hand(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Prodigal Sorcerer")
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Serra Angel")
	g.players[0].life = 8
	assert_true(ai._in_danger(g))
	assert_string_contains(_cast_names(_play_main(ai)), "cast Savannah Lions")


func test_an_artifact_is_never_vetoed() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var tome := give_hand(0, "Jayemdae Tome")
		for _i in 4:
			put_battlefield(0, "Plains")
		put_battlefield(1, "Prodigal Sorcerer")
		assert_false(ai._answered_on_arrival(g, tome.data),
			"nothing in this pool answers an artifact at will")
		assert_string_contains(_cast_names(_play_main(ai)), "cast Jayemdae Tome")


func test_a_removal_spell_is_never_vetoed() -> void:
	# The projection prices what the spell takes off their board, so a
	# Swords to Plowshares is worth casting whatever else is on the table
	# — and [method AiPlayer._answered_on_arrival] abstains for a card
	# that is not a permanent at all, so the veto never even asks.
	var ai := _ai(_on())
	var swords := give_hand(0, "Swords to Plowshares")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Prodigal Sorcerer")
	var mark := put_battlefield(1, "Serra Angel")
	var intent := EffectIntent.read(swords.data.spell_effects, swords.data.card_name)
	var aim: Array = [TargetRef.card(mark)]
	assert_false(ai._answered_on_arrival(g, swords.data))
	assert_gt(ai._cast_projection(g, swords, intent, aim, 0), 0.0,
		"a Serra Angel off their board is worth far more than the card")
	assert_false(ai._cast_veto(g, swords, intent, aim, 0))


# ------------------------------------------------------------ the ladder --

func test_only_the_wizard_checks() -> void:
	assert_false(AiProfile.apprentice().checks_before_casting)
	assert_false(AiProfile.magician().checks_before_casting)
	assert_false(AiProfile.sorcerer().checks_before_casting)
	assert_true(AiProfile.wizard().checks_before_casting)


func test_the_lab_can_put_the_knob_on_a_seat() -> void:
	var profile := AiProfile.wizard()
	assert_eq(typeof(profile.get("checks_before_casting")), TYPE_BOOL)
	assert_eq(profile.apply_overrides("checks_before_casting=off"), "")
	assert_false(profile.checks_before_casting)
	assert_eq(profile.apply_overrides("checks_before_casting=on"), "")
	assert_true(profile.checks_before_casting)
