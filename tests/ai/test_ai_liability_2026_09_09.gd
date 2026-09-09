extends GameTest
## THE LIABILITY (2026-09-09, [member AiProfile.prices_liabilities]).
##
## [method Evaluator.permanent_value] floors at zero, so a permanent worth
## LESS than nothing to its controller could not be said — and every
## question of the form *what does giving this up cost us* reads that floor
## ([method AiPlayer._own_value]). Two things followed, and both are pinned
## here on the arm that has the knob and the arm that does not:
##
##  * [member AiProfile.spares_own]'s ONE DOOR never opened. The rule that
##    landed on 2026-09-08 lets a permanent of ours fill a harmful spell's
##    slot when the evaluator prices giving it up below zero; nothing ever
##    did, and the test that shipped with it said so in as many words ("a
##    Vault it cannot untap is a liability in a human's eyes … but the
##    evaluator has no reading that prices a permanent below zero"). So the
##    AI never Detonated a Mana Vault of its own that it could not untap —
##    the honest half of the play the owner reported the dishonest half of.
##  * A LICH WAS CHEAP. A four-mana enchantment prices at 3.2, below a
##    Grizzly Bears, so a seat asked which of its own permanents to give up
##    answered with the Lich — and "when this enchantment is put into a
##    graveyard from the battlefield, you lose the game" ended the game on
##    the spot. That is a malfunction, which is why the knob is on at every
##    rung like [member AiProfile.spares_own] and [member
##    AiProfile.feeds_worst].
##
## Nothing here names a card in the AI. The three readings are the card's
## own printed lines ([method EffectIntent.toll_of_line], [method
## EffectIntent.loses_the_game_on_leaving]) and live board fields
## ([method AiPlayer._dead_weight]).


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


## A Mana Vault of ours, tapped, with [param mountains] beside it — fewer
## than four and the {4} its own upkeep line offers is out of reach.
func _dead_vault(mountains: int) -> CardInstance:
	_mountains(0, mountains)
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	return vault


## Act until the AI casts [param card_name] or has nothing to do.
func _act_for(ai: AiPlayer, card_name: String, rounds := 8) -> String:
	for _i in rounds:
		var did := ai.act(g)
		if did == "" or did.contains(card_name):
			return did
	return ""


# ------------------------------------------------------------ the reader --

func test_the_reader_finds_the_toll_and_the_price_that_stops_it() -> void:
	# Mana Vault prints the toll on one line and the escape on another;
	# the reader takes each line as it comes and the permanent's own
	# reading sums them ([method AiPlayer._own_toll]).
	var burn := EffectIntent.toll_of_line(
		"At the beginning of your draw step, if this artifact is tapped, it deals 1 damage to you.")
	assert_eq(int(burn["damage"]), 1, "one damage, to us")
	assert_eq(String(burn["escape"]), "", "that line names no way out")
	var offer := EffectIntent.toll_of_line(
		"At the beginning of your upkeep, you may pay {4}. If you do, untap this artifact.")
	assert_eq(int(offer["damage"]), 0, "the offer takes nothing by itself")
	assert_eq(String(offer["escape"]), "{4}", "and it prints the price")


func test_the_reader_refuses_a_toll_it_cannot_know() -> void:
	# A ROLL is not read, the 2026-09-09 ruling on card-local pumps with
	# its sign flipped: what a card GUARANTEES is the only number a
	# decision can be made on, and Mana Crypt guarantees nothing.
	var crypt := EffectIntent.toll_of_line(
		"At the beginning of your upkeep, flip a coin. If you lose the flip, this artifact deals 3 damage to you.")
	assert_eq(int(crypt["damage"]), 0, "a coin flip is not a toll this reader prices")
	# A count the reader would have to do itself is not read either.
	var ooze := EffectIntent.toll_of_line(
		"At the beginning of your upkeep, put a +1/+1 counter on this creature. Then you may pay {X}, where X is the number of +1/+1 counters on it. If you don't, tap this creature and it deals X damage to you.")
	assert_eq(int(ooze["damage"]), 0, "X damage is a count, not a number")
	assert_eq(String(ooze["escape"]), "", "and {X} is not a price this reader can name")


func test_a_symmetric_toll_is_not_one_of_ours() -> void:
	# "…deals 1 damage to THAT PLAYER" ticks both seats at the same rate.
	# A reading that saw only our half would price a Copper Tablet as a
	# liability while it is beating the opponent down beside us.
	var tablet := EffectIntent.toll_of_line(
		"At the beginning of each player's upkeep, Copper Tablet deals 1 damage to that player.")
	assert_eq(int(tablet["damage"]), 0)
	var ai := _ai(_on())
	var inst := put_battlefield(0, "Copper Tablet")
	assert_almost_eq(ai._own_value(g, inst), Evaluator.permanent_value(inst), 0.001,
		"it keeps its printed worth")


