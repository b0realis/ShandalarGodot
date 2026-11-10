extends GameTest
## GAP FIX G1a (gap review 2026-11-10, r1a-4): the card under an
## Illusionary Mask, read by the retarget ranking.
##
## `cards/sets/ice/_patterns.gd` ranked a new target by its PRINTED mana
## value: two face-down 2/2s — publicly the same (CR 708.2) — ranked apart
## by the cards under them, so the computer's Deflection chose by the hidden
## card (CONTRIBUTING.md rule 8), and Portal's targeted triggers, which rank
## their targets with the same function (`cards/sets/por/_triggers.gd`),
## did too. Deflection's question also listed the masked cards' NAMES to
## the seat choosing. Both read the copiable values now — a face-down
## permanent's are a nameless 2/2 with no mana cost — and the question's
## labels are the engine's own target labels.

const ICE := preload("res://engine/ai/ice_age_tactics.gd")
const POR := preload("res://cards/sets/por/_triggers.gd")
const HIDDEN := ["Shivan Dragon", "Llanowar Elves"]


class Recorder extends DecisionAgent:
	var labels: Array = []
	func answer_option(_g: MtgGame, _p: int, prompt: String, options: Array[String], hint: int) -> int:
		labels.append([prompt, options.duplicate()])
		return hint


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	CardPacks.set_enabled("pack-6", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)
	CardPacks.set_enabled("pack-6", false)
	CardPacks.set_enabled(CardPacks.ID, false)


func pilot(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	ai.profile.develops_late = false
	g.set_agent(seat, ai)
	return ai


func _fresh_game() -> void:
	var filler: Array = []
	for i in 30: filler.append("Forest")
	g = MtgGame.new()
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)


func _two_masks(first: String, second: String) -> Array:
	var a := give_hand(1, first)
	g.put_from_hand_face_down(a, 1)
	var b := give_hand(1, second)
	g.put_from_hand_face_down(b, 1)
	return [a, b]


## Seat 1's Terror at our Craw Wurm, on the stack, two masks of theirs beside it.
func _terror_at_our_wurm(first: String, second: String) -> Array:
	var mine := put_battlefield(0, "Craw Wurm")
	var masks := _two_masks(first, second)
	advance_to_step(Mtg.Step.MAIN1)
	g.active_player = 1
	g.priority_player = 1
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(mine)]))
	return [terror, masks[0], masks[1]]


func test_two_masks_rank_alike_for_a_retarget() -> void:
	var setup := _terror_at_our_wurm(HIDDEN[0], HIDDEN[1])
	var ai := pilot()
	var first := ICE.retarget_value(g, ai, setup[0], TargetRef.card(setup[1]))
	var second := ICE.retarget_value(g, ai, setup[0], TargetRef.card(setup[2]))
	assert_eq(first, second, "two face-down 2/2s are publicly identical (rule 8)")


func test_deflection_question_names_no_masked_card() -> void:
	var setup := _terror_at_our_wurm(HIDDEN[0], HIDDEN[1])
	var rec := Recorder.new()
	g.set_agent(0, rec)
	assert_ok(g.pass_priority(1))
	var deflection := give_hand(0, "Deflection")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, deflection, [TargetRef.card(setup[0])]))
	resolve_stack()
	var asked := false
	for row in rec.labels:
		if String(row[0]).begins_with("Deflection"):
			asked = true
			for label in row[1]:
				assert_false(String(label) in HIDDEN, "a masked card's name is hidden from the other seat (CR 708.2)")
			assert_true(row[1].has("a face-down creature"), "the engine's own label for it")
	assert_true(asked, "setup: the Deflection question was put")


func _deflected(first: String, second: String) -> int:
	var setup := _terror_at_our_wurm(first, second)
	assert_ok(g.pass_priority(1))
	give_hand(0, "Deflection")
	for _i in 4: put_battlefield(0, "Island")
	var ai := pilot()
	assert_eq(ai.act(g), "cast Deflection")
	resolve_stack()
	if setup[1].zone != Mtg.Zone.BATTLEFIELD: return 0
	if setup[2].zone != Mtg.Zone.BATTLEFIELD: return 1
	return -1


func test_the_deflection_pick_does_not_follow_the_hidden_card() -> void:
	var dragon_first := _deflected(HIDDEN[0], HIDDEN[1])
	_fresh_game()
	var elves_first := _deflected(HIDDEN[1], HIDDEN[0])
	assert_ne(dragon_first, -1, "setup: the Terror went to a mask")
	assert_eq(dragon_first, elves_first, "the same public board (two 2/2 masks, same ids) gets the same answer")


func test_portal_trigger_order_ranks_two_masks_as_equals() -> void:
	var imp := put_battlefield(0, "Fire Imp")
	var masks := _two_masks(HIDDEN[0], HIDDEN[1])
	var a := TargetRef.card(masks[0])
	var b := TargetRef.card(masks[1])
	assert_false(POR._target_order(g, imp, a, b, false), "neither mask ranks ahead of the other")
	assert_false(POR._target_order(g, imp, b, a, false), "neither mask ranks ahead of the other")


func test_a_face_up_card_still_ranks_by_its_cost() -> void:
	var setup := _terror_at_our_wurm(HIDDEN[0], HIDDEN[1])
	var dragon := put_battlefield(1, "Shivan Dragon")
	var ai := pilot()
	assert_gt(ICE.retarget_value(g, ai, setup[0], TargetRef.card(dragon)),
		ICE.retarget_value(g, ai, setup[0], TargetRef.card(setup[1])),
		"a face-up Shivan Dragon is the public six-drop it shows")
