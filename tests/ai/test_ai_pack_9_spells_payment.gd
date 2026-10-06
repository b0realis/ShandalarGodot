extends GameTest
## Pack 9 (the Tempest block), the fair AI's PAYMENT ROWS (stage 4,
## casting; engine package E2, [member AiProfile.forecasts_tactics]).
##
## 1. THE GRANTED ROW. Dream Halls ("discard a card that shares a colour
##    with it") and Aluren ("creature spells with mana value 3 or less
##    without paying their mana costs") offer every spell a row of
##    [method MtgGame.payment_rows] past the card's own. The pilot pays
##    with one when it is payable now and what it eats is worth less than
##    what it saves: the mana it would otherwise tap, or — when the
##    printed row cannot be paid at all — the spell itself
##    ([method AiPlayer._granted_row]). Never a card dearer than the spell.
## 2. THE RESPONSE PAYS THE ROW IT NAMED. [method AiPlayer._cast_response]
##    priced the printed cost of row 0 whatever row it was handed, so an
##    instant cast at their end step through Dream Halls found no mana and
##    passed ([method MtgGame.payment_option_for]).
## 3. BUYBACK ON AN X SPELL. Fanning the Flames is sized first — X for
##    the creature it kills — and pays its buyback when the mana left over
##    covers it; short of it, the printed row is still cast
##    ([method AiPlayer._x_buyback_row]).
## 4. MEMORY CRYSTAL is worth the buyback cards of our own hand and list
##    ([method AiPlayer._buyback_modifier_value]); with none it is a card
##    that does nothing, and is not cast.
## With the gate off every one of these pays the printed row, as before
## Pack 9. The opponent's hidden hand never moves a decision.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
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


# ------------------------------------------------------------- the granted row --

func test_dream_halls_casts_the_wurm_for_the_bears() -> void:
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	var wurm := give_hand(0, "Craw Wurm")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Craw Wurm")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "no land, a 6/4 for a 2/2")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the cheaper green card is the price")


func test_dream_halls_never_pays_with_the_dearer_card() -> void:
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	var wurm := give_hand(0, "Craw Wurm")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._paying_mode(g, bears.data, bears), -1,
		"the Wurm is never the price of the Bears")
	assert_gt(ai._paying_mode(g, wurm.data, wurm), 0, "the Bears are the Wurm's")


func test_dream_halls_keeps_the_mana_spell_when_it_can_pay() -> void:
	# Two Forests pay for the Bears; a card is not thrown for two mana
	# that would otherwise sit idle.
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	var bears := give_hand(0, "Grizzly Bears")
	var elves := give_hand(0, "Llanowar Elves")
	_lands(0, "Forest", 3)
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	ai.act(g)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD, "both cast with mana, nothing discarded")


func test_the_null_arm_cannot_use_dream_halls() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Dream Halls")
	var wurm := give_hand(0, "Craw Wurm")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(wurm.zone, Mtg.Zone.HAND, "gate off: the printed row, unpayable")


func test_aluren_casts_the_bears_for_nothing() -> void:
	var ai := _ai()
	put_battlefield(1, "Aluren")   # "any player may"
	var forest := put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Grizzly Bears")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(forest.tapped, "the mana cost was not paid")


func test_the_null_arm_pays_for_the_bears() -> void:
	var ai := _ai(false)
	put_battlefield(1, "Aluren")
	_lands(0, "Forest", 2)
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	var tapped := 0
	for land in g.players[0].battlefield:
		if land.is_land() and land.tapped: tapped += 1
	assert_eq(tapped, 2, "gate off: the printed row")


func test_the_granted_row_ignores_their_hidden_hand() -> void:
	var outcomes: Array = []
	for hand in [["Counterspell", "Shivan Dragon"], ["Forest", "Forest"], []]:
		g = null
		before_each()
		var ai := _ai()
		put_battlefield(0, "Dream Halls")
		var wurm := give_hand(0, "Craw Wurm")
		give_hand(0, "Grizzly Bears")
		for card_name in hand: give_hand(1, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		resolve_stack()
		outcomes.append(wurm.zone)
	assert_eq(outcomes, [Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD])


# ---------------------------------------------- the response pays the row it named --

func test_a_bolt_at_their_end_step_through_dream_halls() -> void:
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	var raiders := give_hand(0, "Mons's Goblin Raiders")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Lightning Bolt")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD, "the 1/1 red card paid for it")


# ------------------------------------------------------------ buyback on an X spell --

func test_fanning_the_flames_buys_itself_back_with_the_spare_mana() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 8)
	var giant := put_battlefield(1, "Hill Giant")
	var fanning := give_hand(0, "Fanning the Flames")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Fanning the Flames")
	assert_true(g.buyback_paid(fanning), "X=3 + {R}{R} + {3} fits eight Mountains")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fanning.zone, Mtg.Zone.HAND, "bought back")


