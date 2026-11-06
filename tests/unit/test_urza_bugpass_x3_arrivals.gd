extends GameTest
## 0.60.19 bug pass, h2-3 and h2-4 — permanents that ARRIVE TOGETHER
## (MtgGame.put_onto_battlefield_together: Replenish, Living Death, Show and
## Tell, Exhume).
##
## h2-3, CR 613.7m: "If two or more objects would receive a timestamp
## simultaneously ... their relative timestamps are determined in APNAP
## order ... Objects controlled by the active player ... have an earlier
## relative timestamp in the order of that player's choice, followed by
## each other player in turn order." The engine stamped each seat's cards
## in the order the effect listed them and asked nobody — and Replenish
## with Opalescence and Humility decides by that order whether Humility is
## a 4/4 or a 1/1. A seat is asked now, about its own arrivals, only when
## the order would change the board; a seat that answers with the hint
## (every computer seat) keeps the order the effect gave.
##
## h2-4, CR 704.5k: "all except the one that has had the world supertype
## for the shortest amount of time are put into their owners' graveyards.
## In the event of a tie for the shortest amount of time, all are put into
## their owners' graveyards." Worlds arriving together are such a tie; the
## engine buried only the one stamped first.

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U


## Answers a card question with the first named card it can find among the
## candidates (else the hint) and records every prompt.
class Seat extends DecisionAgent:
	var prefer: Array = []
	var asked: Array[String] = []
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for card_name in prefer:
			for c in candidates:
				if c.data.card_name == card_name:
					return c
		return null if candidates.is_empty() else candidates[0]

var me: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardPacks.set_enabled("pack-9", true)
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)
	CardPacks.set_enabled("pack-9", false)


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func _pt(inst: CardInstance) -> Array:
	return [inst.cur_power, inst.cur_toughness]


func _replenish() -> void:
	var spell := give_hand(0, "Replenish")
	add_mana(0, W, 4)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()


# ===================================== h2-3 the order of a seat's arrivals --

func test_replenish_asks_the_order_of_opalescence_and_humility() -> void:
	var opal := _in_graveyard(0, "Opalescence")
	var humility := _in_graveyard(0, "Humility")
	me.prefer = ["Humility"]
	_replenish()
	assert_eq(opal.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(humility.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(me.asked.size(), 1, "one question: which comes first")
	assert_true(humility.layer_timestamp < opal.layer_timestamp, "Humility first, as chosen")
	assert_eq(_pt(humility), [4, 4], "the newer Opalescence sets Humility's size last")


func test_the_other_order_makes_humility_a_one_one() -> void:
	var opal := _in_graveyard(0, "Opalescence")
	var humility := _in_graveyard(0, "Humility")
	me.prefer = ["Opalescence"]
	_replenish()
	assert_eq(me.asked.size(), 1)
	assert_true(opal.layer_timestamp < humility.layer_timestamp)
	assert_eq(_pt(humility), [1, 1], "the newer Humility sets its own size last")


func test_nobody_is_asked_when_the_order_changes_nothing() -> void:
	var crusade := _in_graveyard(0, "Crusade")
	var anthem := _in_graveyard(0, "Glorious Anthem")
	var first := _in_graveyard(0, "Opalescence")
	var second := _in_graveyard(0, "Opalescence")
	_replenish()
	for card in [crusade, anthem, first, second]:
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(me.asked.size(), 0, "two Opalescences size each other the same either way")
	assert_eq(_pt(first), [6, 6], "4/4 by the other Opalescence, +1/+1 twice")
	assert_eq(_pt(second), [6, 6])


func test_each_seat_orders_only_its_own_arrivals() -> void:
	var foe := Seat.new()
	g.set_agent(1, foe)
	var opal := _in_graveyard(1, "Opalescence")
	var humility := _in_graveyard(1, "Humility")
	var crusade := _in_graveyard(0, "Crusade")
	var entries: Array = [{"instance": crusade}, {"instance": opal},
		{"instance": humility}]
	foe.prefer = ["Humility"]
	g.put_onto_battlefield_together(entries)
	assert_eq(me.asked.size(), 0, "the active player's one arrival has no order")
	assert_eq(foe.asked.size(), 1, "the opponent orders its own two")
	assert_true(crusade.layer_timestamp < humility.layer_timestamp,
		"APNAP: the active player's arrivals are older")
	assert_true(humility.layer_timestamp < opal.layer_timestamp)
	assert_eq(_pt(humility), [4, 4])


func test_a_human_seat_is_held_on_the_order_question() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var opal := _in_graveyard(0, "Opalescence")
	var humility := _in_graveyard(0, "Humility")
	var spell := give_hand(0, "Replenish")
	add_mana(0, W, 4)
	assert_ok(g.cast_spell(0, spell))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "held on the order")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_true(g.awaiting_choice.in_order)
	assert_eq(opal.zone, Mtg.Zone.GRAVEYARD, "nothing has happened yet")
	assert_ok(g.answer_choice(humility.id))
	resolve_stack()
	assert_eq(humility.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_pt(humility), [4, 4], "the player's order")


## The computer seat answers with the hint — the order the effect listed
## the cards in, read off its own graveyard — so its answer cannot depend
## on what the opponent holds or how either library is stacked.
func test_the_computer_seat_answers_the_same_whatever_is_hidden() -> void:
	var seen: Array = []
	for hidden in [["Forest"], ["Lightning Bolt", "Counterspell", "Island"]]:
		super.before_each()
		advance_to_step(Mtg.Step.MAIN1)
		g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
		for card_name in hidden:
			give_hand(1, card_name)
		g.players[1].library.reverse()
		var opal := _in_graveyard(0, "Opalescence")
		var humility := _in_graveyard(0, "Humility")
		_replenish()
		assert_eq(humility.zone, Mtg.Zone.BATTLEFIELD)
		seen.append([_pt(humility), opal.layer_timestamp < humility.layer_timestamp])
	assert_eq(seen[0], seen[1], "the same answer with different hidden cards")
	assert_eq(seen[0], [[1, 1], true], "the effect's own order: Opalescence, then Humility")


# ===================================================== h2-4 the world rule --

func test_replenish_two_worlds_both_go() -> void:
	var a := _in_graveyard(0, "Concordant Crossroads")
	var b := _in_graveyard(0, "Gravity Sphere")
	_replenish()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "a tie: all go")
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD, "a tie: all go")


func test_an_older_world_goes_with_a_tied_pair() -> void:
	var old := put_battlefield(1, "The Abyss")
	var a := _in_graveyard(0, "Concordant Crossroads")
	var b := _in_graveyard(0, "Gravity Sphere")
	_replenish()
	for card in [old, a, b]:
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD)


func test_one_world_arriving_still_supersedes_the_older_one() -> void:
	var old := put_battlefield(1, "The Abyss")
	var a := _in_graveyard(0, "Concordant Crossroads")
	var crusade := _in_graveyard(0, "Crusade")
	_replenish()
	assert_eq(old.zone, Mtg.Zone.GRAVEYARD, "the older world goes")
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD, "the newest stays")
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)


func test_a_world_arriving_alone_later_breaks_no_tie_it_was_not_in() -> void:
	var a := put_battlefield(0, "Concordant Crossroads")
	var b := put_battlefield(1, "Gravity Sphere")
	g.check_state_based_actions()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD)


func test_show_and_tell_two_worlds_both_go() -> void:
	var a := give_hand(0, "Concordant Crossroads")
	var b := give_hand(1, "Gravity Sphere")
	var spell := give_hand(0, "Show and Tell")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "a tie: all go")
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD, "a tie: all go")