func test_the_reckoning_is_read_as_a_shape() -> void:
	assert_true(EffectIntent.loses_the_game_on_leaving(CardRegistry.get_card("Lich")),
		"the Lich's last line")
	assert_false(EffectIntent.loses_the_game_on_leaving(CardRegistry.get_card("Pestilence")))
	assert_false(EffectIntent.loses_the_game_on_leaving(CardRegistry.get_card("Mana Vault")))


# ------------------------------------------------------- what it prices --

func test_a_working_mana_vault_is_worth_what_it_always_was() -> void:
	# Untapped, its draw-step line does not trigger at all — the card's own
	# intervening "if" (CR 603.4) answers for it — so there is no toll and
	# nothing it does is denied us.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_mountains(0, 1)
		var vault := put_battlefield(0, "Mana Vault")
		assert_almost_eq(ai._own_value(g, vault), 1.0, 0.001,
			"an artifact of mana value one, %s" % profile.profile_name)


func test_a_vault_it_cannot_untap_prices_below_zero_only_with_the_knob() -> void:
	var ai := _ai(_on())
	var vault := _dead_vault(1)
	assert_lt(ai._own_value(g, vault), 0.0, "dead weight and a toll on top of it")
	# Three turns of mana away from the {4}, one damage a turn, half a
	# point a life at twenty: -1.5.
	assert_almost_eq(ai._own_value(g, vault), -1.5, 0.001)


func test_the_null_still_prices_the_same_vault_at_its_mana_value() -> void:
	var ai := _ai(_off())
	var vault := _dead_vault(1)
	assert_almost_eq(ai._own_value(g, vault), 1.0, 0.001,
		"the floor of zero, which is what shipped before 2026-09-09")


func test_the_price_falls_as_the_untap_comes_into_reach() -> void:
	# The turns are not a constant: they are what our mana still needs to
	# reach the price the card itself prints, one source a turn.
	var ai := _ai(_on())
	var vault := _dead_vault(3)
	assert_almost_eq(ai._own_value(g, vault), -0.5, 0.001, "one turn away")


func test_a_vault_we_can_untap_is_no_liability_at_all() -> void:
	var ai := _ai(_on())
	var vault := _dead_vault(4)
	assert_almost_eq(ai._own_value(g, vault), 1.0, 0.001,
		"we pay the {4} at our upkeep and it comes back")


func test_a_permanent_that_can_free_itself_keeps_its_worth() -> void:
	# Basalt Monolith is tapped and does not untap either, but "{3}: Untap
	# this artifact" costs no {T} — it can free itself, so it is not dead
	# weight. The rule is structural: no card name is asked.
	var ai := _ai(_on())
	var monolith := put_battlefield(0, "Basalt Monolith")
	g.tap_permanent(monolith)
	assert_almost_eq(ai._own_value(g, monolith),
		Evaluator.permanent_value(monolith), 0.001)


func test_a_toll_with_no_printed_price_is_not_read() -> void:
	# A Serendib Efreet's point a turn has no end but the game's, and
	# permanent_value is a SNAPSHOT: a stream with no end cannot be
	# subtracted from it without pricing every drawback creature in the
	# pool out of its own deck.
	var ai := _ai(_on())
	var efreet := put_battlefield(0, "Serendib Efreet")
	assert_almost_eq(ai._own_value(g, efreet),
		Evaluator.permanent_value(efreet), 0.001)


# ----------------------------------------------- the Detonate, both ways --

func test_it_detonates_its_own_mana_vault_when_it_cannot_untap_it() -> void:
	# THE LOOP THE 2026-09-08 PASS LEFT OPEN. Three Mountains, a tapped
	# Vault it cannot pay {4} for, a Detonate in hand and nothing of
	# theirs to take: the Vault is the target, at X = its mana value.
	var ai := _ai(_on())
	var vault := _dead_vault(3)
	give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Detonate"), "Detonate")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 1, "sized to the Vault")
	assert_eq(item.targets[0].instance_id, vault.id, "at our own dead Vault")
	var life := g.players[0].life   # the Vault has already burnt us once
	resolve_stack()
	assert_eq(vault.zone, Mtg.Zone.GRAVEYARD, "and it is gone")
	assert_eq(g.players[0].life, life - 1, "we paid the X to our own face for it")


