extends GameTest
## THE ANTE CARD IN A DUEL NOT PLAYED FOR ANTE (bug hunt 2026-10-21, ai).
##
## The owner's ruling of the same day: with [member MtgGame.ante_enabled]
## off, the nine cards that print "Remove this card from your deck before
## playing if you're not playing for ante" do nothing — their spells cannot
## be cast, their abilities cannot be activated ([method
## MtgGame.not_for_ante_refusal]). The pilot casts nothing the rules refuse
## (its casts ask [method MtgGame.cast_refusal]), and a Deck Lab run of a
## deck full of them played to the end with no stall — but it still KEPT
## them: the cleanup threw away a Bog Wraith one land from castable and kept
## Contract from Below and Amulet of Quoz, dead cards, to the end of the
## game, and with three Swamps it threw a Bog Wraith away rather than a
## Darkpact; the mulligan read a Contract as the spell three Swamps cast.
## A dead ante card is the first card a discard takes now ([method
## AiPlayer.answer_discard]) and no spell to the mulligan ([method
## AiMulligan.reason]); in a duel played FOR ante it is a card like any
## other (the controls).


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-3")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Three Swamps; Darkpact, Demonic Attorney and a Bog Wraith one land from
## castable; what one discard takes.
func _discard_one(for_ante: bool) -> CardInstance:
	before_each()
	g.ante_enabled = for_ante
	for n in 3: put_battlefield(0, "Swamp")
	give_hand(0, "Darkpact")
	give_hand(0, "Demonic Attorney")
	give_hand(0, "Bog Wraith")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var out := ai.answer_discard(g, 0, 1)
	assert_eq(out.size(), 1)
	return out[0]


func test_a_dead_ante_card_is_discarded_first() -> void:
	var gone := _discard_one(false)
	assert_ne(gone.data.card_name, "Bog Wraith", "the live card was thrown away")
	assert_true(MtgGame.is_ante_card(gone.data), "a card that does nothing in this duel goes")


## THE CONTROL: played for ante the Darkpact and the Attorney are cards
## like any other ({B}{B}{B} and {1}{B}{B}, castable tonight), and the
## ranking that always ruled throws the Wraith away — as it did, until now,
## in the duel not played for ante too.
func test_played_for_ante_the_ranking_is_the_old_one() -> void:
	var gone := _discard_one(true)
	assert_eq(gone.data.card_name, "Bog Wraith", "the ranking that always ruled")


func _hand(names: Array) -> void:
	for inst in g.players[0].hand:
		inst.zone = Mtg.Zone.LIBRARY
	g.players[0].hand.clear()
	for card_name in names:
		give_hand(0, card_name)


func test_three_swamps_and_four_dead_cards_go_back() -> void:
	_hand(["Swamp", "Swamp", "Swamp", "Contract from Below", "Darkpact",
		"Demonic Attorney", "Jeweled Bird"])
	assert_eq(AiMulligan.reason(g, 0), "the lands cast none of the spells")
	g.ante_enabled = true
	assert_eq(AiMulligan.reason(g, 0), "", "for ante, the Contract is a spell")