func test_fanning_the_flames_short_of_the_buyback_is_still_cast() -> void:
	# Seven Mountains: X can reach five (no X-burn hold), X=3 + {R}{R} is
	# five, and the buyback's {3} more is eight.
	var ai := _ai()
	_lands(0, "Mountain", 7)
	var giant := put_battlefield(1, "Hill Giant")
	var fanning := give_hand(0, "Fanning the Flames")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Fanning the Flames")
	assert_false(g.buyback_paid(fanning))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fanning.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_never_buys_back_the_x_spell() -> void:
	var ai := _ai(false)
	_lands(0, "Mountain", 8)
	put_battlefield(1, "Hill Giant")
	var fanning := give_hand(0, "Fanning the Flames")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_false(g.buyback_paid(fanning))


# ------------------------------------------------------------------ Memory Crystal --

func test_memory_crystal_is_worth_the_buyback_cards_in_hand() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var crystal := give_hand(0, "Memory Crystal")
	give_hand(0, "Whispers of the Muse")
	give_hand(0, "Capsize")
	advance_to_step(Mtg.Step.MAIN1)
	assert_gt(ai._buyback_modifier_value(g, crystal), 2.0)
	assert_string_contains(ai.act(g), "Memory Crystal")


func test_memory_crystal_with_no_buyback_is_not_cast() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var crystal := give_hand(0, "Memory Crystal")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(crystal.zone, Mtg.Zone.HAND, "a discount on nothing")


# ------------------------------------------------------------- buyback in a response --

## P1 casts [param spell] (P1's mana given) and passes: P0 holds priority.
func _they_cast(spell: String, color: int, amount: int) -> CardInstance:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	var card := give_hand(1, spell)
	add_mana(1, color, amount)
	assert_ok(g.cast_spell(1, card, []))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func test_forbid_buys_itself_back_with_spare_lands() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var forbid := give_hand(0, "Forbid")
	give_hand(0, "Island")
	give_hand(0, "Island")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_string_contains(ai.act(g), "Forbid")
	assert_true(g.buyback_paid(forbid), "two spare Islands for a Forbid back")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forbid.zone, Mtg.Zone.HAND)


func test_forbid_keeps_the_dear_cards() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var forbid := give_hand(0, "Forbid")
	give_hand(0, "Shivan Dragon")
	give_hand(0, "Craw Wurm")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_string_contains(ai.act(g), "Forbid")
	assert_false(g.buyback_paid(forbid), "a Dragon and a Wurm are not the price")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_counters_with_the_printed_forbid() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 6)
	var forbid := give_hand(0, "Forbid")
	give_hand(0, "Island")
	give_hand(0, "Island")
	_they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_string_contains(ai.act(g), "Forbid")
	assert_false(g.buyback_paid(forbid))


func test_searing_touch_at_their_end_step_buys_itself_back() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	g.players[1].life = 2
	var touch := give_hand(0, "Searing Touch")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Searing Touch")
	assert_true(g.buyback_paid(touch))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 1)


# --------------------------------------------------------------- buyback sweepers --

func test_evincars_justice_is_priced_as_the_sweeper_it_is() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	for _i in 3: put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	var justice := give_hand(0, "Evincar's Justice")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(justice.zone, Mtg.Zone.HAND, "three Bears of ours for one Elf of theirs")


func test_evincars_justice_sweeps_their_board() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 4)
	for _i in 3: put_battlefield(1, "Grizzly Bears")
	var justice := give_hand(0, "Evincar's Justice")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Evincar's Justice")
	resolve_stack()
	assert_eq(g.players[1].creatures().size(), 0)
	assert_ne(justice.zone, Mtg.Zone.STACK)


# ---------------------------------------------------------------- X paid in life --

func test_an_x_paid_in_life_keeps_us_out_of_their_reach() -> void:
	var ai := _ai()
	for _i in 2: put_battlefield(1, "Craw Wurm")   # 12 power across the table
	assert_eq(ai._life_x_cap(g), 20 - 13)
	var null_ai := _ai(false)
	assert_eq(null_ai._life_x_cap(g), 16, "gate off: life - 4, as before Pack 9")
