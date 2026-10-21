extends GameTest
## THE MASKED LOOP PIECE (bug hunt 2026-10-21, ai; CONTRIBUTING.md rule 8).
##
## CARD-COMBOS prices THEIR loop's pieces for the removal ranking ([method
## CardCombos.threat_value], through [method AiPlayer._victim_value]) by
## the names on their table. A face-down permanent (Illusionary Mask) has
## NO name (CR 708.2) and what it hides is exactly the secret
## `docs/fair-play.md` names — yet [method CardCombos.standing] read
## `inst.data.card_name` of every permanent, face down or not. Beside their
## Heartstone and Ashnod's Altar, a masked Sliver Queen made the Altar
## worth 10 points more to destroy (a live loop, where a masked Grizzly
## Bears left it near), and the masked 2/2 itself 15 points more than any
## other 2/2: the Wizard aimed its removal by a card nobody had shown. The
## review of the morning listed it as "possible hidden information".
##
## A face-down permanent is no piece of any loop now, on either side of
## the table: it has no name and no abilities, so a masked Soul Warden of
## our own does not feed an Aluren loop either. Turned face up, it is a
## piece again — the public-change control below.

const CC := preload("res://engine/ai/card_combos.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-9")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Their Heartstone and Ashnod's Altar, and one masked creature.
func _board(hidden_name: String) -> Array[CardInstance]:
	var heart := put_battlefield(0, "Heartstone")
	var altar := put_battlefield(0, "Ashnod's Altar")
	var hidden := put_battlefield(0, hidden_name)
	g.turn_face_down(hidden)
	return [heart, altar, hidden]


func _wizard() -> AiPlayer:
	return AiPlayer.new(1, AiProfile.wizard())


func test_what_a_mask_hides_moves_no_removal_price() -> void:
	var ai := _wizard()
	var cards := _board("Sliver Queen")
	var heart := CC.threat_value(g, ai, cards[0])
	var hidden := CC.threat_value(g, ai, cards[2])
	var altar := ai._victim_value(g, cards[1])
	before_each()
	cards = _board("Grizzly Bears")
	assert_eq(CC.threat_value(g, ai, cards[0]), heart,
		"Heartstone's threat does not move with the masked card")
	assert_eq(CC.threat_value(g, ai, cards[2]), hidden,
		"nor the masked 2/2's own")
	assert_almost_eq(ai._victim_value(g, cards[1]), altar, 0.001,
		"nor the Altar's removal price")
	assert_eq(hidden, 0.0, "a face-down permanent is no piece of a loop")
	assert_eq(heart, CC.THREAT_NEAR, "two pieces on their table are near, not live")


## THE PUBLIC-CHANGE CONTROL: the same Queen turned face up is a piece, and
## the loop it completes is live again.
func test_turned_face_up_it_is_a_piece_again() -> void:
	var ai := _wizard()
	var cards := _board("Sliver Queen")
	g.turn_face_up(cards[2])
	assert_eq(CC.threat_value(g, ai, cards[0]), CC.THREAT_LIVE, "the loop is whole and public")
	assert_eq(CC.threat_value(g, ai, cards[2]), CC.THREAT_LIVE, "the Queen is its piece")


## OUR OWN masked creature has no abilities either: it completes nothing.
func test_our_own_masked_piece_completes_nothing() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var cards := _board("Sliver Queen")
	var recipe: Dictionary = CC.pieces_of("Sliver Queen")[0]["recipe"]
	var st := CC.standing(g, 0, recipe, true)
	assert_false((st["table"] as Array)[0], "a masked Sliver Queen makes no Slivers")
	assert_eq(CC.keep_value(g, ai, cards[1]), CC.KEEP_WORTH,
		"the Altar is kept as one piece beside another, not as a whole loop")