func test_the_null_leaves_the_dead_vault_where_it_is() -> void:
	var ai := _ai(_off())
	var vault := _dead_vault(3)
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_act_for(ai, "Detonate").contains("Detonate"), "not cast")
	assert_eq(detonate.zone, Mtg.Zone.HAND)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)


func test_a_vault_it_can_untap_is_still_not_detonated() -> void:
	# The knob is not "blow up your Mana Vaults": four Mountains reach the
	# {4}, so the Vault is worth what it always was and the card waits.
	var ai := _ai(_on())
	var vault := _dead_vault(4)
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_act_for(ai, "Detonate").contains("Detonate"), "not cast")
	assert_eq(detonate.zone, Mtg.Zone.HAND)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)


func test_an_untapped_vault_of_ours_is_never_detonated_either() -> void:
	# The 2026-09-08 report itself, re-pinned on the arm that can now say
	# "below zero": an untapped Vault is a working artifact.
	var ai := _ai(_on())
	_mountains(0, 4)
	var vault := put_battlefield(0, "Mana Vault")
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_act_for(ai, "Detonate").contains("Detonate"), "not cast")
	assert_eq(detonate.zone, Mtg.Zone.HAND)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)


func test_their_board_comes_first() -> void:
	# Their Sol Ring beside our dead Vault, both of mana value one: the
	# liability pool is the LAST one the picker tries.
	var ai := _ai(_on())
	var vault := _dead_vault(3)
	var ring := put_battlefield(1, "Sol Ring")
	give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Detonate"), "Detonate")
	assert_eq(g.stack.back().targets[0].instance_id, ring.id, "at their Ring")
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD, "ours is left alone")


func test_only_an_effect_that_takes_it_off_the_table_relieves_us() -> void:
	# A TAP relieves nothing — our dead Vault is already tapped, and
	# tapping it again is the padding [member AiProfile.spares_own] was
	# written against. A DESTROY does.
	var ai := _ai(_on())
	var vault := _dead_vault(3)
	var detonate := give_hand(0, "Detonate")
	var icy := put_battlefield(0, "Icy Manipulator")
	var destroy: EffectBase = detonate.data.spell_effects[0]
	var tap: EffectBase = icy.data.activated_abilities[0].effects[0]
	assert_true(ai._worth_giving_up(g, detonate, destroy, vault), "a destroy relieves us")
	assert_false(ai._worth_giving_up(g, icy, tap, vault), "a tap does not")


func test_winter_blast_is_still_not_padded_with_our_own_creatures() -> void:
	# The 2026-09-08 rule holds unchanged with the reading in: none of our
	# creatures is a liability, so none of them fills a slot.
	var ai := _ai(_on())
	for _i in 5:
		put_battlefield(0, "Forest")
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var blast := give_hand(0, "Winter Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_act_for(ai, "Winter Blast").contains("Winter Blast"), "not cast")
	assert_eq(blast.zone, Mtg.Zone.HAND)


# ------------------------------------------------------- the reckoning --

func test_it_does_not_feed_its_own_lich_to_the_lich() -> void:
	# The Lich's own trigger asks its controller for a permanent every time
	# they are dealt damage, and the Lich itself is on the list. With the
	# knob it is the most expensive thing on the table; without it, it is
	# cheaper than a Grizzly Bears and the game ends.
	var ai := _ai(_on())
	var lich := put_battlefield(0, "Lich")
	put_battlefield(0, "Hypnotic Specter")
	var fodder: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		fodder.append(inst)
	var chosen := ai.answer_card(g, 0, fodder, "Sacrifice a permanent to the Lich")
	assert_ne(chosen, lich, "not the enchantment we cannot lose")


func test_the_null_feeds_the_lich_to_the_lich() -> void:
	var ai := _ai(_off())
	var lich := put_battlefield(0, "Lich")
	put_battlefield(0, "Hypnotic Specter")
	var fodder: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		fodder.append(inst)
	assert_eq(ai.answer_card(g, 0, fodder, "Sacrifice a permanent to the Lich"), lich,
		"3.2 is cheaper than a 2/2 flier, and the game ends there")


func test_the_lich_is_never_a_slot_of_a_harmful_spell_of_ours() -> void:
	var ai := _ai(_on())
	var lich := put_battlefield(0, "Lich")
	assert_gt(ai._own_value(g, lich), 100.0, "no price at all")


# ------------------------------------------------------------ the ladder --

func test_every_rung_prices_liabilities() -> void:
	# On at every profile, like spares_own and feeds_worst: a seat that
	# sacrifices the enchantment it cannot lose is not playing worse.
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_true(profile.prices_liabilities, profile.profile_name)


func test_the_lab_can_run_the_null() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("prices_liabilities=off"), "")
	assert_false(profile.prices_liabilities)
