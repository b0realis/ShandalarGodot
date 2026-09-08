extends GameTest
## THE TRIBUTE (2026-09-08, The Deck's third pass). Found while reading
## the Disk's timing: an AI seat under The Deck's Abyss fed it a Serra
## Angel and kept the Grizzly Bears beside it, every upkeep, because
## [method AiPlayer.answer_card] priced every card ask as a gain — the
## most valuable candidate, the right answer to a tutor and the wrong
## one to "choose a creature to be destroyed". The same ask, the same
## answer, for a Lord of the Pit's tribute, a Lich's, a Mana Vortex's
## land and a Sylvan Library's extra draw. [member AiProfile.feeds_worst]
## reads the ask as a loss (the candidates all its own, the prompt a
## sacrifice, a destruction or a discard) and gives up the least
## valuable. On at every rung; each behaviour pinned with the knob and
## without it.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.feeds_worst = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.feeds_worst = false
	return profile


## Advance into seat 1's turn and resolve whatever its upkeep put on the stack.
func _through_their_upkeep() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's upkeep")
	resolve_stack()


# --------------------------------------------------------------- the Abyss --

func test_the_abyss_is_fed_the_bears_not_the_angel() -> void:
	_ai(_on())
	put_battlefield(0, "The Abyss")
	var bears := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	_through_their_upkeep()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bears go")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD, "the Angel stays")


func test_off_the_abyss_is_fed_the_angel() -> void:
	_ai(_off())
	put_battlefield(0, "The Abyss")
	var bears := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	_through_their_upkeep()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD, "the null gives up its best")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_the_abyss_takes_the_legal_worst() -> void:
	# A White Knight cannot be its target (pro-black); the choice is
	# between the Bears and the Angel, and the Bears go.
	_ai(_on())
	put_battlefield(0, "The Abyss")
	var knight := put_battlefield(1, "White Knight")
	var bears := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	_through_their_upkeep()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------ the Lord of the Pit --

func test_the_lord_of_the_pit_eats_the_bears() -> void:
	_ai(_on())
	put_battlefield(1, "Lord of the Pit")
	var bears := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	_through_their_upkeep()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "fed: no seven damage")


func test_off_the_lord_of_the_pit_eats_the_angel() -> void:
	_ai(_off())
	put_battlefield(1, "Lord of the Pit")
	var bears := put_battlefield(1, "Grizzly Bears")
	var serra := put_battlefield(1, "Serra Angel")
	_through_their_upkeep()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- the reading --

func test_a_tribute_is_our_own_and_named_a_loss() -> void:
	var ai := _ai(_on())
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	var ours: Array[CardInstance] = [forest, island]
	assert_true(ai._tribute_ask(1, ours, "Sacrifice a land"))
	assert_true(ai._tribute_ask(1, ours, "The Abyss: choose a nonartifact creature to be destroyed"))
	assert_true(ai._tribute_ask(1, ours, "Select card drawn this turn to discard."))
	assert_false(ai._tribute_ask(1, ours, "Select a card to put in your hand."), "a gain")
	assert_false(ai._tribute_ask(1, ours, "Return a card from your graveyard to your hand"))


func test_an_opponents_ask_about_our_cards_is_their_gain() -> void:
	# Demonic Hordes: the enemy names the land its victim sacrifices.
	# For the enemy that is a pick, not a loss — the best land goes.
	var ai := _ai(_on())
	var forest := put_battlefield(0, "Forest")
	var tundra := put_battlefield(0, "Tundra")
	var theirs: Array[CardInstance] = [forest, tundra]
	assert_false(ai._tribute_ask(1, theirs, "Choose a land for Demonic Hordes's controller to sacrifice"))
	assert_false(ai._tribute_ask(1, [], "Sacrifice a land"), "nothing to answer")


func test_the_worst_by_the_own_ledger() -> void:
	# A land tribute is priced the way a cost's sacrifice is: the fifth
	# Forest before the only Island that casts the blue hand.
	var ai := _ai(_on())
	var forests: Array[CardInstance] = []
	for _i in 4:
		forests.append(put_battlefield(1, "Forest"))
	var island := put_battlefield(1, "Island")
	give_hand(1, "Counterspell")
	var lands: Array[CardInstance] = forests.duplicate()
	lands.append(island)
	var picked := ai.answer_card(g, 1, lands, "Sacrifice a land")
	assert_ne(picked, island, "the only blue source is kept")
	assert_true(forests.has(picked))


# ------------------------------------------------------------- the ladder --

func test_on_at_every_rung() -> void:
	assert_true(AiProfile.apprentice().feeds_worst)
	assert_true(AiProfile.magician().feeds_worst)
	assert_true(AiProfile.sorcerer().feeds_worst)
	assert_true(AiProfile.wizard().feeds_worst)


func test_the_override() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("feeds_worst=off"), "")
	assert_false(profile.feeds_worst)
	assert_eq(profile.apply_overrides("feeds_worst=on"), "")
	assert_true(profile.feeds_worst)
