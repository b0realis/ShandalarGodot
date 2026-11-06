extends GameTest
## Pack 10 (the Urza block), the fair AI's HAND AND GRAVEYARD SPELLS (stage
## 4, casting; engine/ai/urza_spells.gd, [member AiProfile.forecasts_tactics]).
##
## Windfall deals everyone the greatest hand, Tolarian Winds refreshes our
## own, Ill-Gotten Gains returns each player's best three, Unnerve takes
## two, Show and Tell lets each player put a permanent down, Gamble may
## throw its own find away, Yawgmoth's Will replays our graveyard and
## Replenish returns our enchantments. Each is priced from our own hand,
## both public graveyards and the opponent's hand SIZE — never its cards:
## the hidden-state tests change their hand and both libraries and the
## answer stays put. With the gate off the pilot casts as before Pack 10.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Our first main phase with the land drop spent: the cast is the only
## action left.
func _cast_now(ai: AiPlayer, card: CardInstance) -> bool:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].lands_played_this_turn = 99
	for _i in 3:
		if card.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
	return card.zone != Mtg.Zone.HAND


# --------------------------------------------------------------------- Windfall --

func test_windfall_refills_our_empty_hand_to_theirs() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	for _i in 5: give_hand(1, "Grizzly Bears")
	var windfall := give_hand(0, "Windfall")
	assert_true(_cast_now(ai, windfall))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 5)


func test_windfall_never_hands_them_our_hand_size() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	for _i in 5: give_hand(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	var windfall := give_hand(0, "Windfall")
	assert_false(_cast_now(ai, windfall), "five for us, four of them new for them")


func test_windfall_reads_only_their_hand_size() -> void:
	var outcomes: Array = []
	for hand in [["Counterspell", "Shivan Dragon", "Lightning Bolt"], ["Forest", "Forest", "Swamp"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Island", 3)
		give_hand(0, "Grizzly Bears")
		for card_name in hand: give_hand(1, card_name)
		if hand[0] == "Forest":
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var windfall := give_hand(0, "Windfall")
		outcomes.append(_cast_now(ai, windfall))
	assert_eq(outcomes[0], outcomes[1])
	assert_true(outcomes[0], "one card of ours against their three")


# --------------------------------------------------------------- Tolarian Winds --

func test_tolarian_winds_trades_a_flood_for_fresh_cards() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	for _i in 4: give_hand(0, "Island")
	var winds := give_hand(0, "Tolarian Winds")
	assert_true(_cast_now(ai, winds))


func test_tolarian_winds_keeps_a_live_hand() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	give_hand(0, "Air Elemental")
	give_hand(0, "Air Elemental")
	var winds := give_hand(0, "Tolarian Winds")
	assert_false(_cast_now(ai, winds))


# ------------------------------------------------------------ Ill-Gotten Gains --

func test_ill_gotten_gains_when_our_graveyard_is_the_richer() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	for _i in 3: _in_graveyard(0, "Shivan Dragon")
	give_hand(0, "Grizzly Bears")
	for _i in 3: give_hand(1, "Grizzly Bears")
	var gains := give_hand(0, "Ill-Gotten Gains")
	assert_true(_cast_now(ai, gains))


func test_ill_gotten_gains_is_kept_when_theirs_is() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	for _i in 3: _in_graveyard(1, "Shivan Dragon")
	for _i in 3: give_hand(0, "Grizzly Bears")
	for _i in 2: give_hand(1, "Grizzly Bears")
	var gains := give_hand(0, "Ill-Gotten Gains")
	assert_false(_cast_now(ai, gains))


func test_ill_gotten_gains_reads_only_their_hand_size() -> void:
	var outcomes: Array = []
	for hand in [["Shivan Dragon", "Serra Angel"], ["Forest", "Swamp"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Swamp", 4)
		for _i in 3: _in_graveyard(0, "Shivan Dragon")
		give_hand(0, "Grizzly Bears")
		for card_name in hand: give_hand(1, card_name)
		if hand[0] == "Forest":
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var gains := give_hand(0, "Ill-Gotten Gains")
		outcomes.append(_cast_now(ai, gains))
	assert_eq(outcomes, [true, true])


# ---------------------------------------------------------------------- Unnerve --

func test_unnerve_waits_for_cards_in_their_hand() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	var unnerve := give_hand(0, "Unnerve")
	assert_false(_cast_now(ai, unnerve), "nothing to discard")


func test_unnerve_takes_two() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	for _i in 3: give_hand(1, "Grizzly Bears")
	var unnerve := give_hand(0, "Unnerve")
	assert_true(_cast_now(ai, unnerve))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)


# ---------------------------------------------------------------- Show and Tell --

func test_show_and_tell_puts_our_dragon_down() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var dragon := give_hand(0, "Shivan Dragon")
	give_hand(1, "Grizzly Bears")
	var show := give_hand(0, "Show and Tell")
	assert_true(_cast_now(ai, show))
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)


func test_show_and_tell_is_kept_for_a_small_card() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	give_hand(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	var show := give_hand(0, "Show and Tell")
	assert_false(_cast_now(ai, show), "a 2/2 against an average card of theirs")


func test_show_and_tell_reads_only_their_hand_size() -> void:
	var outcomes: Array = []
	for hand in [["Shivan Dragon"], ["Forest"]]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Island", 3)
		give_hand(0, "Shivan Dragon")
		for card_name in hand: give_hand(1, card_name)
		if hand[0] == "Forest":
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var show := give_hand(0, "Show and Tell")
		outcomes.append(_cast_now(ai, show))
	assert_eq(outcomes, [true, true])


# ----------------------------------------------------------------------- Gamble --

func test_gamble_alone_in_hand_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 1)
	var gamble := give_hand(0, "Gamble")
	assert_false(_cast_now(ai, gamble), "the card found would be the card discarded")


# --------------------------------------------------------------- Yawgmoth's Will --

func test_yawgmoths_will_replays_a_graveyard_worth_it() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 7)
	_in_graveyard(0, "Black Knight")
	_in_graveyard(0, "Black Knight")
	var will := give_hand(0, "Yawgmoth's Will")
	assert_true(_cast_now(ai, will))
	resolve_stack()
	for _i in 4:
		ai.act(g)
		resolve_stack()
	assert_eq(g.players[0].creatures().size(), 2, "both Knights replayed")


func test_yawgmoths_will_is_never_cast_into_an_empty_graveyard() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 7)
	var will := give_hand(0, "Yawgmoth's Will")
	assert_false(_cast_now(ai, will))


func test_the_null_arm_casts_the_will_for_its_card() -> void:
	var ai := _ai(false)
	_lands(0, "Swamp", 7)
	var will := give_hand(0, "Yawgmoth's Will")
	assert_true(_cast_now(ai, will), "gate off: an untargeted card worth its cost")


# -------------------------------------------------------------------- Replenish --

func test_replenish_returns_our_enchantments() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	_in_graveyard(0, "Crusade")
	_in_graveyard(0, "Castle")
	_in_graveyard(0, "Bad Moon")
	var replenish := give_hand(0, "Replenish")
	assert_true(_cast_now(ai, replenish))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 7)


func test_replenish_with_nothing_to_return_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	var replenish := give_hand(0, "Replenish")
	assert_false(_cast_now(ai, replenish))
