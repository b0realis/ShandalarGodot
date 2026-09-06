extends GameTest
## THE CONTROL SWEEP (2026-09-06). The AI's activated-ability vocabulary
## had no arm for the two shapes a control deck wins with — a permanent
## that BECOMES the deck's clock, and a permanent that takes a card off
## the opponent's hand every turn — so both scored `{}` and neither ever
## fired. Measured on Weissman's The Deck against the five shipped
## starters: 3.8% -> 9.1% (docs/ROADMAP.md, "the control sweep").
##
## Everything here acts through AiPlayer.act and the public MtgGame API.
## The capability is gated by [member AiProfile.plays_engines], so each
## behaviour is pinned twice: it happens for a profile that has the
## capability and does not happen for one that does not.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


# ------------------------------------------- the clock a land becomes --

func test_factory_animates_and_then_attacks_an_empty_board() -> void:
	# The Deck's only threat. Before this landed, the AI put a Mishra's
	# Factory on the battlefield 2,339 times in 100 instrumented games and
	# animated one ZERO times.
	var ai := _ai(AiProfile.wizard())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_true(factory.is_creature(), "the land is a creature now")
	assert_eq(factory.cur_power, 2)
	# ...and the attack code, which needed no teaching, sends it.
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(factory.id), "the Factory is the attacker")


func test_factory_stays_a_land_when_a_blocker_would_eat_it() -> void:
	# What animates is almost always a LAND, and a land traded for nothing
	# is a mana source the control deck needed.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	put_battlefield(1, "Grizzly Bears")   # 2/2: kills the 2/2 body back
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")


func test_factory_ignores_a_blocker_that_is_already_tapped() -> void:
	# The classic Factory play: they swung, their board is tapped, the
	# land swings back. Same rule, no special case — only untapped
	# creatures can block.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	var bears := put_battlefield(1, "Grizzly Bears")
	bears.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")


func test_a_factory_played_this_turn_does_not_attack() -> void:
	# CR 302.6, the famous judge call: it may animate, it may not swing.
	# The scorer refuses the animation outright, because the {1} would buy
	# nothing this turn.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Mishra's Factory", true)   # summoning sick
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")


func test_the_factory_is_not_animated_twice() -> void:
	# The animation lasts until end of turn and has no per-turn cap, so
	# without the "already a creature" refusal the main phase would
	# re-animate the same land for as long as the mana lasted.
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_ne(ai.act(g), "activated Mishra's Factory",
		"one animation is enough")


func test_the_bottom_difficulties_leave_the_factory_a_land() -> void:
	# The ladder: a capability, like holds_instants — off for the two
	# lowest profiles and on for the two highest.
	assert_false(AiProfile.apprentice().plays_engines)
	assert_false(AiProfile.magician().plays_engines)
	assert_true(AiProfile.sorcerer().plays_engines)
	assert_true(AiProfile.wizard().plays_engines)
	var ai := _ai(AiProfile.magician())
	put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		assert_ne(ai.act(g), "activated Mishra's Factory")


# ------------------------------------------------ the repeatable discard --

func test_disrupting_scepter_takes_a_card_every_turn() -> void:
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Forest", 3)
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Disrupting Scepter")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "a card came off THEIR hand")
	assert_eq(g.players[0].hand.size(), 0, "and none off ours")


func test_the_scepter_stands_down_against_an_empty_hand() -> void:
	var ai := _ai(AiProfile.wizard())
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Forest", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")


func test_the_bottom_difficulties_never_tick_the_scepter() -> void:
	var ai := _ai(AiProfile.magician())
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Forest", 3)
	give_hand(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		assert_ne(ai.act(g), "activated Disrupting Scepter")


# ------------------------------ what the reader will and will not read --

func test_the_reader_finds_the_aimed_discards() -> void:
	var scepter := CardRegistry.get_card("Disrupting Scepter")
	var scepter_intent := EffectIntent.read(
		scepter.activated_abilities[0].effects, scepter.card_name)
	assert_eq(scepter_intent.discards, 1, "Disrupting Scepter takes one card")
	var twist := CardRegistry.get_card("Mind Twist")
	assert_eq(EffectIntent.read(twist.spell_effects, twist.card_name).discards, -1,
		"Mind Twist's count is X")
	var rag := CardRegistry.get_card("Rag Man")
	assert_eq(EffectIntent.read(rag.activated_abilities[0].effects,
		rag.card_name).discards, 1, "Rag Man takes one card")


func test_the_reader_refuses_the_discards_we_would_pay_for() -> void:
	# The "target player" prefix is the whole guard: a symmetrical discard
	# and one WE pay must never look like an aimed one, or the AI empties
	# its own hand every turn.
	for name in ["Wheel of Fortune", "Contract from Below", "Recall"]:
		var data := CardRegistry.get_card(name)
		assert_eq(EffectIntent.read(data.spell_effects, name).discards, 0,
			"%s is not an aimed discard" % name)


func test_an_animation_is_read_as_an_animation() -> void:
	var factory := CardRegistry.get_card("Mishra's Factory")
	var intent := EffectIntent.read(factory.activated_abilities[0].effects,
		factory.card_name)
	assert_not_null(intent.animates, "the animate ability is recognised")
	assert_eq(intent.animates.set_power, 2)
	assert_eq(intent.animates.set_toughness, 2)
	assert_false(intent.unknown, "and it is no longer an unknown effect")
